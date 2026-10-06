using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Storage.Streams;

namespace Klaverjas.Ble;

/// <summary>Voor de statusregel op het scherm; puur informatief.</summary>
public enum GastheerStatus
{
    NietOpen,
    OpentZich,
    WachtOpGast,
    WachtOpBegroeting,
    Verbonden,
    Verbroken,
}

/// <summary>
/// De gastheer-kant (peripheral) van het samenspel-protocol: adverteren,
/// wachten tot een gast zich abonneert, de begroeting afhandelen, ZET-regels
/// van de gast decoderen en STAND-regels terugsturen.
///
/// <b>Onbewezen zonder hardware.</b> Zie de aantekening bij <see cref="GastRadio"/>
/// en BLUETOOTH-VOOR-WINDOWS2.1.0.md, "Welke kant bouwt Windows eerst": de
/// WinRT-peripheral-API's (<see cref="GattServiceProvider"/>) hangen af van of
/// de adapter/driver dat ondersteunt, en zijn in de praktijk minder
/// betrouwbaar dan de central-rol in <see cref="GastRadio"/> (die inmiddels
/// wél op hardware bewezen is, tegen zowel een Mac als een iPhone). Dit
/// bestand is op deze machine niet tegen een echte gast getoetst.
///
/// In tegenstelling tot <see cref="GastRadio"/> (die na een mislukking of
/// verbroken verbinding stopt, zie <c>Stop()</c> in de begroetingsfoutafhandeling)
/// blijft het openstellen hier gewoon doorlopen als een gast wegvalt: precies
/// zoals de Mac-kant (<c>BlePerifeer.abonneeVerloren</c>) niet stopt met
/// adverteren, blijft deze radio klaarstaan voor de volgende (of dezelfde)
/// gast tot de gebruiker "openstellen" zelf uitzet.
///
/// Alle events komen binnen op een achtergrondthread (WinRT-callbacks); de
/// afnemer (het scherm) moet zelf naar de UI-thread marshalen.
/// </summary>
public sealed class GastheerRadio : IDisposable
{
    public event Action<GastheerStatus, string> StatusGewijzigd;
    public event Action<GastZet> ZetOntvangen;
    public event Action<string> Fout;

    /// <summary>
    /// Vuurt zodra de begroeting klaar is (de JA van de gast is binnen) — het
    /// moment waarop de gastheer "de eerste STAND" moet sturen (zie het
    /// lijnprotocol in BLUETOOTH-VOOR-WINDOWS2.1.0.md). Deze klasse kent de
    /// huidige <c>SpelView</c> niet zelf (dat is aan <c>SpelForm</c>/<c>KjSpel</c>),
    /// vandaar een event in plaats van hier zelf iets te versturen.
    /// </summary>
    public event Action EersteStandGevraagd;

    private readonly string _eigenNaam;
    private RegelBuffer _ontvangBuffer = new();

    /// <summary>
    /// Op hardware gevonden (klaverjas-ble-log.txt, 16:48:27.679):
    /// <c>GattLocalCharacteristic.WriteRequested</c> kan meerdere keren vlak
    /// na elkaar vuren — bijvoorbeeld KJ, STAT en JA kort na elkaar — en dan
    /// liep <see cref="OpSchrijfVerzoek"/> gelijktijdig op twee threads
    /// tegelijk in <c>_ontvangBuffer.VoegToe(...)</c>, een kale
    /// <see cref="List{T}"/> zonder eigen threadveiligheid: een
    /// <c>ArgumentException</c> uit <c>RemoveRange</c>, en (erger) een kans
    /// dat een regel zoek raakt of de buffer blijvend verschoven raakt. Dit
    /// slot dwingt schrijfverzoeken één voor één af, in plaats van
    /// gelijktijdig.
    /// </summary>
    private readonly object _ontvangSlot = new();

    /// <summary>Zie de aantekening bij hetzelfde veld in <see cref="GastRadio"/>.</summary>
    private readonly SemaphoreSlim _zendSlot = new(1, 1);

    private GattServiceProvider _provider;
    private GattLocalCharacteristic _naarPerifeer;
    private GattLocalCharacteristic _naarCentraal;

    private volatile bool _gestopt;
    private volatile bool _begroet;
    private string _gastNaam = "";

    /// <summary>
    /// true zodra openstellen zelf definitief niet lukt of expliciet gestopt
    /// is — voor de UI, die het "Openstellen"-vinkje dan moet uitzetten. Een
    /// weggevallen gást (zie <see cref="OpAbonneesGewijzigd"/>) telt hier niet
    /// als gestopt: daarna blijft doorgeadverteerd voor de volgende.
    /// </summary>
    public bool IsGestopt => _gestopt;

    public GastheerRadio(string eigenNaam = null)
    {
        _eigenNaam = string.IsNullOrWhiteSpace(eigenNaam) ? Environment.MachineName : eigenNaam;
    }

    /// <summary>Zet de dienst op en begint met adverteren.</summary>
    public async void Start()
    {
        BleLog.Zeg("GastheerRadio.Start() - opzetten begint");
        _gestopt = false;
        _begroet = false;
        _ontvangBuffer = new RegelBuffer();
        StatusGewijzigd?.Invoke(GastheerStatus.OpentZich, "");

        try
        {
            var dienstResultaat = await GattServiceProvider.CreateAsync(UartDienst.Dienst);
            if (dienstResultaat.Error != BluetoothError.Success)
            { MeldFout($"Kon de dienst niet aanmaken: {dienstResultaat.Error}"); Stop(); return; }
            _provider = dienstResultaat.ServiceProvider;
            _provider.AdvertisementStatusChanged += (_, e) =>
                BleLog.Zeg($"advertentiestatus gewijzigd: {e.Status}, fout={e.Error}");

            var schrijfParams = new GattLocalCharacteristicParameters
            {
                CharacteristicProperties = GattCharacteristicProperties.Write
                                          | GattCharacteristicProperties.WriteWithoutResponse,
                WriteProtectionLevel = GattProtectionLevel.Plain,
            };
            var schrijfResultaat = await _provider.Service.CreateCharacteristicAsync(UartDienst.NaarPerifeer, schrijfParams);
            if (schrijfResultaat.Error != BluetoothError.Success)
            { MeldFout($"Kon het schrijf-kenmerk niet aanmaken: {schrijfResultaat.Error}"); Stop(); return; }
            _naarPerifeer = schrijfResultaat.Characteristic;
            _naarPerifeer.WriteRequested += OpSchrijfVerzoek;

            var meldParams = new GattLocalCharacteristicParameters
            {
                CharacteristicProperties = GattCharacteristicProperties.Notify,
                ReadProtectionLevel = GattProtectionLevel.Plain,
            };
            var meldResultaat = await _provider.Service.CreateCharacteristicAsync(UartDienst.NaarCentraal, meldParams);
            if (meldResultaat.Error != BluetoothError.Success)
            { MeldFout($"Kon het meld-kenmerk niet aanmaken: {meldResultaat.Error}"); Stop(); return; }
            _naarCentraal = meldResultaat.Characteristic;
            _naarCentraal.SubscribedClientsChanged += OpAbonneesGewijzigd;

            if (_gestopt) return; // Stop() kan intussen al aangeroepen zijn

            _provider.StartAdvertising(new GattServiceProviderAdvertisingParameters
            {
                IsDiscoverable = true,
                IsConnectable = true,
            });
            BleLog.Zeg("adverteren gestart, wacht op een gast");
            StatusGewijzigd?.Invoke(GastheerStatus.WachtOpGast, "");
        }
        catch (Exception ex)
        {
            BleLog.Zeg($"UITZONDERING bij openstellen: {ex}");
            MeldFout($"Openstellen mislukt: {ex.Message}");
            Stop();
        }
    }

    /// <summary>Stopt met adverteren en breekt alles af. Kan altijd veilig aangeroepen worden.</summary>
    public void Stop()
    {
        BleLog.Zeg("GastheerRadio.Stop() aangeroepen");
        _gestopt = true;
        _begroet = false;
        _gastNaam = "";

        var naarPerifeer = _naarPerifeer;
        _naarPerifeer = null;
        if (naarPerifeer != null) naarPerifeer.WriteRequested -= OpSchrijfVerzoek;

        var naarCentraal = _naarCentraal;
        _naarCentraal = null;
        if (naarCentraal != null) naarCentraal.SubscribedClientsChanged -= OpAbonneesGewijzigd;

        try { _provider?.StopAdvertising(); } catch { /* al gestopt, of nooit begonnen */ }
        _provider = null;
    }

    public void Dispose()
    {
        Stop();
        _zendSlot.Dispose();
    }

    // -------------------------------------------------------- verbinden

    /// <summary>
    /// Vuurt zowel bij een nieuwe abonnee als bij het wegvallen van één.
    /// Beide kanten sturen hun begroeting "meteen zodra de verbinding en de
    /// karakteristieken klaarstaan, zonder op elkaar te wachten" (zie het
    /// lijnprotocol) — voor de gastheer is dat dit moment: pas als een gast
    /// zich op <c>naarCentraal</c> abonneert, kan er ook echt iets naartoe
    /// gestuurd worden.
    /// </summary>
    private async void OpAbonneesGewijzigd(GattLocalCharacteristic sender, object args)
    {
        int aantal = sender.SubscribedClients.Count;
        BleLog.Zeg($"aantal abonnees gewijzigd: {aantal}");

        if (_gestopt) return;

        if (aantal > 0 && !_begroet)
        {
            StatusGewijzigd?.Invoke(GastheerStatus.WachtOpBegroeting, "");
            try
            {
                string eigenGroet = DuoBericht.Kj(DuoProtocol.Versie, GastRadio.Applicatieversie(), _eigenNaam).NaarRegel();
                BleLog.Zeg($"eigen begroeting versturen: \"{eigenGroet}\"");
                await StuurRegelAsync(eigenGroet);
                BleLog.Zeg("eigen begroeting verstuurd, wacht nu op begroeting van de gast");
            }
            catch (Exception ex)
            {
                if (_gestopt) return;
                MeldFout($"Kon de begroeting niet versturen: {ex.Message}");
            }
        }
        else if (aantal == 0 && _begroet)
        {
            // Zie de klasse-aantekening: dit stopt het openstellen zelf niet,
            // alleen de lopende sessie — er wordt gewoon doorgeadverteerd.
            _begroet = false;
            _gastNaam = "";
            lock (_ontvangSlot) { _ontvangBuffer = new RegelBuffer(); }
            StatusGewijzigd?.Invoke(GastheerStatus.Verbroken, "");
        }
    }

    private async void OpSchrijfVerzoek(GattLocalCharacteristic sender, GattWriteRequestedEventArgs args)
    {
        var deferral = args.GetDeferral();
        try
        {
            var verzoek = await args.GetRequestAsync();
            if (verzoek == null) return; // te laat: geen verzoek meer beschikbaar

            var reader = DataReader.FromBuffer(verzoek.Value);
            var pakket = new byte[reader.UnconsumedBufferLength];
            reader.ReadBytes(pakket);
            BleLog.Zeg($"schrijfverzoek ontvangen: {pakket.Length} bytes");

            // Alleen bevestigen als de gast dat ook vroeg (WriteWithResponse) —
            // precies zoals GastRadio.StuurRegelAsync zelf WriteWithResponse
            // gebruikt als hij de gast-kant speelt, dus een andere Windows-
            // laptop als gast verwacht hier een respons.
            if (verzoek.Option == GattWriteOption.WriteWithResponse)
                verzoek.Respond();

            List<string> regels;
            lock (_ontvangSlot) { regels = _ontvangBuffer.VoegToe(pakket); }
            foreach (string regel in regels)
                VerwerkRegel(regel);
        }
        catch (Exception ex)
        {
            BleLog.Zeg($"UITZONDERING bij schrijfverzoek: {ex}");
        }
        finally
        {
            deferral.Complete();
        }
    }

    // -------------------------------------------------------- ontvangen

    private async void VerwerkRegel(string regel)
    {
        BleLog.Zeg($"regel compleet: \"{regel}\"");
        DuoBericht bericht = DuoBericht.Ontleed(regel);
        if (bericht == null) { BleLog.Zeg("  -> niet te ontleden, genegeerd"); return; }

        switch (bericht.Type)
        {
            case DuoBerichtType.Kj:
                if (bericht.Versie != DuoProtocol.Versie)
                {
                    MeldFout($"Protocolversie komt niet overeen (gast {bericht.Versie}, deze app {DuoProtocol.Versie}).");
                    return;
                }
                _gastNaam = bericht.Naam;
                try { await StuurRegelAsync(DuoBericht.Stat(DuoProtocol.LegeStatistiek).NaarRegel()); }
                catch (Exception ex) { if (!_gestopt) MeldFout($"Kon STAT niet versturen: {ex.Message}"); }
                break;

            case DuoBerichtType.Stat:
                // Inhoud genegeerd (minimale, correcte deelname — zie
                // DuoProtocol.LegeStatistiek); alleen dat hij binnenkomt telt.
                break;

            case DuoBerichtType.Ja:
                if (bericht.Versie != DuoProtocol.Versie)
                {
                    MeldFout($"Protocolversie komt niet overeen (gast {bericht.Versie}, deze app {DuoProtocol.Versie}).");
                    return;
                }
                _begroet = true;
                StatusGewijzigd?.Invoke(GastheerStatus.Verbonden, _gastNaam);
                EersteStandGevraagd?.Invoke();
                break;

            case DuoBerichtType.Zet:
                if (!_begroet) return; // eerst de begroeting, dan pas een ZET vertrouwen
                try { ZetOntvangen?.Invoke(DuoStand.DecodeerZet(bericht.Base64)); }
                catch (Exception ex) { Fout?.Invoke($"Onleesbare ZET genegeerd: {ex.Message}"); }
                break;

            case DuoBerichtType.Stand:
            case DuoBerichtType.Pols:
                break; // hoort niet van de gast te komen, resp. mag genegeerd worden
        }
    }

    // -------------------------------------------------------- versturen

    public Task StuurStandAsync(SpelStandGast stand) =>
        StuurRegelAsync(DuoBericht.Stand(DuoStand.CodeerStand(stand)).NaarRegel());

    private void MeldFout(string tekst)
    {
        BleLog.Zeg($"FOUT: {tekst}");
        Fout?.Invoke(tekst);
    }

    private async Task StuurRegelAsync(string regel)
    {
        var kenmerk = _naarCentraal ?? throw new InvalidOperationException("Nog niet opengesteld.");

        // Zie de aantekening bij _zendSlot in GastRadio: op slot, zodat twee
        // gelijktijdige regels (bijvoorbeeld een STAT-antwoord vanuit de
        // ontvangst-callback, terwijl de motor net een STAND wil sturen) niet
        // door elkaar heen schuiven.
        await _zendSlot.WaitAsync();
        try
        {
            var pakketten = RegelSplitser.SplitsVoorVerzending(regel, DuoProtocol.PakketGrootte);
            foreach (var pakket in pakketten)
            {
                var schrijver = new DataWriter();
                schrijver.WriteBytes(pakket);
                var resultaten = await kenmerk.NotifyValueAsync(schrijver.DetachBuffer());
                foreach (var resultaat in resultaten)
                {
                    if (resultaat.Status != GattCommunicationStatus.Success)
                        BleLog.Zeg($"  melding aan een abonnee mislukt: {resultaat.Status}");
                }
            }
        }
        finally
        {
            _zendSlot.Release();
        }
    }
}
