namespace Klaverjas.Engine;

/// <summary>
/// Hulpjes die de C-stringsemantiek van het origineel nabootsen: een char-array
/// met een afsluitende '\0'. Het origineel (KJ.C / KJJ.C) leunt zwaar op
/// strlen/strcpy/strcat/strchr over char-arrays, en op het feit dat een array
/// langer is dan de string die erin staat. Door dat hier expliciet na te doen
/// blijft de vertaling regel-voor-regel te volgen.
/// </summary>
internal static class CStr
{
    public const char Nul = '\0';

    /// <summary>Nieuwe lege C-string van gegeven omvang.</summary>
    public static char[] New(int size)
    {
        var s = new char[size];
        s[0] = Nul;
        return s;
    }

    public static char[][] New2(int dim1, int size)
    {
        var a = new char[dim1][];
        for (int i = 0; i < dim1; i++) a[i] = New(size);
        return a;
    }

    public static char[][][] New3(int dim1, int dim2, int size)
    {
        var a = new char[dim1][][];
        for (int i = 0; i < dim1; i++) a[i] = New2(dim2, size);
        return a;
    }

    /// <summary>strlen()</summary>
    public static int Len(char[] s)
    {
        for (int i = 0; i < s.Length; i++)
            if (s[i] == Nul) return i;
        return s.Length;
    }

    /// <summary>Inhoud tot aan de NUL als .NET string.</summary>
    public static string Str(char[] s) => new string(s, 0, Len(s));

    /// <summary>strcpy(dst, src)</summary>
    public static void Cpy(char[] dst, string src)
    {
        int n = Math.Min(src.Length, dst.Length - 1);
        for (int i = 0; i < n; i++) dst[i] = src[i];
        dst[n] = Nul;
    }

    public static void Cpy(char[] dst, char[] src) => Cpy(dst, Str(src));

    /// <summary>strcat(dst, src)</summary>
    public static void Cat(char[] dst, string src)
    {
        int l = Len(dst);
        int n = Math.Min(src.Length, dst.Length - 1 - l);
        for (int i = 0; i < n; i++) dst[l + i] = src[i];
        dst[l + n] = Nul;
    }

    public static void Cat(char[] dst, char[] src) => Cat(dst, Str(src));

    /// <summary>Zet 1 teken achteraan (dst[strlen(dst)] = c).</summary>
    public static void Append(char[] dst, char c)
    {
        int l = Len(dst);
        if (l + 1 >= dst.Length) return;
        dst[l] = c;
        dst[l + 1] = Nul;
    }

    public static void Clear(char[] s) => s[0] = Nul;

    /// <summary>
    /// strpos() uit het origineel: 1-gebaseerde positie van x in s, of 0 als x
    /// niet voorkomt. Let op: de returnwaarde wordt in het origineel ook als
    /// boolean gebruikt ("staat die kaart erin?").
    /// </summary>
    public static int Pos(string s, char x)
    {
        int i = s.IndexOf(x);
        return i < 0 ? 0 : i + 1;
    }

    public static int Pos(char[] s, char x)
    {
        int len = Len(s);
        for (int i = 0; i < len; i++)
            if (s[i] == x) return i + 1;
        return 0;
    }
}
