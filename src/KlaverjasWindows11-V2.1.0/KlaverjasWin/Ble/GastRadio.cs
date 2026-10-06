using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Foundation;
using Windows.Storage.Streams;

namespace Klaverjas.Ble;

/// <summary>Voor de statusregel op het scherm; puur informatief.</summary>
public enum GastStatus
{
    Nietverbonden,
    ZoektNaarApparaat,
    VerbindtMet,
    WachtOpBegroeting,
    Verbonden,
    Verbroken,

    /// <summary>
    /// Zoals <see cref="Verbroken"/>, maar dan voor het specifieke patroon dat
    /// op hardware bleek te wijzen op een verouderde Bluetooth-koppeling in
    /// Windows voor dit apparaat (zie <see cref="GastRadio"/>,
    /// <c>_meteenAlVerbondenGezien</c>): het apparaat meldt zich al meteen als
    /// Connected, nog vóór er iets is opgezet, en laat de verbinding daarna
    /// alsnog vallen vóór de begroeting.
    /// </summary>
    VerbrokenOudeKoppeling,
}

/// <summary>
/// De gast-kant (central) van het samenspel-protocol: scannen, verbinden, de
/// begroeting afhandelen, inkomende STAND-regels decoderen en ZET-regels
/// terugsturen.
///
/// <b>Onbewezen zonder hardware.</b> De WinRT-central-API's
/// (<see cref="BluetoothLEAdvertisementWatcher"/>, <see cref="BluetoothLEDevice"/>,
/// <see cref="GattDeviceService"/>) zijn stabiel en bestaan al sinds Windows 10,
/// maar dit bestand is op deze machine niet tegen een echte gastheer getoetst.
/// Zie BLUETOOTH-VOOR-WINDOWS.md, "Hoe te toetsen, zonder en met hardware",
/// stap 4 en 5, voordat dit als bewezen mag gelden — net zoals de Mac-kant
/// zijn eigen CoreBluetooth-code pas op echte hardware kon bewijzen.
///
/// Alle events komen binnen op een achtergrondthread (WinRT-callbacks); de
/// afnemer (het scherm) moet zelf naar de UI-thread marshalen.
/// </summary>
public sealed class GastRadio : IDisposable
{
    /// <summary>Zie <see cref="DuoProtocol"/> — gedeeld met <see cref="GastheerRadio"/>.</summary>
    public const int ProtocolVersie = DuoProtocol.Versie;

    public event Action<GastStatus, string> StatusGewijzigd;
    public event Action<SpelStandGast> NieuweStand;
    public event Action<string> Fout;

    private readonly string _eigenNaam;
    private readonly RegelBuffer _ontvangBuffer = new();

    /// <summary>
    /// Eén regel tegelijk versturen. Zonder dit kan de eigen begroeting nog
    /// half onderweg zijn (twee pakketjes) wanneer de binnengekomen
    /// begroeting van de gastheer meteen een JA teruglaat sturen — dat JA-
    /// pakketje schoof dan tussen de twee KJ-pakketjes in, en op de lijn werd
    /// er één verminkte regel van (en de gastheer wachtte voor eeuwig op een
    /// JA die nooit meer apart aankwam). Precies dit is op hardware ook
    /// gebeurd: zie klaverjas-ble-log.txt van 13 september 2026.
    /// </summary>
    private readonly SemaphoreSlim _zendSlot = new(1, 1);

    private BluetoothLEAdvertisementWatcher _watcher;
    private BluetoothLEDevice _apparaat;
    private GattDeviceService _dienst;
    private GattCharacteristic _naarPerifeer;
    private GattCharacteristic _naarCentraal;

    private volatile bool _gestopt;
    private volatile bool _verbindingBezig;
    private volatile bool _begroet;
    private string _gastheerNaam = "";

    /// <summary>
    /// Waar geweest op echte hardware (een iPhone met een verouderde
    /// Bluetooth-koppeling in Windows, zie klaverjas-ble-log.txt): het
    /// apparaat meldt zich al als <c>Connected</c> op het moment dat we het
    /// net gevonden hebben, nog vóór we zelf iets hebben opgezet — terwijl een
    /// eerlijke, verse verbinding hier altijd met <c>Disconnected</c> begint
    /// en pas ná onze eigen stappen via <see cref="OpVerbindingGewijzigd"/>
    /// naar <c>Connected</c> gaat. Valt de verbinding daarna, nog vóór de
    /// begroeting, alsnog weg, dan is dat een sterke aanwijzing voor precies
    /// dat probleem in plaats van een gewoon wegvallen.
    /// </summary>
    private volatile bool _meteenAlVerbondenGezien;

    /// <summary>
    /// true zodra deze radio definitief is opgehouden (mislukt of expliciet
    /// gestopt) — voor de UI, die het "Samen spelen (zoeken)"-vinkje dan zelf
    /// moet uitzetten in plaats van aangevinkt te laten staan terwijl er niets
    /// meer verbonden is.
    /// </summary>
    public bool IsGestopt => _gestopt;

    public GastRadio(string eigenNaam = null)
    {
        _eigenNaam = string.IsNullOrWhiteSpace(eigenNaam) ? Environment.MachineName : eigenNaam;
    }

    /// <summary>Begint met scannen naar een gastheer die de klaverjas-dienst adverteert.</summary>
    public void Start()
    {
        BleLog.Zeg("Start() - scannen begint");
        _gestopt = false;
        _meteenAlVerbondenGezien = false;
        StatusGewijzigd?.Invoke(GastStatus.ZoektNaarApparaat, "");

        _watcher = new BluetoothLEAdvertisementWatcher { ScanningMode = BluetoothLEScanningMode.Active };
        _watcher.AdvertisementFilter.Advertisement.ServiceUuids.Add(UartDienst.Dienst);
        _watcher.Received += OpAdvertentieOntvangen;
        _watcher.Stopped += (_, e) =>
        {
            BleLog.Zeg($"watcher gestopt: {e.Error}");
            if (!_gestopt && !_verbindingBezig)
                Fout?.Invoke($"Scannen gestopt: {e.Error}");
        };
        _watcher.Start();
    }

    /// <summary>Sluit de verbinding en stopt met scannen. Kan altijd veilig aangeroepen worden.</summary>
    public void Stop()
    {
        BleLog.Zeg("Stop() aangeroepen");
        _gestopt = true;
        try { _watcher?.Stop(); } catch { /* al gestopt */ }
        _watcher = null;
        _begroet = false;
        _verbindingBezig = false;

        var naarCentraal = _naarCentraal;
        _naarCentraal = null;
        _naarPerifeer = null;

        if (naarCentraal != null)
        {
            naarCentraal.ValueChanged -= OpWaardeVeranderd;
            // Eerst netjes afmelden (CCCD terug naar None) vóórdat alles
            // wordt afgebroken. Zonder dit ziet de gastheer nooit een
            // "didUnsubscribeFrom" en blijft hij denken dat er nog een gast
            // aan de lijn hangt — precies het soort onopgeruimde toestand
            // waardoor een volgende verbindingspoging (ook met een ander
            // toestel) niets meer vindt. Dit gebeurt op de achtergrond: Stop()
            // zelf blijft synchroon en mag altijd meteen aangeroepen worden.
            _ = AfmeldenEnOpruimen(naarCentraal);
        }
        else
        {
            RuimApparaatOp();
        }
    }

    private async Task AfmeldenEnOpruimen(GattCharacteristic naarCentraal)
    {
        try
        {
            await naarCentraal.WriteClientCharacteristicConfigurationDescriptorAsync(
                GattClientCharacteristicConfigurationDescriptorValue.None);
        }
        catch
        {
            // Apparaat is al weg, of de afmelding lukt niet meer — dan is er
            // hoe dan ook niets meer aan te doen, alleen zelf nog opruimen.
        }
        RuimApparaatOp();
    }

    /// <summary>
    /// De dienst moet in leven blijven zolang de karakteristieken gebruikt
    /// worden: hem eerder sluiten (bijvoorbeeld met een lokale `using` direct
    /// na het ophalen) maakt de karakteristieken ongeldig en breekt
    /// schrijven/notificaties midden in de verbinding. Pas hier, bij het echt
    /// afsluiten, mogen dienst en apparaat dicht.
    /// </summary>
    private void RuimApparaatOp()
    {
        _dienst?.Dispose();
        _dienst = null;

        if (_apparaat != null) _apparaat.ConnectionStatusChanged -= OpVerbindingGewijzigd;
        _apparaat?.Dispose();
        _apparaat = null;
    }

    public void Dispose()
    {
        Stop();
        _zendSlot.Dispose();
    }

    // -------------------------------------------------------- verbinden

    private async void OpAdvertentieOntvangen(BluetoothLEAdvertisementWatcher watcher,
                                               BluetoothLEAdvertisementReceivedEventArgs advertentie)
    {
        if (_verbindingBezig || _gestopt) return;
        _verbindingBezig = true;
        try { watcher.Stop(); } catch { /* race met Stop() elders */ }

        BleLog.Zeg($"advertentie ontvangen: naam=\"{advertentie.Advertisement.LocalName}\" adres={advertentie.BluetoothAddress:X}");
        StatusGewijzigd?.Invoke(GastStatus.VerbindtMet, advertentie.Advertisement.LocalName);

        try
        {
            _apparaat = await BluetoothLEDevice.FromBluetoothAddressAsync(advertentie.BluetoothAddress);
            if (_apparaat == null) { MeldFout("Kon geen verbinding maken met het apparaat."); return; }
            BleLog.Zeg($"apparaat gevonden: \"{_apparaat.Name}\", status={_apparaat.ConnectionStatus}");
            _meteenAlVerbondenGezien = _apparaat.ConnectionStatus == BluetoothConnectionStatus.Connected;

            _apparaat.ConnectionStatusChanged += OpVerbindingGewijzigd;

            // Vlak na het verbinden kan de GATT-sessie nog niet helemaal klaar
            // zijn: de dienst zoeken lukt dan soms pas een paar honderd ms
            // later, ook al adverteerde het apparaat 'm net nog (de watcher
            // filtert immers al op precies dit UUID). Een enkele mislukte
            // poging is dus niet meteen "dienst bestaat niet".
            var diensten = await MetPogingen("dienst opzoeken",
                () => _apparaat.GetGattServicesForUuidAsync(UartDienst.Dienst, BluetoothCacheMode.Uncached),
                r => r.Status == GattCommunicationStatus.Success && r.Services.Count > 0);
            BleLog.Zeg($"dienst opgezocht: status={diensten.Status}, aantal gevonden={diensten.Services.Count}");
            if (diensten.Status != GattCommunicationStatus.Success || diensten.Services.Count == 0)
            { MeldFout("De klaverjas-dienst is niet gevonden op dit apparaat."); return; }

            // Bewust niet met een lokale `using`: de dienst moet in leven
            // blijven zolang _naarPerifeer/_naarCentraal gebruikt worden.
            // Stop() sluit hem pas als de verbinding echt wordt afgebroken.
            _dienst = diensten.Services[0];

            var schrijfKenmerken = await MetPogingen("kenmerk naarPerifeer opzoeken",
                () => _dienst.GetCharacteristicsForUuidAsync(UartDienst.NaarPerifeer, BluetoothCacheMode.Uncached),
                r => r.Status == GattCommunicationStatus.Success && r.Characteristics.Count > 0);
            var leesKenmerken = await MetPogingen("kenmerk naarCentraal opzoeken",
                () => _dienst.GetCharacteristicsForUuidAsync(UartDienst.NaarCentraal, BluetoothCacheMode.Uncached),
                r => r.Status == GattCommunicationStatus.Success && r.Characteristics.Count > 0);
            BleLog.Zeg($"kenmerken opgezocht: naarPerifeer status={schrijfKenmerken.Status} aantal={schrijfKenmerken.Characteristics.Count}, " +
                       $"naarCentraal status={leesKenmerken.Status} aantal={leesKenmerken.Characteristics.Count}");

            _naarPerifeer = schrijfKenmerken.Characteristics.FirstOrDefault();
            _naarCentraal = leesKenmerken.Characteristics.FirstOrDefault();
            if (_naarPerifeer == null || _naarCentraal == null)
            { MeldFout("De verwachte bluetooth-kenmerken ontbreken."); return; }
            BleLog.Zeg($"naarPerifeer eigenschappen={_naarPerifeer.CharacteristicProperties}, " +
                       $"naarCentraal eigenschappen={_naarCentraal.CharacteristicProperties}");

            _naarCentraal.ValueChanged += OpWaardeVeranderd;
            var inschrijfResultaat = await _naarCentraal.WriteClientCharacteristicConfigurationDescriptorAsync(
                GattClientCharacteristicConfigurationDescriptorValue.Notify);
            BleLog.Zeg($"inschrijven op meldingen: resultaat={inschrijfResultaat}");
            if (inschrijfResultaat != GattCommunicationStatus.Success)
            { MeldFout("Kon niet inschrijven op meldingen van de gastheer."); return; }

            StatusGewijzigd?.Invoke(GastStatus.WachtOpBegroeting, "");
            string eigenGroet = DuoBericht.Kj(ProtocolVersie, Applicatieversie(), _eigenNaam).NaarRegel();
            BleLog.Zeg($"eigen begroeting versturen: \"{eigenGroet}\"");
            await StuurRegelAsync(eigenGroet);
            BleLog.Zeg("eigen begroeting verstuurd, wacht nu op begroeting van de gastheer");
        }
        catch (Exception ex)
        {
            BleLog.Zeg($"UITZONDERING bij verbinden: {ex}");
            if (_gestopt)
            {
                // De verbinding viel al weg vlak vóórdat deze aanroep kon
                // voltooien: OpVerbindingGewijzigd (hieronder) zag Disconnected,
                // meldde dat al zelf als Verbroken en riep zelf al Stop() aan —
                // dat maakt _apparaat/_dienst halverwege ongeldig, wat hier
                // altijd als een kale TaskCanceledException ("a task was
                // canceled") naar boven komt. Geen aparte fout: de gebruiker
                // heeft de echte reden (Verbroken) al gezien, dus die niet
                // overschrijven met deze onduidelijke Engelse tekst.
                BleLog.Zeg("  -> genegeerd: de verbinding was net al verbroken");
                return;
            }
            MeldFout($"Verbinden mislukt: {ex.Message}");
        }
    }

    private void OpVerbindingGewijzigd(BluetoothLEDevice apparaat, object _)
    {
        BleLog.Zeg($"verbindingsstatus gewijzigd: {apparaat.ConnectionStatus}");
        if (apparaat.ConnectionStatus != BluetoothConnectionStatus.Disconnected || _gestopt) return;

        // Zie _meteenAlVerbondenGezien: dit precieze patroon (meteen al
        // Connected, dan toch weg vóór de begroeting) bleek op hardware een
        // verouderde Bluetooth-koppeling in Windows voor dit apparaat, niet
        // een gewoon wegvallen — dus een aparte, bruikbare melding in plaats
        // van de generieke "Verbinding verbroken".
        bool oudeKoppeling = _meteenAlVerbondenGezien && !_begroet;
        StatusGewijzigd?.Invoke(oudeKoppeling ? GastStatus.VerbrokenOudeKoppeling : GastStatus.Verbroken, "");
        Stop();
    }

    private void MeldFout(string tekst)
    {
        BleLog.Zeg($"FOUT: {tekst}");
        Fout?.Invoke(tekst);
        Stop();
    }

    /// <summary>
    /// Dezelfde waarde die als <c>&lt;appversie&gt;</c> in de begroeting meegaat
    /// — ook bruikbaar op het scherm, zie <c>SpelForm</c>.
    /// </summary>
    public static string Applicatieversie() =>
        System.Reflection.Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "1.0";

    /// <summary>
    /// Probeert <paramref name="actie"/> tot vier keer, met een oplopende
    /// pauze ertussen, zolang <paramref name="voldoetAl"/> nog niet waar is.
    /// Alleen voor GATT-opzoekingen vlak na het verbinden: die kunnen leeg
    /// terugkomen puur omdat de sessie nog niet helemaal klaarstaat, niet
    /// omdat er echt niets is.
    /// </summary>
    private static async Task<T> MetPogingen<T>(string omschrijving, Func<IAsyncOperation<T>> actie, Func<T, bool> voldoetAl)
    {
        T resultaat = default;
        for (int poging = 1; poging <= 4; poging++)
        {
            resultaat = await actie();
            if (voldoetAl(resultaat)) return resultaat;
            BleLog.Zeg($"{omschrijving}: poging {poging} leverde nog niets op, {(poging < 4 ? "nog eens proberen" : "opgeven")}");
            if (poging < 4) await Task.Delay(poging * 300);
        }
        return resultaat;
    }

    // -------------------------------------------------------- ontvangen

    private void OpWaardeVeranderd(GattCharacteristic karakteristiek, GattValueChangedEventArgs argumenten)
    {
        var reader = DataReader.FromBuffer(argumenten.CharacteristicValue);
        var pakket = new byte[reader.UnconsumedBufferLength];
        reader.ReadBytes(pakket);
        BleLog.Zeg($"notificatie ontvangen: {pakket.Length} bytes");

        foreach (string regel in _ontvangBuffer.VoegToe(pakket))
            VerwerkRegel(regel);
    }

    private async void VerwerkRegel(string regel)
    {
        BleLog.Zeg($"regel compleet: \"{regel}\"");
        DuoBericht bericht = DuoBericht.Ontleed(regel);
        if (bericht == null) { BleLog.Zeg("  -> niet te ontleden, genegeerd"); return; }

        switch (bericht.Type)
        {
            case DuoBerichtType.Kj:
                if (bericht.Versie != ProtocolVersie)
                {
                    MeldFout($"Protocolversie komt niet overeen (gastheer {bericht.Versie}, deze app {ProtocolVersie}).");
                    return;
                }
                _gastheerNaam = bericht.Naam;
                try { await StuurRegelAsync(DuoBericht.Stat(DuoProtocol.LegeStatistiek).NaarRegel()); }
                catch (Exception ex) { MeldFout($"Kon STAT niet versturen: {ex.Message}"); }
                break;

            case DuoBerichtType.Stat:
                // Inhoud wordt genegeerd (minimale, correcte deelname — zie
                // DuoProtocol.LegeStatistiek); alleen dat hij binnenkomt telt,
                // anders blijft de begroeting hangen vóór de JA.
                if (_begroet) return;
                try
                {
                    await StuurRegelAsync(DuoBericht.Ja(ProtocolVersie).NaarRegel());
                    _begroet = true;
                    StatusGewijzigd?.Invoke(GastStatus.Verbonden, _gastheerNaam);
                }
                catch (Exception ex)
                {
                    MeldFout($"Kon de begroeting niet beantwoorden: {ex.Message}");
                }
                break;

            case DuoBerichtType.Stand:
                if (!_begroet) return; // eerst de begroeting, dan pas standen vertrouwen
                try { NieuweStand?.Invoke(DuoStand.DecodeerStand(bericht.Base64)); }
                catch (Exception ex) { Fout?.Invoke($"Onleesbare STAND genegeerd: {ex.Message}"); }
                break;

            case DuoBerichtType.Ja:
            case DuoBerichtType.Pols:
                break; // hoort van de gastheer niet te komen resp. mag genegeerd worden
        }
    }

    // -------------------------------------------------------- versturen

    public Task StuurTroefAsync(int kleur) => StuurZetAsync(GastZet.VoorTroef(kleur));

    public Task StuurKaartAsync(char naam, int kleur) => StuurZetAsync(GastZet.VoorKaart(naam, kleur));

    /// <summary>
    /// De "volgende slag"-tik. Mag altijd gestuurd worden zodra de laatste
    /// STAND <c>wachtOpVerder == true</c> had, ongeacht wie er aan zet is.
    /// </summary>
    public Task StuurVerderAsync() => StuurZetAsync(GastZet.VoorVerder());

    private Task StuurZetAsync(GastZet zet) => StuurRegelAsync(DuoBericht.Zet(DuoStand.CodeerZet(zet)).NaarRegel());

    private async Task StuurRegelAsync(string regel)
    {
        var kenmerk = _naarPerifeer ?? throw new InvalidOperationException("Nog niet verbonden.");

        // Op slot: een andere gelijktijdige aanroep (bijvoorbeeld het antwoord
        // op een net binnengekomen begroeting, vanuit de notificatie-callback)
        // mag zijn pakketjes nooit tussen die van deze regel door schuiven —
        // zie de aantekening bij _zendSlot hierboven.
        await _zendSlot.WaitAsync();
        try
        {
            var pakketten = RegelSplitser.SplitsVoorVerzending(regel, DuoProtocol.PakketGrootte);
            for (int i = 0; i < pakketten.Count; i++)
            {
                var schrijver = new DataWriter();
                schrijver.WriteBytes(pakketten[i]);
                // WriteWithResponse in plaats van WriteWithoutResponse: dat kost
                // een kleine omweg (een echte ATT-bevestiging van de gastheer),
                // maar WriteWithoutResponse geeft "Success" terug zodra de lokale
                // stack het pakket accepteert — dat bewijst niet dat het ook echt
                // aankwam. De Mac-kant ondersteunt allebei
                // (`properties: [.write, .writeWithoutResponse]`).
                var resultaat = await kenmerk.WriteValueAsync(schrijver.DetachBuffer(), GattWriteOption.WriteWithResponse);
                BleLog.Zeg($"  pakket {i + 1}/{pakketten.Count} ({pakketten[i].Length} bytes) geschreven: {resultaat}");
                if (resultaat != GattCommunicationStatus.Success)
                    throw new IOException($"Schrijven naar de gastheer mislukt: {resultaat}");
            }
        }
        finally
        {
            _zendSlot.Release();
        }
    }
}
