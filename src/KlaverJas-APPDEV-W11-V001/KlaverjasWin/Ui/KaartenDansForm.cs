using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

namespace Klaverjas.Ui;

/// <summary>
/// De kaartendans uit KRTDANS.C (en kaarten() in KJKRT.C): er vliegt telkens
/// één kaart over het scherm, botst tegen de randen en laat een spoor achter
/// omdat er niets gewist wordt. De bewegingsvergelijkingen zijn letterlijk
/// overgenomen, inclusief de gehele deling die de horizontale snelheid stap
/// voor stap laat afnemen.
/// </summary>
public sealed class KaartenDansForm : Form
{
    private const string RangRoem = "AHVBT987";

    private readonly System.Windows.Forms.Timer _klok = new() { Interval = 10 };
    private readonly Random _rnd = new();

    private Bitmap _doek;      // hierop blijft het spoor staan
    private int _schaal = 2;
    private int _virtW, _virtH;

    private int _posx, _posy, _x, _y, _rang, _kleur, _stappen;

    public KaartenDansForm()
    {
        Text = Klaverjas.Engine.Taal.DansTitel;
        StartPosition = FormStartPosition.CenterParent;
        KeyPreview = true;
        DoubleBuffered = true;
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint
                 | ControlStyles.UserPaint, true);

        var werkvlak = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1024, 768);
        ClientSize = new Size(Math.Min(1300, werkvlak.Width - 80),
                              Math.Min(960, werkvlak.Height - 100));

        _klok.Tick += (_, _) => Stap();
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        NieuwDoek();
        NieuweKaart();
        _klok.Start();
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        if (IsHandleCreated && ClientSize.Width > 40 && ClientSize.Height > 40) NieuwDoek();
    }

    private void NieuwDoek()
    {
        // Het origineel draaide op ongeveer 640 bij 480; met een hele
        // vergroting komt het speelvlak daar vanzelf dicht bij uit.
        _schaal = Math.Clamp(Math.Min(ClientSize.Width / 640, ClientSize.Height / 440), 1, 4);
        _virtW = ClientSize.Width / _schaal;
        _virtH = ClientSize.Height / _schaal;

        _doek?.Dispose();
        _doek = new Bitmap(Math.Max(1, ClientSize.Width), Math.Max(1, ClientSize.Height),
                           PixelFormat.Format32bppPArgb);
        using var g = Graphics.FromImage(_doek);
        g.Clear(Color.FromArgb(0, 170, 0));   // GREEN uit het EGA-palet
        Invalidate();
    }

    private void NieuweKaart()
    {
        _rang = _rnd.Next(8);
        _kleur = _rnd.Next(4);
        _posx = 10 + _rang * 70;
        _posy = 10 + _kleur * 85;
        _x = _rnd.Next(25) + 30 - 2 * _rang;
        _y = _rnd.Next(7) + 1;
        _stappen = 0;

        if (_posx > _virtW - 60) _posx = Math.Max(1, _virtW - 60);
        if (_posy > _virtH - 90) _posy = Math.Max(1, _virtH - 90);
    }

    /// <summary>Twee bewegingsstappen per tik; het origineel deed delay(5).</summary>
    private void Stap()
    {
        if (_doek == null) return;

        for (int herhaling = 0; herhaling < 2; herhaling++)
        {
            _posx += _x-- / 2;      // let op: waarde vóór de aftrek, net als in C
            _posy += _y;

            if (_posx > _virtW - 55)
            {
                if (_x < 2) _x = 6;
                _x = (-_x * 2) / 3;
                _posx += _x / 2;
            }
            if (_posx < 1)
            {
                if (_posy > 200 && _posy < 250) { NieuweKaart(); continue; }
                if (_x > -2) _x = -3;
                _x = (-_x * 3) / 4;
                _posx += _x / 2;
            }
            if (_posy > _virtH - 85)
            {
                if (_y < 3) _y = 4;
                _x = (_x * 2) / 3; _y = (-_y * 2) / 3; _x = -_x;
                _posy += _y;
            }
            if (_posy < 1)
            {
                if (_y > -3) _y = -4;
                _x = (_x * 2) / 3; _y = (-_y * 2) / 3; _x = -_x;
                _posy += _y;
            }

            TekenKaart();

            // Zonder toetsaanslag om op te stoppen kan een kaart lang blijven
            // stuiteren; na een tijdje pakken we er zelf een nieuwe bij.
            if (++_stappen > 2600) NieuweKaart();
        }

        Invalidate();
    }

    private void TekenKaart()
    {
        var bm = OrigineleKaarten.Voor(RangRoem[_rang], _kleur, _schaal);
        if (bm == null) return;

        using var g = Graphics.FromImage(_doek);
        g.InterpolationMode = InterpolationMode.NearestNeighbor;
        g.PixelOffsetMode = PixelOffsetMode.Half;
        g.DrawImage(bm, _posx * _schaal, _posy * _schaal, bm.Width, bm.Height);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        if (_doek != null) e.Graphics.DrawImageUnscaled(_doek, 0, 0);
    }

    protected override void OnMouseDown(MouseEventArgs e) => Close();
    protected override void OnKeyDown(KeyEventArgs e) => Close();

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _klok.Stop();
        _klok.Dispose();
        _doek?.Dispose();
        _doek = null;
        base.OnFormClosed(e);
    }
}
