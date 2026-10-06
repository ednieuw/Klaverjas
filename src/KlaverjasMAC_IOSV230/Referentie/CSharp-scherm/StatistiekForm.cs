using System.Drawing;
using System.Windows.Forms;

namespace Klaverjas.Ui;

using Klaverjas.Engine;

/// <summary>
/// De tellingen die het origineel bij het afsluiten afdrukte, nu op te vragen
/// tijdens het spel. Dezelfde regels en dezelfde volgorde als het printf-blok
/// aan het eind van main() in KJ.C, met Zuid en Noord als kolommen.
///
/// Daaronder hoe vaak elke tactiek is toegepast. Het origineel drukte dat
/// alleen af als de computer beide kanten speelde; hier staat het er altijd
/// bij zodra er iets te tellen valt.
/// </summary>
internal sealed class StatistiekForm : Form
{
    private static readonly Color Achtergrond = Color.FromArgb(12, 54, 34);
    private static readonly Color Inkt = Color.FromArgb(250, 230, 160);

    public StatistiekForm(Statistiek st)
    {
        Text = Taal.StatTitel;
        BackColor = Achtergrond;
        ForeColor = Inkt;
        ClientSize = new Size(600, 700);
        StartPosition = FormStartPosition.CenterParent;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = false;
        MaximizeBox = false;

        var tellingen = MaakLijst(new[] { ("", 250), (Taal.Zuid, 150), (Taal.Noord, 150) });
        tellingen.SetBounds(12, 12, 570, 300);
        VulTellingen(tellingen, st);

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

        var tactiek = MaakLijst(new[] { ("#", 44), ("", 400), ("", 100) });
        tactiek.HeaderStyle = ColumnHeaderStyle.None;
        tactiek.SetBounds(12, 368, 570, 270);
        foreach (var (nummer, aantal) in st.GebruikteTactieken())
        {
            var r = new ListViewItem(nummer.ToString());
            // 70 is niet van 1994 maar van de zoekende speler; Tactieknamen komt
            // uit de Swift-bron en blijft daarom ongemoeid.
            r.SubItems.Add(nummer == 70 ? Taal.StatTactiekZoeken : Tactieknamen.Naam(nummer));
            r.SubItems.Add(aantal.ToString("N0"));
            tactiek.Items.Add(r);
        }

        var sluit = new Button
        {
            Text = Taal.StatSluiten,
            DialogResult = DialogResult.Cancel,
        };
        sluit.SetBounds(482, 650, 100, 30);

        Controls.AddRange(new Control[] { tellingen, kop, uitleg, tactiek, sluit });
        CancelButton = sluit;
        AcceptButton = sluit;

        if (st.Leeg)
        {
            tellingen.Items.Clear();
            tellingen.Items.Add(new ListViewItem(Taal.StatNogNiets));
        }
    }

    private ListView MaakLijst((string Kop, int Breedte)[] kolommen)
    {
        var lijst = new ListView
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

    private static void VulTellingen(ListView lijst, Statistiek st)
    {
        void Regel(string kop, long zuid, long noord)
        {
            var r = new ListViewItem(kop);
            r.SubItems.Add(zuid.ToString("N0"));
            r.SubItems.Add(noord.ToString("N0"));
            lijst.Items.Add(r);
        }

        Regel(Taal.StatPartijen, st.Partijen[0], st.Partijen[1]);
        Regel(Taal.StatSpellen, st.Spellen[0], st.Spellen[1]);
        Regel(Taal.StatStand, st.Totaal[0], st.Totaal[1]);
        Regel(Taal.StatKaartpunten, st.Kaartpunten[0], st.Kaartpunten[1]);
        Regel(Taal.StatTroefpunten, st.Troefpunten[0], st.Troefpunten[1]);
        Regel(Taal.StatTroefkaarten, st.Troefkaarten[0], st.Troefkaarten[1]);
        Regel(Taal.StatRoempunten, st.Roempunten[0], st.Roempunten[1]);
        Regel(Taal.StatPit, st.Pit[0], st.Pit[1]);
        Regel(Taal.StatTegenpit, st.Tegenpit[0], st.Tegenpit[1]);
        Regel(Taal.StatNat, st.Nat[0], st.Nat[1]);

        var s = new ListViewItem(Taal.StatSuperroem);
        s.SubItems.Add(st.Superroem.ToString("N0"));
        s.SubItems.Add("");
        lijst.Items.Add(s);
    }
}
