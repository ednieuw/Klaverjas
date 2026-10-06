using Klaverjas.Engine;

namespace Klaverjas.Ble;

/// <summary>
/// Zet een binnengekomen <see cref="SpelStandGast"/> (Zuid/Noord vanuit het
/// perspectief van de gastheer) om in een <see cref="SpelView"/> waarin de
/// gast zijn eigen kant als Zuid ziet — dezelfde aanname waar de bestaande
/// tekencode in SpelForm al van uitgaat (Zuid = onderin, van jou).
///
/// <c>mijnKant</c> is voor de gast altijd 2 (Noord), maar wordt hier uit de
/// data gelezen in plaats van aangenomen, zoals BLUETOOTH-VOOR-WINDOWS.md
/// voorschrijft ("Wat Windows zelf moet uitrekenen").
/// </summary>
public static class GastWeergave
{
    /// <summary>true als de gast zelf iets moet kiezen (troef of kaart).</summary>
    public static bool BenIkAanZet(SpelStandGast stand)
    {
        bool ikBenZuid = stand.MijnKant != 2;
        int mijnHandPos = ikBenZuid ? Pos.HandZuid : Pos.HandNoord;
        int mijnTafelPos = ikBenZuid ? Pos.TafelZuid : Pos.TafelNoord;
        return stand.AanZet == mijnHandPos || stand.AanZet == mijnTafelPos;
    }

    /// <summary>Wissel Zuid/Noord om als de gast Noord is; anders ongewijzigd.</summary>
    private static int Relatief(int positie, bool wissel)
    {
        if (!wissel) return positie;
        return positie switch
        {
            Pos.HandZuid => Pos.HandNoord,
            Pos.HandNoord => Pos.HandZuid,
            Pos.TafelZuid => Pos.TafelNoord,
            Pos.TafelNoord => Pos.TafelZuid,
            _ => positie,
        };
    }

    private static List<KaartView> Kaarten(List<KaartViewGast> bron) =>
        bron.Select(k => new KaartView
        {
            Index = k.Index,
            Naam = k.Naam,
            Kleur = k.Kleur,
            Open = k.Open,
            Klikbaar = k.Klikbaar,
            Plek = k.Plek,
        }).ToList();

    private static List<SlagView> Slagen(List<SlagViewGast> bron, bool wissel) =>
        bron.Select(s => new SlagView(s.Kleur, s.Naam, Relatief(s.Speler, wissel), s.Tactiek)).ToList();

    /// <summary>Bouwt de SpelView waarop de bestaande tekencode van SpelForm al werkt.</summary>
    public static SpelView NaarSpelView(SpelStandGast stand)
    {
        bool wissel = stand.MijnKant == 2; // gast is altijd Noord: draai om voor het eigen scherm

        var v = new SpelView
        {
            HandZuid = Kaarten(wissel ? stand.HandNoord : stand.HandZuid),
            HandNoord = Kaarten(wissel ? stand.HandZuid : stand.HandNoord),
            TafelZuid = Kaarten(wissel ? stand.TafelNoord : stand.TafelZuid),
            TafelNoord = Kaarten(wissel ? stand.TafelZuid : stand.TafelNoord),
            DichtZuid = Kaarten(wissel ? stand.DichtNoord : stand.DichtZuid),
            DichtNoord = Kaarten(wissel ? stand.DichtZuid : stand.DichtNoord),
            Slag = Slagen(stand.Slag, wissel),
            VorigeSlag = Slagen(stand.VorigeSlag, wissel),
            Troef = stand.Troef,
            SlagNr = stand.SlagNr,
            AanZet = Relatief(stand.AanZet, wissel),
            WachtOpSpeler = stand.WachtOpSpeler,
            TroefVraag = stand.TroefVraag,
            PuntenZuid = wissel ? stand.PuntenNoord : stand.PuntenZuid,
            PuntenNoord = wissel ? stand.PuntenZuid : stand.PuntenNoord,
            RoemZuid = wissel ? stand.RoemNoord : stand.RoemZuid,
            RoemNoord = wissel ? stand.RoemZuid : stand.RoemNoord,
            TotaalZuid = wissel ? stand.TotaalNoord : stand.TotaalZuid,
            TotaalNoord = wissel ? stand.TotaalZuid : stand.TotaalNoord,
            PartijenZuid = wissel ? stand.PartijenNoord : stand.PartijenZuid,
            PartijenNoord = wissel ? stand.PartijenZuid : stand.PartijenNoord,
            Status = stand.Status,
            Melding = stand.Melding,
            SpelUit = stand.SpelUit,
        };

        bool[] onderZuidBron = wissel ? stand.OnderNoord : stand.OnderZuid;
        bool[] onderNoordBron = wissel ? stand.OnderZuid : stand.OnderNoord;
        for (int i = 0; i < 4; i++)
        {
            v.OnderZuid[i] = i < onderZuidBron.Length && onderZuidBron[i];
            v.OnderNoord[i] = i < onderNoordBron.Length && onderNoordBron[i];
        }

        return v;
    }
}
