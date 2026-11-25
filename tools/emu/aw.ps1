# aw.ps1 - drive AppleWin from PowerShell
#   aw.ps1 start [image]     launch enhanced //e, RamWorks 8 MB, image as slot 7 HD1
#   aw.ps1 shot  <out.png>   capture the AppleWin window (PrintWindow, works when covered)
#   aw.ps1 keys  <text>      bring AppleWin to front and type; ~ = Return (SendKeys syntax)
#   aw.ps1 stop              close AppleWin
param([string]$cmd, [string]$arg = "")

$exe  = "D:\AppleWin1.32.0.0\AppleWin.exe"
$conf = Join-Path $PSScriptRoot "applewin-cobolos.ini"

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint f, UIntPtr x);
  public struct RECT { public int L, T, R, B; }
}
"@

function Get-AW { Get-Process -Name AppleWin -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1 }

switch ($cmd) {
  "start" {
    if (Get-AW) { "already running"; break }
    $img = if ($arg) { $arg } else { "D:\AppleWin1.32.0.0\COBOLOS.po" }
    # "first.po;second.po" puts the second in slot 7 as drive 2
    $h2 = $null; if ($img.Contains(";")) { $h2 = $img.Split(";")[1]; $img = $img.Split(";")[0] }
    $a = @("-conf", "`"$conf`"", "-model", "apple2ee", "-r", "128", "-s7", "hdc", "-h1", "`"$img`"",
           "-no-full-screen", "-no-printscreen-dlg", "-noreg")
    if ($h2) { $a += @("-h2", "`"$h2`"") }
    Start-Process -FilePath $exe -ArgumentList $a -WorkingDirectory (Split-Path $exe) | Out-Null
    for ($i = 0; $i -lt 40 -and -not (Get-AW); $i++) { Start-Sleep -Milliseconds 250 }
    if (Get-AW) { "started pid " + (Get-AW).Id } else { "did not start" }
  }
  "shot" {
    $p = Get-AW; if (-not $p) { "not running"; exit 1 }
    $h = $p.MainWindowHandle; $r = New-Object W+RECT; [W]::GetWindowRect($h, [ref]$r) | Out-Null
    $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
    [W]::PrintWindow($h, $dc, 2) | Out-Null   # 2 = PW_RENDERFULLCONTENT
    $g.ReleaseHdc($dc); $g.Dispose(); $bmp.Save($arg, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    "saved $arg"
  }
  "keys" {
    $p = Get-AW; if (-not $p) { "not running"; exit 1 }
    [W]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
    [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 300
    if ([W]::GetForegroundWindow() -ne $p.MainWindowHandle) { "could not bring AppleWin to front"; exit 1 }
    # Plain SendKeys characters never reach the emulated keyboard; AppleWin's
    # own paste (Shift+Insert) does, so type through the clipboard.
    $old = [System.Windows.Forms.Clipboard]::GetText()
    [System.Windows.Forms.Clipboard]::SetText($arg.Replace("~", "`r"))
    [System.Windows.Forms.SendKeys]::SendWait("+{INSERT}")
    Start-Sleep -Milliseconds (300 + 40 * $arg.Length)
    if ($old) { [System.Windows.Forms.Clipboard]::SetText($old) } else { [System.Windows.Forms.Clipboard]::Clear() }
    "typed"
  }
  "raw" {   # one SendKeys string as-is, e.g. {F2} or ^c
    $p = Get-AW; if (-not $p) { "not running"; exit 1 }
    [W]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
    [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 300
    if ([W]::GetForegroundWindow() -ne $p.MainWindowHandle) { "could not bring AppleWin to front"; exit 1 }
    [System.Windows.Forms.SendKeys]::SendWait($arg); "sent"
  }
  "dbg" {   # debugger commands separated by ';', each sent with Enter; stops on any failure
    $p = Get-AW; if (-not $p) { "not running"; exit 1 }
    foreach ($c in $arg.Split(';')) {
      [W]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
      [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
      Start-Sleep -Milliseconds 400
      if ([W]::GetForegroundWindow() -ne $p.MainWindowHandle) { "FOCUS LOST before: $c - stopped"; exit 1 }
      $k = $c -replace '([+^%~(){}\[\]])', '{$1}'
      [System.Windows.Forms.SendKeys]::SendWait("$k{ENTER}"); Start-Sleep -Milliseconds 300
    }
    "sent"
  }
  "sa" {   # Solid-Apple (right Alt) + one letter, or UP DOWN LEFT RIGHT
    $p = Get-AW; if (-not $p) { "not running"; exit 1 }
    [W]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
    [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 300
    if ([W]::GetForegroundWindow() -ne $p.MainWindowHandle) { "could not bring AppleWin to front"; exit 1 }
    $arrows = @{ UP = 0x26; DOWN = 0x28; LEFT = 0x25; RIGHT = 0x27 }
    $ext = 0
    if ($arrows.ContainsKey($arg.ToUpper())) { $vk = [byte]$arrows[$arg.ToUpper()]; $ext = 1 }
    else { $vk = [byte][char]$arg.ToUpper() }
    [W]::keybd_event(0xA5, 0x38, 1, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [W]::keybd_event($vk, 0, $ext, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [W]::keybd_event($vk, 0, (2 + $ext), [UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [W]::keybd_event(0xA5, 0x38, 3, [UIntPtr]::Zero); "sent"
  }
  "oa" {   # Open-Apple (left Alt) + one letter, or UP DOWN LEFT RIGHT
    $p = Get-AW; if (-not $p) { "not running"; exit 1 }
    [W]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
    [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 300
    if ([W]::GetForegroundWindow() -ne $p.MainWindowHandle) { "could not bring AppleWin to front"; exit 1 }
    $arrows = @{ UP = 0x26; DOWN = 0x28; LEFT = 0x25; RIGHT = 0x27 }
    $ext = 0
    if ($arrows.ContainsKey($arg.ToUpper())) { $vk = [byte]$arrows[$arg.ToUpper()]; $ext = 1 }
    else { $vk = [byte][char]$arg.ToUpper() }
    [W]::keybd_event(0xA4, 0x38, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [W]::keybd_event($vk, 0, $ext, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [W]::keybd_event($vk, 0, (2 + $ext), [UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [W]::keybd_event(0xA4, 0x38, 2, [UIntPtr]::Zero); "sent"
  }
  "stop" { $p = Get-AW; if ($p) { $p.CloseMainWindow() | Out-Null; Start-Sleep 2; if (-not $p.HasExited) { $p.Kill() }; "stopped" } else { "not running" } }
  default { "usage: aw.ps1 start|shot|keys|raw|dbg|sa|oa|stop [arg]" }
}
