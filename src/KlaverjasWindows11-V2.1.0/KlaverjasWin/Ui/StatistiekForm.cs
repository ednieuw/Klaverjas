using System.Drawing;
using System.Windows.Forms;

namespace Klaverjas.Ui;

using Klaverjas.Engine;

/// <summary>
/// De tellingen die het origineel bij het afsluiten afdrukte, nu op te vragen
/// tijdens het spel. Dezelfde regels en dezelfde volgorde als het printf-blok
/// aan het eind van main() in KJ.C, met Zuid en Noord als kolommen - op één
/// punt na: de stand van de partij staat bovenaan, want dat is het getal waar
/// je tijdens het spelen naar kijkt.
///
/// Daaronder hoe vaak elke tactiek is toegepast. Het origineel drukte dat
/// alleen af als de computer beide kanten speelde; hier staat het er altijd
/// bij zodra er iets te tellen valt.
///
/// Het venster staat naast het spel in plaats van ervoor, en werkt zichzelf
/// twee keer per seconde bij. Bij snel spelen is dat het aardigste om naar te
/// kijken, en het is ook de enige plek waar dan iets te zien valt.
/// </summary>
internal sealed class StatistiekForm : Form
{
    private static readonly Color Achtergrond = Color.FromArgb(12, 54, 34);
    private static readonly Color Inkt = Color.FromArgb(250, 230, 160);

    private readonly Func<Statistiek> _lees;
    private readonly Action _wissen;
    private readonly ListView _tellingen;
    private readonly ListView _tactiek;
    private readonly System.Windows.Forms.Timer _klok;

    /// <summary>Zodat de rijen niet elke halve seconde opnieuw gebouwd worden.</summary>
    private bool _leegGetoond;

    /// <param name="lees">Haalt de nieuwste tellingen op; wordt herhaald aangeroepen.</param>
    /// <param name="wissen">Zet alles op nul. Null = geen knop.</param>
    public StatistiekForm(Func<Statistiek> lees, Action wissen = null)
    {
        _lees = lees;
        _wissen = wissen;

        Text = Taal.StatTitel;
        BackColor = Achtergrond;
        ForeColor = Inkt;
        ClientSize = new Size(600, 700);
        // Niet CenterParent: dat werkt alleen voor een venster dat ervoor
        // staat, en dit staat ernaast. SpelForm zet hem zelf neer.
        StartPosition = FormStartPosition.Manual;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = false;
        MaximizeBox = false;

        _tellingen = MaakLijst(new[] { ("", 250), (Taal.Zuid, 150), (Taal.Noord, 150) });
        _tellingen.SetBounds(12, 12, 570, 300);

        var kop = new Label
        {
            Text = Taal.StatTactiek,
            Font = new Font(Font, FontStyle.Bold),
            ForeColor = Inkt,
            AutoSize = true,
        };
        kop.SetBounds(12, 322, 300, 20);

        var uitleg = new Label
        {
            Text = Taal.StatTactiekUitleg,
            ForeColor = Color.FromArgb(190, 200, 160),
            AutoSize = false,
        };
        uitleg.SetBounds(12, 344, 570, 20);

        _tactiek = MaakLijst(new[] { ("#", 44), ("", 400), ("", 100) });
        _tactiek.HeaderStyle = ColumnHeaderStyle.None;
        _tactiek.SetBounds(12, 368, 570, 270);

        var sluit = new Button { Text = Taal.StatSluiten };
        sluit.SetBounds(482, 650, 100, 30);
        // Dit venster is niet-modaal (Show(), geen ShowDialog()): een
        // DialogResult op de knop zou dan niets doen, dus expliciet sluiten.
        sluit.Click += (_, _) => Close();

        Controls.AddRange(new Control[] { _tellingen, kop, uitleg, _tactiek, sluit });
        CancelButton = sluit;
        AcceptButton = sluit;

        if (_wissen != null)
        {
            var wis = new Button { Text = Taal.StatWissen };
            wis.SetBounds(12, 650, 100, 30);
            wis.Click += (_, _) =>
            {
                var antwoord = MessageBox.Show(this, Taal.StatWisVraag, Taal.Titel,
                                               MessageBoxButtons.YesNo, MessageBoxIcon.Question);
                if (antwoord != DialogResult.Yes) return;
                _wissen();
                Werkbij();
            };
            Controls.Add(wis);
        }

        Werkbij();

        // Twee keer per seconde, hetzelfde tempo als waarmee het speelscherm bij
        // snel spelen tekent. Vaker heeft geen zin en gaat van de speeltijd af.
        _klok = new System.Windows.Forms.Timer { Interval = 500 };
        _klok.Tick += (_, _) => Werkbij();
        _klok.Start();
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _klok.Stop();
        _klok.Dispose();
        base.OnFormClosed(e);
    }

    // ---------------------------------------------------------- bijwerken

    private void Werkbij()
    {
        var st = _lees();
        if (st == null) return;

        if (st.Leeg)
        {
            if (_leegGetoond) return;
            _leegGetoond = true;
            _tellingen.Items.Clear();
            _tellingen.Items.Add(new ListViewItem(Taal.StatNogNiets));
            _tactiek.Items.Clear();
            return;
        }

        if (_leegGetoond)
        {
            _leegGetoond = false;
            _tellingen.Items.Clear();
        }

        VulTellingen(st);
        VulTactieken(st);
    }

    /// <summary>
    /// De vaste regels. De eerste keer worden ze aangemaakt, daarna alleen de
    /// getallen overschreven: rijen weggooien en opnieuw aanmaken laat de lijst
    /// twee keer per seconde knipperen.
    /// </summary>
    private void VulTellingen(Statistiek st)
    {
        (string Kop, long Zuid, long Noord)[] regels =
        {
            // De stand van de partij bovenaan: daar kijk je tijdens het spelen naar.
            (Taal.StatStand, st.Totaal[0], st.Totaal[1]),
            (Taal.StatPartijen, st.Partijen[0], st.Partijen[1]),
            (Taal.StatSpellen, st.Spellen[0], st.Spellen[1]),
            (Taal.StatKaartpunten, st.Kaartpunten[0], st.Kaartpunten[1]),
            (Taal.StatTroefpunten, st.Troefpunten[0], st.Troefpunten[1]),
            (Taal.StatTroefkaarten, st.Troefkaarten[0], st.Troefkaarten[1]),
            (Taal.StatRoempunten, st.Roempunten[0], st.Roempunten[1]),
            (Taal.StatPit, st.Pit[0], st.Pit[1]),
            (Taal.StatTegenpit, st.Tegenpit[0], st.Tegenpit[1]),
            (Taal.StatNat, st.Nat[0], st.Nat[1]),
            // De superroem gaat naar wie de slag pakt, dus in dezelfde kolommen.
            (Taal.StatSuperroem, st.Superroem[0], st.Superroem[1]),
        };

        if (_tellingen.Items.Count != regels.Length)
        {
            _tellingen.BeginUpdate();
            _tellingen.Items.Clear();
            foreach (var (kop, _, _) in regels)
            {
                var r = new ListViewItem(kop);
                r.SubItems.Add("");
                r.SubItems.Add("");
                _tellingen.Items.Add(r);
            }
            _tellingen.EndUpdate();
        }

        _tellingen.BeginUpdate();
        for (int i = 0; i < regels.Length; i++)
        {
            var r = _tellingen.Items[i];
            r.Text = regels[i].Kop;
            r.SubItems[1].Text = regels[i].Zuid.ToString("N0");
            r.SubItems[2].Text = regels[i].Noord.ToString("N0");
        }
        _tellingen.EndUpdate();
    }

    /// <summary>
    /// De tactieken, de meest gebruikte eerst. De volgorde verschuift terwijl
    /// er gespeeld wordt, dus de tekst van de rijen wordt overschreven; alleen
    /// als er een tactiek bij komt of afvalt gaat de lijst op de schop.
    /// </summary>
    private void VulTactieken(Statistiek st)
    {
        var gebruikt = st.GebruikteTactieken();

        if (_tactiek.Items.Count != gebruikt.Count)
        {
            _tactiek.BeginUpdate();
            _tactiek.Items.Clear();
            foreach (var _ in gebruikt)
            {
                var r = new ListViewItem("");
                r.SubItems.Add("");
                r.SubItems.Add("");
                _tactiek.Items.Add(r);
            }
            _tactiek.EndUpdate();
        }

        _tactiek.BeginUpdate();
        for (int i = 0; i < gebruikt.Count; i++)
        {
            var (nummer, aantal) = gebruikt[i];
            var r = _tactiek.Items[i];
            r.Text = nummer.ToString();
            // 70 is niet van 1994 maar van de zoekende speler; Tactieknamen komt
            // uit de Swift-bron en blijft daarom ongemoeid.
            r.SubItems[1].Text = nummer == 70 ? Taal.StatTactiekZoeken : Tactieknamen.Naam(nummer);
            r.SubItems[2].Text = aantal.ToString("N0");
        }
        _tactiek.EndUpdate();
    }

    /// <summary>
    /// Een gewone ListView is niet dubbel gebufferd: elke keer dat Werkbij() de
    /// tekst overschrijft (twee keer per seconde, ook als er niets veranderd
    /// is) knippert het scherm zichtbaar. Dit is de standaard-oplossing
    /// daarvoor - DoubleBuffered is alleen vanuit een afgeleide klasse te
    /// zetten, niet van buitenaf.
    /// </summary>
    private sealed class DubbelGebufferdeListView : ListView
    {
        public DubbelGebufferdeListView() => DoubleBuffered = true;
    }

    private ListView MaakLijst((string Kop, int Breedte)[] kolommen)
    {
        var lijst = new DubbelGebufferdeListView
        {
            View = View.Details,
            FullRowSelect = true,
            GridLines = false,
            MultiSelect = false,
            BackColor = Achtergrond,
            ForeColor = Inkt,
            BorderStyle = BorderStyle.None,
            HeaderStyle = ColumnHeaderStyle.Nonclickable,
        };
        foreach (var (kop, breedte) in kolommen)
            lijst.Columns.Add(kop, breedte,
                              kop == "" ? HorizontalAlignment.Left : HorizontalAlignment.Right);
        return lijst;
    }
}
