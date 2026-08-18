namespace Klaverjas.Engine;

public partial class KjEngine
{
    /// <summary>
    /// Controleert of de gekozen kaart (S.Lkaart / S.Lkleur) volgens de regels
    /// gespeeld mag worden. Geeft null als het mag, anders de reden.
    /// Dit is check_valid() uit KJJ.C.
    /// </summary>
    public string CheckValid()
    {
        int m, n, i, j;
        char hoogste = (char)0;
        char[] trKrt = CStr.New(16);
        int iKrt, tKrt;
        bool troefaanwezig = false;

        int kaartkleurnul = S.Slag(S.SlagNr, 0).Kleur;
        if (S.SlagKrtNo <= 0) return null;
        if (kaartkleurnul < 0 || kaartkleurnul > 3) return null;
        if (S.Lkleur < 0 || S.Lkleur > 3) return Taal.VerkeerdeKaart;

        if (S.Vrager < 3)
        {
            CStr.Cpy(trKrt, S.KHand[0][S.Troef]);
            tKrt = S.IKrt[S.Troef, 0];
            iKrt = S.IKrt[kaartkleurnul, 0];
        }
        else
        {
            CStr.Cpy(trKrt, S.KTafel[0][S.Troef]);
            tKrt = S.IKrtTafel[S.Troef, 0];
            iKrt = S.IKrtTafel[kaartkleurnul, 0];
        }

        for (n = 0; n < S.SlagKrtNo; n++)
            if (S.Slag(S.SlagNr, n).Kleur == S.Troef) troefaanwezig = true;

        if (troefaanwezig)
        {
            i = 99;
            for (n = 0; n < S.SlagKrtNo; n++)
            {
                if (S.Slag(S.SlagNr, n).Kleur != S.Troef) continue;
                j = CStr.Pos(KjState.RangTroef, S.Slag(S.SlagNr, n).Naam);
                if (i > j) { i = j; hoogste = S.Slag(S.SlagNr, n).Naam; }
            }

            // Het origineel test hier ook op "iKrt==0", maar vergelijkt daarbij
            // de array iKrt[][] met NUL in plaats van de lokale teller IKrt.
            // Die twee deelvoorwaarden zijn dus altijd onwaar; alleen de eerste
            // telt, en dat is hier zo gelaten.
            if (kaartkleurnul == S.Troef && tKrt != 0)
            {
                i = CStr.Pos(KjState.RangTroef, hoogste);
                if (CStr.Pos(KjState.RangTroef, S.Lkaart) < i && S.Lkleur == S.Troef) return null;

                if (S.Lkleur != S.Troef) return Taal.MoetTroefBekennen;

                for (m = 0; m < S.SlagKrtNo; m++)
                    if (CStr.Pos(KjState.RangTroef, S.Lkaart) > i)
                    {
                        int len = CStr.Len(trKrt);
                        for (n = 0; n < len; n++)
                            if (CStr.Pos(KjState.RangTroef, trKrt[n]) < i)
                                return Taal.MoetOvertroeven;
                    }
            }
        }

        if (iKrt > 0 && S.Lkleur != kaartkleurnul) return Taal.MoetKleurBekennen;

        if (iKrt == 0 && tKrt > 0)
        {
            i = WieSlag();
            if (i > 2) i -= 2;
            j = S.Vrager;
            if (j > 2) j -= 2;
            if (i == j) return null;       // slag staat al op eigen naam

            i = CStr.Pos(KjState.RangTroef, hoogste);
            if (CStr.Pos(KjState.RangTroef, S.Lkaart) < i && S.Lkleur == S.Troef) return null;

            int lenTr = CStr.Len(trKrt);
            for (n = 0; n < lenTr; n++)
                if (CStr.Pos(KjState.RangTroef, trKrt[n]) < i)
                    return Taal.MoetOvertroeven;

            if (S.Lkleur != S.Troef && !troefaanwezig) return Taal.MoetTroeven;
        }

        return null;
    }
}
