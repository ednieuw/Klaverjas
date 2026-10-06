using Klaverjas.Ui;

namespace Klaverjas;

internal static class Program
{
    /// <summary>Waar een onverwachte fout wordt vastgelegd.</summary>
    /// <summary>Meteen snel spelen zonder kaarten, gezet met /snel.</summary>
    internal static bool StartSnel;

    /// <summary>
    /// Stond de taal op de opdrachtregel? Dan gaat die voor op de bewaarde
    /// keuze: hij hoort bij de snelkoppeling waarmee gestart is.
    /// </summary>
    internal static bool TaalUitArgument;

    internal static readonly string FoutLog =
        Path.Combine(Path.GetDirectoryName(Environment.ProcessPath) ?? ".", "klaverjas-fout.txt");

    [STAThread]
    private static void Main(string[] args)
    {
        // Zonder dit sluit Windows Forms het programma af zodra er ergens in de
        // schermafhandeling een fout optreedt: het venster verdwijnt dan zonder
        // melding. Met CatchException blijft het programma staan en krijg je te
        // zien wat er misging.
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += (_, e) => Meld(e.Exception);
        AppDomain.CurrentDomain.UnhandledException += (_, e) => Log(e.ExceptionObject as Exception);

        // Met "Klaverjas.exe /en" start het programma in het Engels; handig voor
        // een aparte snelkoppeling, zonder dat er een tweede versie nodig is.
        if (args.Any(a => a.Equals("/en", StringComparison.OrdinalIgnoreCase)
                       || a.Equals("-en", StringComparison.OrdinalIgnoreCase)))
        {
            Engine.Taal.Engels = true;
            TaalUitArgument = true;
        }
        else if (args.Any(a => a.Equals("/nl", StringComparison.OrdinalIgnoreCase)
                            || a.Equals("-nl", StringComparison.OrdinalIgnoreCase)))
        {
            Engine.Taal.Engels = false;
            TaalUitArgument = true;
        }

        // "/snel" begint meteen met snel spelen zonder kaarten, de twee
        // speelwijzen tegen elkaar.
        StartSnel = args.Any(a => a.Equals("/snel", StringComparison.OrdinalIgnoreCase)
                               || a.Equals("/fast", StringComparison.OrdinalIgnoreCase));

        ApplicationConfiguration.Initialize();

        // "Klaverjas.exe kaartenblad <bestand.png> [schaal]" zet alle 32 kaarten
        // op één afbeelding. Handig om het tekenwerk te controleren zonder te spelen.
        if (args.Length >= 2 && args[0] == "kaartenblad")
        {
            int schaal = args.Length > 2 && int.TryParse(args[2], out var s) ? s : 3;
            KaartenBlad.Schrijf(args[1], schaal);
            return;
        }

        Application.Run(new SpelForm());
    }

    internal static void Log(Exception ex)
    {
        if (ex == null) return;
        try { File.AppendAllText(FoutLog, $"{DateTime.Now:s}\n{ex}\n\n"); } catch { }
    }


    private static void Meld(Exception ex)
    {
        Log(ex);
        try
        {
            MessageBox.Show(
                $"{Engine.Taal.IetsMisMaarLooptDoor}\n\n{ex.GetType().Name}: {ex.Message}\n\n" +
                $"{Engine.Taal.VolledigeMeldingIn}\n{FoutLog}",
                Engine.Taal.Titel, MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        catch { }
    }
}
