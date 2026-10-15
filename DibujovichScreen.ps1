param([switch]$SelfTest)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$source = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("DibujovichScreen")]
[assembly: System.Reflection.AssemblyProduct("DibujovichScreen")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]

public sealed class InkStroke
{
    public readonly List<Point> Points = new List<Point>();
    public readonly Color Color;
    public readonly int Width;
    public InkStroke(Color color, int width) { Color = color; Width = width; }
}

public sealed class InkWindow : Form
{
    private readonly List<InkStroke> strokes = new List<InkStroke>();
    private InkStroke current;
    private Color color = Color.Red;
    private int penWidth = 5;

    public InkWindow()
    {
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        ShowInTaskbar = false;
        TopMost = true;
        BackColor = Color.Magenta;
        TransparencyKey = Color.Magenta;
        DoubleBuffered = true;
        Text = "DibujovichScreen Ink";
    }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams p = base.CreateParams;
            p.ExStyle |= 0x20 | 0x80 | 0x08000000;
            return p;
        }
    }

    public int StrokeCount { get { return strokes.Count; } }
    public int LastPointCount { get { return strokes.Count == 0 ? 0 : strokes[strokes.Count - 1].Points.Count; } }
    public void Begin(Point point)
    {
        current = new InkStroke(color, penWidth);
        current.Points.Add(point);
        strokes.Add(current);
        Invalidate();
    }
    public void Continue(Point point)
    {
        if (current == null) return;
        current.Points.Add(point);
        Invalidate();
    }
    public void End() { current = null; }
    public void Undo() { End(); if (strokes.Count > 0) strokes.RemoveAt(strokes.Count - 1); Invalidate(); }
    public void ClearInk() { End(); strokes.Clear(); Invalidate(); }
    public void SetColor(Color next) { color = next; }
    public void ChangeWidth(int delta) { penWidth = Math.Max(1, Math.Min(40, penWidth + delta)); }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        foreach (InkStroke stroke in strokes)
        {
            if (stroke.Points.Count == 1)
            {
                using (Brush brush = new SolidBrush(stroke.Color))
                    e.Graphics.FillEllipse(brush, stroke.Points[0].X - stroke.Width / 2,
                        stroke.Points[0].Y - stroke.Width / 2, stroke.Width, stroke.Width);
            }
            else if (stroke.Points.Count > 1)
            {
                using (Pen pen = new Pen(stroke.Color, stroke.Width))
                {
                    pen.StartCap = LineCap.Round;
                    pen.EndCap = LineCap.Round;
                    pen.LineJoin = LineJoin.Round;
                    e.Graphics.DrawLines(pen, stroke.Points.ToArray());
                }
            }
        }
        using (Brush background = new SolidBrush(Color.FromArgb(36, 36, 36)))
            e.Graphics.FillRectangle(background, 12, 12, 475, 35);
        using (Brush foreground = new SolidBrush(Color.White))
            e.Graphics.DrawString("MODO DIBUJO  |  F4 salir  |  Supr limpiar  |  Ctrl+Z deshacer",
                SystemFonts.DefaultFont, foreground, 21, 21);
    }
}

public sealed class CaptureWindow : Form
{
    private readonly InkWindow ink;
    private readonly Action leave;
    private bool drawing;

    public CaptureWindow(InkWindow ink, Action leave)
    {
        this.ink = ink;
        this.leave = leave;
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        ShowInTaskbar = false;
        TopMost = true;
        BackColor = Color.Black;
        Opacity = 0.01;
        Cursor = Cursors.Cross;
        KeyPreview = true;
        Text = "DibujovichScreen Capture";
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;
        drawing = true;
        ink.Begin(e.Location);
    }
    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        if (drawing) ink.Continue(e.Location);
    }
    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        if (e.Button == MouseButtons.Left) { drawing = false; ink.End(); }
    }
    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (e.KeyCode == Keys.Escape) { leave(); return; }
        if (e.KeyCode == Keys.R) ink.SetColor(Color.Red);
        if (e.KeyCode == Keys.G) ink.SetColor(Color.Lime);
        if (e.KeyCode == Keys.B) ink.SetColor(Color.Cyan);
        if (e.KeyCode == Keys.Y) ink.SetColor(Color.Yellow);
        if (e.KeyCode == Keys.Add || e.KeyCode == Keys.Oemplus) ink.ChangeWidth(2);
        if (e.KeyCode == Keys.Subtract || e.KeyCode == Keys.OemMinus) ink.ChangeWidth(-2);
    }
}

public sealed class DrawingApp : ApplicationContext
{
    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")]
    private static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")]
    private static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")]
    private static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
    [DllImport("dwmapi.dll")]
    private static extern int DwmFlush();

    private readonly InkWindow ink = new InkWindow();
    private readonly CaptureWindow capture;
    private readonly Timer keyTimer = new Timer();
    private readonly NotifyIcon tray = new NotifyIcon();
    private bool f4WasDown;
    private bool undoWasDown;
    private bool deleteWasDown;
    private bool active;
    private int testStep;
    private int testFailures;
    private readonly Timer testTimer = new Timer();
    private Point originalCursor;
    private Point testPoint;
    private Color pixelBeforeStroke;

    public DrawingApp(bool selfTest)
    {
        capture = new CaptureWindow(ink, Deactivate);
        MenuItem exit = new MenuItem("Salir", delegate { ExitThread(); });
        tray.Icon = SystemIcons.Application;
        tray.Text = "DibujovichScreen: F4 para dibujar";
        tray.ContextMenu = new ContextMenu(new MenuItem[] { exit });
        tray.Visible = !selfTest;
        keyTimer.Interval = 25;
        keyTimer.Tick += PollKeyboard;
        keyTimer.Start();

        if (selfTest)
        {
            GetCursorPos(out originalCursor);
            Rectangle b = SystemInformation.VirtualScreen;
            testPoint = new Point(b.Left + Math.Min(240, b.Width / 2), b.Top + Math.Min(240, b.Height / 2));
            testTimer.Interval = 220;
            testTimer.Tick += RunTestStep;
            testTimer.Start();
        }
    }

    private void PollKeyboard(object sender, EventArgs e)
    {
        bool down = (GetAsyncKeyState((int)Keys.F4) & 0x8000) != 0;
        if (down && !f4WasDown) Toggle();
        f4WasDown = down;

        bool ctrl = (GetAsyncKeyState((int)Keys.ControlKey) & 0x8000) != 0;
        bool z = (GetAsyncKeyState((int)Keys.Z) & 0x8000) != 0;
        bool undoDown = ctrl && z;
        if (active && undoDown && !undoWasDown) ink.Undo();
        undoWasDown = undoDown;

        bool deleteDown = (GetAsyncKeyState((int)Keys.Delete) & 0x8000) != 0;
        if (active && deleteDown && !deleteWasDown) ink.ClearInk();
        deleteWasDown = deleteDown;
    }

    private void Toggle()
    {
        if (active) Deactivate();
        else
        {
            Rectangle bounds = SystemInformation.VirtualScreen;
            ink.Bounds = bounds;
            capture.Bounds = bounds;
            ink.Show();
            capture.Show();
            capture.Activate();
            active = true;
        }
    }

    private void Deactivate()
    {
        active = false;
        ink.End();
        capture.Hide();
        ink.Hide();
    }

    private void Assert(string name, bool passes)
    {
        Console.WriteLine(name + ": " + (passes ? "OK" : "FAILED"));
        if (!passes) testFailures++;
    }

    private Color SampleStrokePixel()
    {
        ink.Update();
        Application.DoEvents();
        DwmFlush();
        using (Bitmap sample = new Bitmap(1, 1))
        {
            using (Graphics g = Graphics.FromImage(sample))
                g.CopyFromScreen(testPoint.X + 50, testPoint.Y + 50, 0, 0, new Size(1, 1));
            return sample.GetPixel(0, 0);
        }
    }

    private void RunTestStep(object sender, EventArgs e)
    {
        if (testStep == 0) keybd_event((byte)Keys.F4, 0, 0, UIntPtr.Zero);
        if (testStep == 1)
        {
            Assert("F4 activates drawing", active && ink.Visible && capture.Visible);
            keybd_event((byte)Keys.F4, 0, 2, UIntPtr.Zero);
            SetCursorPos(testPoint.X, testPoint.Y);
            Assert("Overlay receives mouse", WindowFromPoint(testPoint) == capture.Handle);
            pixelBeforeStroke = SampleStrokePixel();
            mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
        }
        if (testStep == 2) SetCursorPos(testPoint.X + 100, testPoint.Y + 100);
        if (testStep == 3)
        {
            mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
            Assert("Mouse stroke is recorded", ink.StrokeCount == 1);
            Assert("Mouse drag is recorded", ink.LastPointCount > 1);
            Color pixel = SampleStrokePixel();
            Console.WriteLine("Sample pixel: " + pixel.R + "," + pixel.G + "," + pixel.B);
            Assert("Stroke is visible on screen", pixel.R > 150 && pixel.G < 110 && pixel.B < 110);
            keybd_event((byte)Keys.ControlKey, 0, 0, UIntPtr.Zero);
            keybd_event((byte)Keys.Z, 0, 0, UIntPtr.Zero);
        }
        if (testStep == 4)
        {
            Assert("Ctrl+Z removes last stroke", ink.StrokeCount == 0 && SampleStrokePixel().ToArgb() == pixelBeforeStroke.ToArgb());
            keybd_event((byte)Keys.Z, 0, 2, UIntPtr.Zero);
            keybd_event((byte)Keys.ControlKey, 0, 2, UIntPtr.Zero);
            SetCursorPos(testPoint.X, testPoint.Y);
            mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
        }
        if (testStep == 5) SetCursorPos(testPoint.X + 100, testPoint.Y + 100);
        if (testStep == 6)
        {
            mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
            Assert("Second stroke is recorded", ink.StrokeCount == 1);
            keybd_event((byte)Keys.Delete, 0, 0, UIntPtr.Zero);
        }
        if (testStep == 7)
        {
            Assert("Delete clears drawing", ink.StrokeCount == 0 && SampleStrokePixel().ToArgb() == pixelBeforeStroke.ToArgb());
            keybd_event((byte)Keys.Delete, 0, 2, UIntPtr.Zero);
            keybd_event((byte)Keys.F4, 0, 0, UIntPtr.Zero);
        }
        if (testStep == 8)
        {
            Assert("F4 deactivates drawing", !active && !ink.Visible && !capture.Visible);
            keybd_event((byte)Keys.F4, 0, 2, UIntPtr.Zero);
            SetCursorPos(originalCursor.X, originalCursor.Y);
            testTimer.Stop();
            Console.WriteLine(testFailures == 0 ? "SELFTEST PASSED" : "SELFTEST FAILED");
            Environment.ExitCode = testFailures == 0 ? 0 : 1;
            ExitThread();
        }
        testStep++;
    }

    protected override void ExitThreadCore()
    {
        keyTimer.Stop();
        testTimer.Stop();
        tray.Visible = false;
        tray.Dispose();
        capture.Close();
        ink.Close();
        base.ExitThreadCore();
    }
}

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        bool firstInstance;
        using (System.Threading.Mutex singleInstance = new System.Threading.Mutex(true, "Local\\DibujovichScreen", out firstInstance))
        {
            if (!firstInstance) return;
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            bool selfTest = args.Length > 0 && args[0] == "--self-test";
            if (selfTest && args.Length > 1)
            {
                using (StreamWriter log = new StreamWriter(args[1], false))
                {
                    log.AutoFlush = true;
                    Console.SetOut(log);
                    Application.Run(new DrawingApp(true));
                }
            }
            else Application.Run(new DrawingApp(selfTest));
        }
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies System.Windows.Forms,System.Drawing -ErrorAction Stop
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
[System.Windows.Forms.Application]::Run([DrawingApp]::new([bool]$SelfTest))
