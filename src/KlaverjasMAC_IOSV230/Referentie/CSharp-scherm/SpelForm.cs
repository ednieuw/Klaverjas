using System.Drawing.Drawing2D;
using System.Threading;
using Klaverjas.Engine;

namespace Klaverjas.Ui;

/// <summary>
/// Het speelscherm. De speellogica draait op een aparte thread en blokkeert op
/// KiesKaart/KiesTroef/Verder; dit formulier zet die wachtmomenten om in
/// muisklikken en toetsaanslagen.
/// </summary>
public sealed class SpelForm : Form, IKjUi
{
    private enum Modus { Wachten, KiesKaart, KiesTroef, Verder }

    private KjSpel _spel;
    private Thread _motor;
    private CancellationTokenSource _stop;

    private volatile SpelView _view = new();
    private volatile Modus _modus = Modus.Wachten;
    private readonly SemaphoreSlim _antwoord = new(0, 1);

    private (char Naam, int Kleur) _gekozenKaart;
    private int _gekozenTroef;
    private string _balk = "";

    private readonly List<(RectangleF Vak, KaartView Kaart)> _klikbaar = new();
    private readonly List<(RectangleF Vak, int Kleur)> _troefKnoppen = new();
    private KaartView _onderMuis;

    private ToolStripMenuItem _miDemo, _miOpen, _miAuto, _miOrigineel, _miDansAuto, _miSnel;

    // Snel spelen zonder kaarten, en wanneer er voor het laatst getekend is.
    private volatile bool _snel;
    private DateTime _laatsteTeken = DateTime.MinValue;
    private ToolStripMenuItem _miSpel, _miNieuw, _miDans, _miAfsluiten, _miOpties, _miStatistiek;
    private ToolStripMenuItem _miTaal, _miNederlands, _miEngels;
    private ToolStripMenuItem _miSpeelwijze, _miNoordKop, _miNoordEd, _miNoordLoggen;
    private ToolStripMenuItem _miZuidKop, _miZuidEd, _miZuidLoggen;

    // Blijft bewaard als er een nieuwe partij begint.
    private readonly bool[] _zoektOnthouden = new bool[2];

    // Zit de speler drie minuten stil, dan begint de kaartendans vanzelf.
    private readonly System.Windows.Forms.Timer _rustKlok = new() { Interval = 10_000 };
    private DateTime _laatsteInvoer = DateTime.UtcNow;
    private bool _dansOpen;

    public SpelForm()
    {
        Text = Taal.Titel;
        DoubleBuffered = true;
        // Zonder dit wordt bij het slepen van de vensterrand alleen het nieuwe
        // stuk hertekend, waardoor het puntenpaneel en de kaarten half blijven
        // staan: de hele indeling wordt immers uit de vensterafmeting berekend.
        SetStyle(ControlStyles.ResizeRedraw | ControlStyles.OptimizedDoubleBuffer
                 | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
        BackColor = Color.FromArgb(18, 74, 46);
        MinimumSize = new Size(760, 560);
        StartPosition = FormStartPosition.CenterScreen;

        // Ruim genoeg voor kaarten op dubbele grootte (106x166) naast het
        // speelveld, maar nooit groter dan het bureaublad.
        var werkvlak = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1024, 768);
        ClientSize = new Size(Math.Min(1300, werkvlak.Width - 60),
                              Math.Min(950, werkvlak.Height - 80));
        KeyPreview = true;

        BouwMenu();
        StartMotor();

        if (Program.StartSnel)
        {
            // Beide kanten door de computer, en elk een eigen speelwijze zodat
            // je meteen ziet hoe ze zich tot elkaar verhouden.
            _snel = true;
            _miSnel.Checked = true;
            _miDemo.Checked = true;
            _miDansAuto.Checked = false;
            _spel.E.S.Comp = true;
            _zoektOnthouden[1] = true;
            _spel.E.S.Zoekt[1] = true;
            ZetMenuTeksten();
        }

        _rustKlok.Tick += (_, _) => KijkOfDansMag();
        _rustKlok.Start();
    }

    // ------------------------------------------------------- kaartendans

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        // Zoals in het origineel: main() begon met intro_text(), dat meteen de
        // kaartendans liet lopen tot je een toets indrukte. Het delen gebeurt
        // ondertussen al op de speelthread, die netjes blijft wachten.
        if (_miDansAuto?.Checked == true) StartDans();
    }

    private void KijkOfDansMag()
    {
        if (_dansOpen || _miDansAuto?.Checked != true) return;
        if (_snel) return;                    // dan is het scherm al bezet
        if (WindowState == FormWindowState.Minimized) return;
        // Niet voordringen wanneer je in een ander programma bezig bent.
        if (!ContainsFocus) return;
        if ((DateTime.UtcNow - _laatsteInvoer).TotalMinutes < 3) return;
        StartDans();
    }

    private void StartDans()
    {
        if (_dansOpen) return;
        _dansOpen = true;
        try
        {
            using var f = new KaartenDansForm();
            f.ShowDialog(this);
        }
        finally
        {
            _dansOpen = false;
            _laatsteInvoer = DateTime.UtcNow;
            Invalidate();
        }
    }

    private void BouwMenu()
    {
        var menu = new MenuStrip();

        _miSpel = new ToolStripMenuItem();
        _miNieuw = new ToolStripMenuItem("", null, (_, _) => HerstartMotor());
        _miDans = new ToolStripMenuItem("", null, (_, _) => StartDans());
        _miAfsluiten = new ToolStripMenuItem("", null, (_, _) => Close());
        _miStatistiek = new ToolStripMenuItem("", null, (_, _) => ToonStatistiek());
        _miSpel.DropDownItems.Add(_miNieuw);
        _miSpel.DropDownItems.Add(_miDans);
        _miSpel.DropDownItems.Add(_miStatistiek);
        _miSpel.DropDownItems.Add(new ToolStripSeparator());
        _miSpel.DropDownItems.Add(_miAfsluiten);

        _miOpties = new ToolStripMenuItem();
        _miDemo = new ToolStripMenuItem("", null,
            (s, _) => { _miDemo.Checked = !_miDemo.Checked; _spel.E.S.Comp = _miDemo.Checked; });
        _miOpen = new ToolStripMenuItem("", null,
            (s, _) => { _miOpen.Checked = !_miOpen.Checked; _spel.E.S.Dicht = !_miOpen.Checked; Invalidate(); });
        _miAuto = new ToolStripMenuItem("", null,
            (s, _) => { _miAuto.Checked = !_miAuto.Checked; });
        _miOrigineel = new ToolStripMenuItem("", null,
            (s, _) => { _miOrigineel.Checked = !_miOrigineel.Checked; KaartTekenaar.Origineel = _miOrigineel.Checked; Invalidate(); })
        { Checked = KaartTekenaar.Origineel };
        _miDansAuto = new ToolStripMenuItem("", null,
            (s, _) => { _miDansAuto.Checked = !_miDansAuto.Checked; _laatsteInvoer = DateTime.UtcNow; })
        { Checked = true };

        // Snel spelen zonder kaarten: het SDEMO uit het origineel, waar
        // Sputimage() het tekenen oversloeg. Beide kanten worden dan door de
        // computer gespeeld, want er valt niets te klikken.
        _miSnel = new ToolStripMenuItem("", null, (s, _) =>
        {
            _miSnel.Checked = !_miSnel.Checked;
            _snel = _miSnel.Checked;
            if (_snel)
            {
                _miDemo.Checked = true;
                if (_spel != null) _spel.E.S.Comp = true;
                Deblokkeer();                 // eventueel wachten op "verder" opheffen
            }
            Invalidate();
        });

        // Welke speelwijze gebruikt elke kant: de vuistregels van Ed of de
        // zoekende speler van Loggen.
        _miSpeelwijze = new ToolStripMenuItem();
        _miNoordKop = new ToolStripMenuItem { Enabled = false };
        _miNoordEd = new ToolStripMenuItem("", null, (_, _) => ZetSpeelwijze(1, false));
        _miNoordLoggen = new ToolStripMenuItem("", null, (_, _) => ZetSpeelwijze(1, true));
        _miZuidKop = new ToolStripMenuItem { Enabled = false };
        _miZuidEd = new ToolStripMenuItem("", null, (_, _) => ZetSpeelwijze(0, false));
        _miZuidLoggen = new ToolStripMenuItem("", null, (_, _) => ZetSpeelwijze(0, true));
        _miSpeelwijze.DropDownItems.Add(_miNoordKop);
        _miSpeelwijze.DropDownItems.Add(_miNoordEd);
        _miSpeelwijze.DropDownItems.Add(_miNoordLoggen);
        _miSpeelwijze.DropDownItems.Add(new ToolStripSeparator());
        _miSpeelwijze.DropDownItems.Add(_miZuidKop);
        _miSpeelwijze.DropDownItems.Add(_miZuidEd);
        _miSpeelwijze.DropDownItems.Add(_miZuidLoggen);

        _miTaal = new ToolStripMenuItem();
        _miNederlands = new ToolStripMenuItem("", null, (_, _) => ZetTaal(engels: false));
        _miEngels = new ToolStripMenuItem("", null, (_, _) => ZetTaal(engels: true));
        _miTaal.DropDownItems.Add(_miNederlands);
        _miTaal.DropDownItems.Add(_miEngels);

        _miOpties.DropDownItems.Add(_miOrigineel);
        _miOpties.DropDownItems.Add(new ToolStripSeparator());
        _miOpties.DropDownItems.Add(_miDemo);
        _miOpties.DropDownItems.Add(_miOpen);
        _miOpties.DropDownItems.Add(_miAuto);
        _miOpties.DropDownItems.Add(_miSnel);
        _miOpties.DropDownItems.Add(new ToolStripSeparator());
        _miOpties.DropDownItems.Add(_miDansAuto);
        _miOpties.DropDownItems.Add(new ToolStripSeparator());
        _miOpties.DropDownItems.Add(_miSpeelwijze);
        _miOpties.DropDownItems.Add(_miTaal);

        menu.Items.Add(_miSpel);
        menu.Items.Add(_miOpties);
        MainMenuStrip = menu;
        Controls.Add(menu);

        ZetMenuTeksten();
    }

    private void ZetTaal(bool engels)
    {
        Taal.Engels = engels;
        ZetMenuTeksten();
        Invalidate();
    }

    /// <summary>Alle menuteksten opnieuw ophalen; ook na het wisselen van taal.</summary>
    private void ZetMenuTeksten()
    {
        Text = Taal.Titel;
        _miSpel.Text = Taal.MenuSpel;
        _miNieuw.Text = Taal.MenuNieuw;
        _miDans.Text = Taal.MenuDans;
        _miStatistiek.Text = Taal.MenuStatistieken;
        _miAfsluiten.Text = Taal.MenuAfsluiten;
        _miOpties.Text = Taal.MenuOpties;
        _miOrigineel.Text = Taal.MenuOrigineel;
        _miDemo.Text = Taal.MenuDemo;
        _miOpen.Text = Taal.MenuOpenKaart;
        _miAuto.Text = Taal.MenuAuto;
        _miDansAuto.Text = Taal.MenuDansAuto;
        _miSnel.Text = Taal.MenuSnel;
        _miTaal.Text = Taal.MenuTaal;
        _miNederlands.Text = Taal.MenuNederlands;
        _miEngels.Text = Taal.MenuEngels;
        _miNederlands.Checked = !Taal.Engels;
        _miEngels.Checked = Taal.Engels;

        _miSpeelwijze.Text = Taal.MenuSpeelwijze;
        _miNoordKop.Text = Taal.MenuNoordSpeelt;
        _miZuidKop.Text = Taal.MenuZuidSpeelt;
        _miNoordEd.Text = _miZuidEd.Text = Taal.MenuAiEd;
        _miNoordLoggen.Text = _miZuidLoggen.Text = Taal.MenuAiLoggen;

        bool zuidZoekt = _spel?.E.S.Zoekt[0] ?? false;
        bool noordZoekt = _spel?.E.S.Zoekt[1] ?? false;
        _miNoordEd.Checked = !noordZoekt;
        _miNoordLoggen.Checked = noordZoekt;
        _miZuidEd.Checked = !zuidZoekt;
        _miZuidLoggen.Checked = zuidZoekt;
    }

    private void ToonStatistiek()
    {
        using var dlg = new StatistiekForm(_view.Statistiek);
        dlg.ShowDialog(this);
        _laatsteInvoer = DateTime.UtcNow;
    }

    /// <summary>kant 0 = Zuid, 1 = Noord.</summary>
    private void ZetSpeelwijze(int kant, bool zoekend)
    {
        if (_spel == null) return;
        _spel.E.S.Zoekt[kant] = zoekend;
        _zoektOnthouden[kant] = zoekend;
        ZetMenuTeksten();
    }

    // ------------------------------------------------------------- motor

    private void StartMotor()
    {
        _stop = new CancellationTokenSource();
        _spel = new KjSpel(this);
        _spel.E.S.Comp = _miDemo?.Checked ?? false;
        _spel.E.S.Zoekt[0] = _zoektOnthouden[0];
        _spel.E.S.Zoekt[1] = _zoektOnthouden[1];
        _spel.E.S.Dicht = !(_miOpen?.Checked ?? false);
        _view = _spel.Snapshot();

        _motor = new Thread(() =>
        {
            try { _spel.Loop(_stop.Token); }
            catch (OperationCanceledException) { }
            catch (Exception ex)
            {
                Program.Log(ex);
                try
                {
                    if (!IsDisposed && IsHandleCreated)
                        BeginInvoke(() => MessageBox.Show(this,
                            $"{Taal.FoutInSpellogica}\n\n{ex.GetType().Name}: {ex.Message}\n\n" +
                            $"{Taal.VolledigeMeldingIn}\n{Program.FoutLog}",
                            Taal.Titel, MessageBoxButtons.OK, MessageBoxIcon.Warning));
                }
                catch { }
            }
        })
        { IsBackground = true, Name = "Klaverjas-motor" };
        _motor.Start();
    }

    private void HerstartMotor()
    {
        _stop.Cancel();
        Deblokkeer();

        // Pas een nieuwe motor starten als de oude echt weg is: anders zouden
        // twee speelthreads tegelijk op ditzelfde venster wachten en elkaars
        // antwoorden oppikken.
        if (!_motor.Join(3000))
        {
            MessageBox.Show(this, Taal.VorigePartijReageertNiet,
                            Taal.Titel, MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        StartMotor();
        Invalidate();
    }

    private void Deblokkeer()
    {
        _modus = Modus.Wachten;
        try { _antwoord.Release(); } catch (SemaphoreFullException) { }
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        _stop.Cancel();
        Deblokkeer();
        base.OnFormClosing(e);
    }

    // ------------------------------------------------------------- IKjUi

    public void Toon(SpelView view)
    {
        _view = view;
        if (_snel)
        {
            // Niet wachten, en hooguit een paar keer per seconde tekenen: anders
            // gaat alle tijd naar het scherm in plaats van naar het spelen.
            if ((DateTime.UtcNow - _laatsteTeken).TotalMilliseconds > 250)
            {
                _laatsteTeken = DateTime.UtcNow;
                Hertekenen();
            }
            return;
        }
        Hertekenen();
        if (_spel.E.S.Comp || !view.WachtOpSpeler) Thread.Sleep(_miAuto?.Checked == true ? 120 : 350);
    }

    public (char Naam, int Kleur) KiesKaart(SpelView view)
    {
        _view = view;
        _balk = view.Melding;
        _modus = Modus.KiesKaart;
        Hertekenen();
        _antwoord.Wait(_stop.Token);
        _modus = Modus.Wachten;
        return _gekozenKaart;
    }

    public int KiesTroef(SpelView view)
    {
        _view = view;
        _balk = Taal.KiesDeTroefkleur;
        _modus = Modus.KiesTroef;
        Hertekenen();
        _antwoord.Wait(_stop.Token);
        _modus = Modus.Wachten;
        return _gekozenTroef;
    }

    public void Verder(SpelView view, string tekst)
    {
        _view = view;
        _balk = tekst;
        if (_snel) return;                    // geen adempauze tussen de slagen
        if (_miAuto?.Checked == true)
        {
            _modus = Modus.Wachten;
            Hertekenen();
            Thread.Sleep(900);
            return;
        }
        _modus = Modus.Verder;
        Hertekenen();
        _antwoord.Wait(_stop.Token);
        _modus = Modus.Wachten;
    }

    private void Hertekenen()
    {
        if (IsDisposed || !IsHandleCreated) return;
        // Tussen de controle hierboven en de aanroep kan het venster verdwijnen;
        // dat mag de speelthread niet omver halen.
        try { BeginInvoke(() => Invalidate()); } catch { }
    }

    // ------------------------------------------------------------ invoer

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        _laatsteInvoer = DateTime.UtcNow;
        switch (_modus)
        {
            case Modus.Verder:
                Antwoord();
                break;

            case Modus.KiesTroef:
                foreach (var (vak, kleur) in _troefKnoppen)
                    if (vak.Contains(e.Location)) { _gekozenTroef = kleur; Antwoord(); return; }
                break;

            case Modus.KiesKaart:
                foreach (var (vak, kaart) in _klikbaar)
                    if (vak.Contains(e.Location)) { _gekozenKaart = (kaart.Naam, kaart.Kleur); Antwoord(); return; }
                break;
        }
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        _laatsteInvoer = DateTime.UtcNow;
        KaartView nieuw = null;
        if (_modus == Modus.KiesKaart)
            foreach (var (vak, kaart) in _klikbaar)
                if (vak.Contains(e.Location)) { nieuw = kaart; break; }

        if (!ReferenceEquals(nieuw, _onderMuis))
        {
            _onderMuis = nieuw;
            Cursor = nieuw != null ? Cursors.Hand : Cursors.Default;
            Invalidate();
        }
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        _laatsteInvoer = DateTime.UtcNow;
        if (_modus == Modus.Verder) { Antwoord(); return; }
        if (_modus == Modus.KiesTroef)
        {
            int k = e.KeyCode switch
            {
                Keys.K => 0,
                Keys.S => 1,
                Keys.R => 2,
                Keys.H => 3,
                _ => -1
            };
            if (k >= 0) { _gekozenTroef = k; Antwoord(); }
        }
    }

    private void Antwoord()
    {
        _modus = Modus.Wachten;
        try { _antwoord.Release(); } catch (SemaphoreFullException) { }
    }

    // ----------------------------------------------------------- tekenen

    protected override void OnPaint(PaintEventArgs e)
    {
        // Een venster van niets komt voor tijdens minimaliseren en midden in een
        // sleepbeweging; de indeling wordt uit die maten berekend en penselen
        // met breedte nul zijn ongeldig.
        if (ClientSize.Width < 40 || ClientSize.Height < 40) return;

        try
        {
            Teken(e.Graphics);
        }
        catch (Exception ex)
        {
            // Nooit het programma laten sneuvelen op een tekenfout.
            Program.Log(ex);
            _klikbaar.Clear();
            _troefKnoppen.Clear();
            try { e.Graphics.Clear(BackColor); } catch { }
        }
    }

    private void Teken(Graphics g)
    {
        KaartTekenaar.ZetKwaliteit(g);
        _klikbaar.Clear();
        _troefKnoppen.Clear();

        var v = _view;
        int top = MainMenuStrip?.Height ?? 0;
        float panelW = Math.Clamp(ClientSize.Width * 0.24f, 200f, 290f);
        var speel = new RectangleF(0, top, Math.Max(200, ClientSize.Width - panelW), ClientSize.Height - top);

        TekenAchtergrond(g, new RectangleF(0, top, ClientSize.Width, ClientSize.Height - top));

        if (_snel)
        {
            TekenSnel(g, speel, v);
            TekenPaneel(g, v, new RectangleF(speel.Right, top, ClientSize.Width - speel.Right,
                                             ClientSize.Height - top));
            return;
        }

        // De kaarten zijn per pixel ontworpen, dus alleen hele vergrotingen:
        // 53x83 maal een geheel getal. Kies de grootste die past.
        int k = HeleSchaal((int)speel.Width, (int)speel.Height);
        int ch = OrigineleKaarten.Hoogte * k;

        var rijen = new RectangleF(speel.Left + 20, speel.Top, speel.Width - 40, speel.Height);

        // Tussen de twee tafelrijen extra ruimte: daar steken de dichte kaarten
        // naar elkaar toe uit en die mogen elkaar niet raken.
        int extra = 12 * k;
        int gap = Math.Max(4, ((int)rijen.Height - 4 * ch - extra) / 5);
        int yNoordHand = (int)rijen.Top + gap;
        int yNoordTafel = yNoordHand + ch + gap;
        int yZuidTafel = yNoordTafel + ch + gap + extra;
        int yZuidHand = yZuidTafel + ch + gap;

        var veld = VeldVak(speel, rijen, k, yNoordHand + ch, yZuidHand);

        bool magHand = v.WachtOpSpeler && (v.Slag.Count == 0 || v.AanZet == Pos.HandZuid);
        bool magTafel = v.WachtOpSpeler && (v.Slag.Count == 0 || v.AanZet == Pos.TafelZuid);

        TekenSpeelveld(g, v, veld, k);

        TekenRij(g, v.HandNoord, rijen, yNoordHand, k, NoordHandSpatie(k), false);
        TekenTafelRij(g, v.TafelNoord, v.OnderNoord, rijen, yNoordTafel, k, false, peekOmhoog: false);
        TekenTafelRij(g, v.TafelZuid, v.OnderZuid, rijen, yZuidTafel, k, magTafel, peekOmhoog: true);
        TekenRij(g, v.HandZuid, rijen, yZuidHand, k, HandSpatie(k), magHand);

        TekenPaneel(g, v, new RectangleF(speel.Right, top, ClientSize.Width - speel.Right, ClientSize.Height - top));
        TekenBalk(g, speel);

        if (_modus == Modus.KiesTroef)
        {
            // De troefvraag komt op de rij dichte kaarten van de tegenstander te
            // staan: daar zit toch geen informatie, en zo blijft je eigen hand
            // zichtbaar terwijl je kiest.
            // Noord legt zijn hand met een kleinere spatie neer dan Zuid, dus
            // die maat gebruiken - anders steekt de band links buiten de rij.
            int aantal = Math.Max(v.HandNoord.Count, 1);
            int handBreed = NoordHandSpatie(k) * (aantal - 1) + OrigineleKaarten.Breedte * k;
            var noordRij = new RectangleF(rijen.Right - handBreed, yNoordHand, handBreed, ch);
            TekenTroefKeuze(g, noordRij);
        }
    }

    /// <summary>
    /// Het scherm tijdens snel spelen: geen kaarten, alleen wie er speelt en
    /// hoeveel spellen er al doorheen zijn. Zo blijft alle rekentijd voor het
    /// spel zelf.
    /// </summary>
    private void TekenSnel(Graphics g, RectangleF speel, SpelView v)
    {
        var midden = new StringFormat { Alignment = StringAlignment.Center };
        float x = speel.Left + speel.Width / 2;
        float y = speel.Top + speel.Height * 0.30f;

        using var fKop = new Font("Segoe UI", 20f, FontStyle.Bold);
        using var fTxt = new Font("Segoe UI", 13f);
        using var fKlein = new Font("Segoe UI", 10f);
        using var geel = new SolidBrush(Color.FromArgb(250, 230, 160));
        using var wit = new SolidBrush(Color.FromArgb(225, 235, 228));
        using var grijs = new SolidBrush(Color.FromArgb(150, 168, 155));

        g.DrawString(Taal.SnelBezig, fKop, geel, new PointF(x, y), midden);
        y += 52;

        long spellen = v.Statistiek.Spellen[0] + v.Statistiek.Spellen[1];
        g.DrawString(Taal.SnelSpellen(spellen), fTxt, wit, new PointF(x, y), midden);
        y += 40;

        // Wie speelt er aan welke kant.
        string zuid = (_spel?.E.S.Zoekt[0] ?? false) ? Taal.MenuAiLoggen : Taal.MenuAiEd;
        string noord = (_spel?.E.S.Zoekt[1] ?? false) ? Taal.MenuAiLoggen : Taal.MenuAiEd;
        g.DrawString($"{Taal.Zuid}: {zuid}", fTxt, wit, new PointF(x, y), midden);
        y += 26;
        g.DrawString($"{Taal.Noord}: {noord}", fTxt, wit, new PointF(x, y), midden);
        y += 44;

        g.DrawString(Taal.SnelUitzetten, fKlein, grijs, new PointF(x, y), midden);
    }

    private static void TekenAchtergrond(Graphics g, RectangleF r)
    {
        // Een verloopkwast met breedte of hoogte nul is ongeldig en gooit.
        if (r.Width < 1 || r.Height < 1) return;
        using var vul = new LinearGradientBrush(r, Color.FromArgb(24, 92, 58), Color.FromArgb(12, 54, 34), 90f);
        g.FillRectangle(vul, r);
    }

    // Het speelveld waar de slag op ligt: 130 bij 230, met de vier kaarten op
    // vaste plekken per speler. Dit zijn de maten uit KJJ.C, waar het veld op
    // (0,125) lag en legkaart() de kaarten op krtposx/krtposy neerlegde.
    private const int VeldBreedte = 130;
    private const int VeldHoogte = 230;
    private const int VeldMarge = 24;   // lucht boven en onder het veld samen

    /// <summary>Plek van de kaart van speler 1..4 binnen het speelveld.</summary>
    private static Point VeldPlek(int speler, int k) => speler switch
    {
        Pos.HandZuid => new Point(10 * k, 135 * k),   // Zuid onderaan
        Pos.TafelZuid => new Point(65 * k, 95 * k),
        Pos.TafelNoord => new Point(10 * k, 50 * k),  // Noord bovenaan
        _ => new Point(65 * k, 10 * k),
    };

    // Afstand tussen twee kaarten in een rij, steeds een veelvoud van de schaal
    // zodat elke kaart op een hele pixel valt. De hand van Noord ligt over
    // elkaar heen, net als in het origineel.
    private static int HandSpatie(int k) => 57 * k;
    private static int NoordHandSpatie(int k) => 46 * k;
    private static int TafelSpatie(int k) => 70 * k;

    /// <summary>
    /// Grootste hele vergroting waarbij het speelveld links, vier rijen kaarten
    /// rechts en de breedste rij (acht kaarten in de hand) nog passen.
    /// </summary>
    private static int HeleSchaal(int breedte, int hoogte)
    {
        for (int k = 6; k > 1; k--)
        {
            int cw = OrigineleKaarten.Breedte * k;
            int ch = OrigineleKaarten.Hoogte * k;
            int handRij = HandSpatie(k) * 7 + cw;
            int tafelRij = TafelSpatie(k) * 3 + cw;
            int rijenHoog = 4 * ch + 12 * k + 20;

            // Speelveld tussen de handen in, links van de tafelrijen. De ruimte
            // tussen de twee handen is 2*ch + 3*gap + extra, met gap afgeleid
            // van de hoogte; uitgeschreven naar de benodigde hoogte geeft dat:
            int nodigBinnen = (5 * VeldHoogte * k + 5 * VeldMarge + 2 * ch - 2 * 12 * k + 2) / 3;
            bool binnen = 40 + Math.Max(handRij, VeldBreedte * k + 24 + tafelRij) <= breedte
                       && nodigBinnen <= hoogte;

            // Of anders links naast alle rijen.
            bool buiten = 40 + VeldBreedte * k + 24 + handRij <= breedte
                       && rijenHoog <= hoogte;

            if (binnen || buiten) return k;
        }
        return 1;
    }

    /// <summary>Kleur van het speelveld.</summary>
    private static readonly Color VeldKleur = Color.FromArgb(0x66, 0xCE, 0x33);

    /// <summary>
    /// Plek van het speelveld. Bij voorkeur rechts, in de vrije ruimte links
    /// van de tafelrijen en tussen de handen van Noord en Zuid in. Past het daar
    /// niet, dan valt hij terug naar links naast de rijen.
    /// </summary>
    private static Rectangle VeldVak(RectangleF speel, RectangleF rijen, int k, int bandTop, int bandBot)
    {
        int vb = VeldBreedte * k, vh = VeldHoogte * k;
        int tafelLinks = (int)rijen.Right - (TafelSpatie(k) * 3 + OrigineleKaarten.Breedte * k);
        int x = tafelLinks - 24 - vb;

        if (x >= speel.Left + 8 && bandBot - bandTop >= vh + VeldMarge)
            return new Rectangle(x, bandTop + (bandBot - bandTop - vh) / 2, vb, vh);

        return new Rectangle((int)speel.Left + 20,
                             (int)(speel.Top + (speel.Height - vh) / 2), vb, vh);
    }

    /// <summary>
    /// Het speelveld met de kaarten van de lopende slag. Noord legt bovenin,
    /// Zuid onderin, zodat je in één oogopslag ziet wie wat legde.
    /// </summary>
    private void TekenSpeelveld(Graphics g, SpelView v, Rectangle veld, int k)
    {
        int cw = OrigineleKaarten.Breedte * k;
        int ch = OrigineleKaarten.Hoogte * k;

        using (var vul = new SolidBrush(VeldKleur))
            g.FillRectangle(vul, veld);
        using (var rand = new Pen(Color.FromArgb(58, 122, 30), 2))
            g.DrawRectangle(rand, veld);

        // Labels binnen het veld: erbuiten is bij de rechterpositie geen ruimte.
        using var fLabel = new Font("Segoe UI", 9.5f, FontStyle.Bold);
        using var donker = new SolidBrush(Color.FromArgb(34, 78, 18));
        g.DrawString(Taal.Noord, fLabel, donker, veld.Left + 6, veld.Top + 4);
        g.DrawString(Taal.Zuid, fLabel, donker, veld.Left + 6, veld.Bottom - 20);

        // Lege plekken licht aangeven, zodat de indeling ook zichtbaar is
        // voordat er kaarten liggen.
        using (var leeg = new Pen(Color.FromArgb(90, 40, 90, 20), 1) { DashStyle = DashStyle.Dot })
            foreach (int speler in new[] { Pos.HandZuid, Pos.HandNoord, Pos.TafelZuid, Pos.TafelNoord })
            {
                if (v.Slag.Any(s => s.Speler == speler)) continue;
                var p = VeldPlek(speler, k);
                g.DrawRectangle(leeg, veld.Left + p.X, veld.Top + p.Y, cw, ch);
            }

        // In speelvolgorde tekenen, zodat een latere kaart over een eerdere valt.
        foreach (var s in v.Slag)
        {
            var p = VeldPlek(s.Speler, k);
            var vak = new RectangleF(veld.Left + p.X, veld.Top + p.Y, cw, ch);
            TekenSchaduw(g, vak);
            KaartTekenaar.TekenKaart(g, vak, s.Naam, s.Kleur);
        }
    }

    private void TekenRij(Graphics g, List<KaartView> kaarten, RectangleF speel,
                          int y, int k, int spatie, bool klikbaar)
    {
        if (kaarten.Count == 0) return;
        int cw = OrigineleKaarten.Breedte * k;
        int ch = OrigineleKaarten.Hoogte * k;
        // Alle rijen tegen dezelfde rechterkant, zoals het origineel ze vanaf
        // x=560 naar links neerlegde.
        int breed = spatie * (kaarten.Count - 1) + cw;
        int x = (int)speel.Right - breed;

        for (int i = 0; i < kaarten.Count; i++)
        {
            var kaart = kaarten[i];
            bool onder = klikbaar && ReferenceEquals(kaart, _onderMuis);
            int dy = onder ? -6 * k : 0;
            var vak = new RectangleF(x + i * spatie, y + dy, cw, ch);
            TekenSchaduw(g, vak);
            if (kaart.Open) KaartTekenaar.TekenKaart(g, vak, kaart.Naam, kaart.Kleur, onder);
            else KaartTekenaar.TekenAchterkant(g, vak);
            if (klikbaar) _klikbaar.Add((vak, kaart));
        }
    }

    /// <param name="peekOmhoog">
    /// Steekt de dichte kaart eronder naar boven uit (Zuid) of naar beneden
    /// (Noord)? In het origineel legde leg_tafel() hem vijf pixels verschoven
    /// neer, richting het midden van de tafel.
    /// </param>
    private void TekenTafelRij(Graphics g, List<KaartView> open, bool[] gedekt,
                               RectangleF speel, int y, int k, bool klikbaar, bool peekOmhoog)
    {
        int cw = OrigineleKaarten.Breedte * k;
        int ch = OrigineleKaarten.Hoogte * k;
        int spatie = TafelSpatie(k);
        int aantal = Math.Max(open.Count, 4);
        int breed = spatie * (aantal - 1) + cw;
        int x = (int)speel.Right - breed;

        // De achterkant hoort onder de plek die hij werkelijk dekt, niet onder
        // de eerste zoveel plekken.
        int peek = peekOmhoog ? -5 * k : 5 * k;
        for (int i = 0; i < aantal && i < gedekt.Length; i++)
        {
            if (!gedekt[i]) continue;
            var vak = new RectangleF(x + i * spatie, y + peek, cw, ch);
            KaartTekenaar.TekenAchterkant(g, vak);
        }


        for (int i = 0; i < open.Count; i++)
        {
            var kaart = open[i];
            int plek = Math.Clamp(kaart.Plek, 0, aantal - 1);
            bool onder = klikbaar && ReferenceEquals(kaart, _onderMuis);
            int dy = onder ? -5 * k : 0;
            var vak = new RectangleF(x + plek * spatie, y + dy, cw, ch);
            TekenSchaduw(g, vak);
            if (kaart.Open) KaartTekenaar.TekenKaart(g, vak, kaart.Naam, kaart.Kleur, onder);
            else KaartTekenaar.TekenAchterkant(g, vak);
            if (klikbaar) _klikbaar.Add((vak, kaart));
        }
    }

    private static void TekenSchaduw(Graphics g, RectangleF r)
    {
        using var b = new SolidBrush(Color.FromArgb(60, 0, 0, 0));
        g.FillRectangle(b, r.X + 3, r.Y + 4, r.Width, r.Height);
    }

    private void TekenPaneel(Graphics g, SpelView v, RectangleF r)
    {
        using var vul = new SolidBrush(Color.FromArgb(28, 34, 40));
        g.FillRectangle(vul, r);

        using var fKop = new Font("Segoe UI", 13f, FontStyle.Bold);
        using var fTxt = new Font("Segoe UI", 11f);
        using var fKlein = new Font("Segoe UI", 9.5f);
        using var wit = new SolidBrush(Color.FromArgb(235, 240, 245));
        using var grijs = new SolidBrush(Color.FromArgb(160, 172, 184));
        using var geel = new SolidBrush(Color.FromArgb(250, 208, 90));

        float x = r.Left + 18, y = r.Top + 16;

        string troef = (v.Troef >= 0 && v.Troef < 4)
            ? $"{Taal.KleurNaam(v.Troef)} {KaartTekenaar.SuitTeken[v.Troef]}"
            : Taal.NogNietBepaald;
        g.DrawString(Taal.Troef, fKlein, grijs, x, y); y += 18;
        g.DrawString(troef, fKop, geel, x, y); y += 34;

        g.DrawString(Taal.SlagVanAcht(Math.Max(v.SlagNr, 0)), fTxt, wit, x, y); y += 30;

        using var lijn = new Pen(Color.FromArgb(60, 70, 82));
        g.DrawLine(lijn, x, y, r.Right - 18, y); y += 14;

        // Kolommen meeschalen met de paneelbreedte; met vaste afstanden viel de
        // Zuid-kolom in een smal venster buiten beeld.
        float rechterRand = r.Right - 18;
        float kolZuid = rechterRand;
        float kolNoord = rechterRand - (r.Width - 36) * 0.34f;
        var rechts = new StringFormat { Alignment = StringAlignment.Far };

        g.DrawString(Taal.Noord, fKlein, grijs, kolNoord, y, rechts);
        g.DrawString(Taal.Zuid, fKlein, grijs, kolZuid, y, rechts); y += 22;

        Regel(g, Taal.Punten, v.PuntenNoord.ToString(), v.PuntenZuid.ToString(), fTxt, wit, x, kolNoord, kolZuid, rechts, ref y);
        Regel(g, Taal.Roem, v.RoemNoord.ToString(), v.RoemZuid.ToString(), fTxt, wit, x, kolNoord, kolZuid, rechts, ref y);
        Regel(g, Taal.Totaal, v.TotaalNoord.ToString(), v.TotaalZuid.ToString(), fTxt, wit, x, kolNoord, kolZuid, rechts, ref y);
        Regel(g, Taal.Partijen, v.PartijenNoord.ToString(), v.PartijenZuid.ToString(), fTxt, wit, x, kolNoord, kolZuid, rechts, ref y);

        y += 10;
        g.DrawLine(lijn, x, y, r.Right - 18, y); y += 14;

        // Bij snel spelen niet: dan flitsen de kaartjes voorbij, en juist het
        // tekenen daarvan is wat we willen overslaan.
        if (!_snel && v.VorigeSlag.Count > 0)
        {
            g.DrawString(Taal.VorigeSlag, fKlein, grijs, x, y); y += 20;
            float mw = 40, mh = 56;
            for (int i = 0; i < v.VorigeSlag.Count; i++)
            {
                var s = v.VorigeSlag[i];
                var vak = new RectangleF(x + i * (mw + 8), y, mw, mh);
                KaartTekenaar.TekenKaart(g, vak, s.Naam, s.Kleur);
            }
            y += mh + 16;
        }

        if (!string.IsNullOrEmpty(v.Status))
        {
            g.DrawString(v.Status, fKlein, grijs, new RectangleF(x, y, r.Width - 36, 60));
        }

        // Naamsvermelding onderaan het paneel.
        using var fVoet = new Font("Segoe UI", 8.5f);
        using var voet = new SolidBrush(Color.FromArgb(118, 130, 142));
        var rechtsUit = new StringFormat { Alignment = StringAlignment.Far };
        g.DrawString("©2026 EdSoft, ednieuw.nl", fVoet, voet,
                     new RectangleF(r.Left + 10, r.Bottom - 26, r.Width - 28, 20), rechtsUit);
    }

    private static void Regel(Graphics g, string label, string noord, string zuid,
                              Font f, Brush b, float x, float kolNoord, float kolZuid,
                              StringFormat rechts, ref float y)
    {
        g.DrawString(label, f, b, x, y);
        g.DrawString(noord, f, b, kolNoord, y, rechts);
        g.DrawString(zuid, f, b, kolZuid, y, rechts);
        y += 24;
    }

    private void TekenBalk(Graphics g, RectangleF speel)
    {
        // Bij de troefkeuze staat de vraag al groot op de rij van Noord.
        if (_modus == Modus.KiesTroef) return;
        if (string.IsNullOrEmpty(_balk) && _modus != Modus.Verder) return;

        string tekst = _balk;
        if (_modus == Modus.Verder) tekst += Taal.KlikOfToets;
        if (string.IsNullOrWhiteSpace(tekst)) return;

        // Na de achtste slag staat er behalve de slag ook de uitslag van het
        // spel; die regel moet nog binnen het speelveld passen.
        float ruimte = Math.Max(120f, speel.Width - 24f);
        Font f = null;
        SizeF maat = SizeF.Empty;
        foreach (float punt in new[] { 12f, 11f, 10f, 9f, 8f })
        {
            f?.Dispose();
            f = new Font("Segoe UI", punt, FontStyle.Bold);
            maat = g.MeasureString(tekst, f);
            if (maat.Width + 32 <= ruimte) break;
        }
        using var _ = f;
        var vak = new RectangleF(speel.Left + (speel.Width - maat.Width) / 2 - 16,
                                 speel.Top + 4, maat.Width + 32, maat.Height + 10);
        using var b = new SolidBrush(Color.FromArgb(200, 12, 20, 16));
        g.FillRectangle(b, vak);
        using var t = new SolidBrush(Color.FromArgb(250, 230, 160));
        g.DrawString(tekst, f, t, vak.Left + 16, vak.Top + 5);
    }

    /// <summary>De troefvraag, uitgeklapt over de dichte kaarten van Noord.</summary>
    private void TekenTroefKeuze(Graphics g, RectangleF rij)
    {
        if (rij.Width < 60 || rij.Height < 60) return;

        using (var band = new SolidBrush(Color.FromArgb(212, 14, 28, 20)))
            g.FillRectangle(band, rij);
        using (var rand = new Pen(Color.FromArgb(250, 208, 90), 2))
            g.DrawRectangle(rand, rij.X, rij.Y, rij.Width, rij.Height);

        var fmt = new StringFormat { Alignment = StringAlignment.Center };
        using var fKop = new Font("Segoe UI", Math.Max(10f, rij.Height * 0.105f), FontStyle.Bold);
        using var geel = new SolidBrush(Color.FromArgb(250, 230, 160));
        g.DrawString(Taal.WelkeTroef, fKop, geel,
                     new PointF(rij.Left + rij.Width / 2, rij.Top + rij.Height * 0.05f), fmt);

        float bh = rij.Height * 0.54f;
        float bw = bh * 1.2f;
        float sp = Math.Min(bw * 0.22f, rij.Width * 0.04f);
        float breed = 4 * bw + 3 * sp;
        float x = rij.Left + (rij.Width - breed) / 2;
        float y = rij.Bottom - bh - rij.Height * 0.07f;

        using var fTeken = new Font("Segoe UI Symbol", bh * 0.46f, GraphicsUnit.Pixel);
        using var fNaam = new Font("Segoe UI", Math.Max(8f, bh * 0.14f), GraphicsUnit.Pixel);

        for (int k = 0; k < 4; k++)
        {
            var vak = new RectangleF(x + k * (bw + sp), y, bw, bh);
            using var vul = new SolidBrush(Color.FromArgb(245, 248, 250));
            g.FillRectangle(vul, vak);
            using var lijn = new Pen(Color.FromArgb(120, 130, 140), 2);
            g.DrawRectangle(lijn, vak.X, vak.Y, vak.Width, vak.Height);

            using var kwast = new SolidBrush(KaartTekenaar.KleurVan(k));
            g.DrawString(KaartTekenaar.SuitTeken[k], fTeken, kwast,
                         new PointF(vak.Left + bw / 2, vak.Top + bh * 0.06f), fmt);
            g.DrawString(Taal.KleurNaam(k), fNaam, kwast,
                         new PointF(vak.Left + bw / 2, vak.Bottom - bh * 0.22f), fmt);

            _troefKnoppen.Add((vak, k));
        }
    }
}