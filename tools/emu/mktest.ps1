# mktest.ps1 - the test disks: the same files, two systems
#   mktest.ps1 [-Test TEST3]   (TEST2 by default)
#                  -> D:\AppleWin1.32.0.0\TESTOS.po  (boots COBOL.OS)
#                     D:\AppleWin1.32.0.0\TESTPD.po  (boots ProDOS 8)
#
# Both are 800K volumes named /TESTVOL holding the files src/TEST2.S
# reads, and TEST2.BIN as COBOL.SYSTEM.  TESTOS has our block 0 and
# COBOL.OS; TESTPD has ProDOS's blocks 0-1 and PRODOS, both taken from
# COBOL32.po (which is only read).  TEST2 must pass on both: on ProDOS
# that proves the test's expectations, on COBOL.OS the kernel.
#
# Every data byte is (p0 + 7*p1 + 13*p2) mod 256, p = its position,
# except the zero runs in HOLES and TREEH.  Files are BIN ($06).
# Refuses while AppleWin is running.
param([string]$Test = "TEST2")
$cp2  = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"
$aw   = "D:\AppleWin1.32.0.0"
$obj  = "P:\COBOLOS\build\obj"
if (Get-Process AppleWin* -ErrorAction SilentlyContinue) { "AppleWin is running - not writing the disks"; exit 1 }

function Pattern([int]$len, [scriptblock]$hole) {
  $b = New-Object byte[] $len
  for ($p = 0; $p -lt $len; $p++) {
    if ($hole -and (& $hole $p)) { continue }
    $b[$p] = [byte](((($p -band 0xFF) + 7 * (($p -shr 8) -band 0xFF) + 13 * ($p -shr 16))) -band 0xFF)
  }
  ,$b
}

$w = Join-Path $PSScriptRoot "mktest-stage"
if (Test-Path $w) { Remove-Item -Recurse -Force $w }
New-Item -ItemType Directory "$w\files\DIR\SUB" | Out-Null
$f = "$w\files"
[IO.File]::WriteAllBytes("$f\SEED#060000",  (Pattern 300))
[IO.File]::WriteAllBytes("$f\EMPTY#060000", (New-Object byte[] 0))
[IO.File]::WriteAllBytes("$f\SAP#060000",   (Pattern 70000))
[IO.File]::WriteAllBytes("$f\TREE#060000",  (Pattern 140000))
[IO.File]::WriteAllBytes("$f\HOLES#060000", (Pattern 20480 { param($p) $p -ge 2560 -and $p -lt 5120 }))
[IO.File]::WriteAllBytes("$f\TREEH#060000", (Pattern 263000 { param($p) $p -ge 131072 -and $p -lt 262144 }))
$text = (1..30 | ForEach-Object { "LINE $_`r" }) -join ""
[IO.File]::WriteAllBytes("$f\TEXT#060000", [Text.Encoding]::ASCII.GetBytes($text + "END"))
for ($i = 1; $i -le 20; $i++) {
  [IO.File]::WriteAllBytes(("$f\DIR\F{0:D2}#060000" -f $i), (Pattern (10 * $i)))
}
[IO.File]::WriteAllBytes("$f\DIR\SUB\DEEP#060000", (Pattern 100))

# ---- the shared base volume -------------------------------------------
$base = "$w\TESTBASE.po"
& $cp2 cdi $base 800k prodos | Out-Null
& $cp2 rename $base "/" TESTVOL | Out-Null
Push-Location $f
& $cp2 add --from-naps --recurse $base SEED#060000 EMPTY#060000 SAP#060000 TREE#060000 HOLES#060000 TREEH#060000 TEXT#060000 DIR | Out-Null
Pop-Location
Copy-Item "$obj\$Test.BIN" "$w\COBOL.SYSTEM#ff2000"

function Put-Blocks($img, [byte[]]$bytes) {
  $fs = [IO.File]::Open($img, 'Open', 'ReadWrite')
  $fs.Seek(0, 'Begin') | Out-Null; $fs.Write($bytes, 0, $bytes.Length); $fs.Close()
}

# ---- TESTOS: our block 0, COBOL.OS ------------------------------------
$os = "$aw\TESTOS.po"
Copy-Item $base $os -Force
$boot = [IO.File]::ReadAllBytes("$obj\BOOTBLK.BIN")
$blk = New-Object byte[] 512; [Array]::Copy($boot, $blk, $boot.Length)
Put-Blocks $os $blk
Copy-Item "$obj\COBOLOS.BIN" "$w\COBOL.OS#ff2000"
Push-Location $w
& $cp2 add --from-naps $os "COBOL.OS#ff2000" "COBOL.SYSTEM#ff2000" | Out-Null
Pop-Location

# ---- TESTPD: ProDOS's blocks 0-1 and PRODOS, from COBOL32.po -----------
$pd = "$aw\TESTPD.po"
Copy-Item $base $pd -Force
$src = [IO.File]::ReadAllBytes("$aw\COBOL32.po")
$pb = New-Object byte[] 1024; [Array]::Copy($src, $pb, 1024)
Put-Blocks $pd $pb
New-Item -ItemType Directory "$w\pd" | Out-Null
Push-Location "$w\pd"
& $cp2 extract --preserve=naps "$aw\COBOL32.po" PRODOS | Out-Null
$pf = Get-ChildItem | Select-Object -First 1
& $cp2 add --from-naps $pd $pf.Name | Out-Null
Pop-Location
Push-Location $w
& $cp2 add --from-naps $pd "COBOL.SYSTEM#ff2000" | Out-Null
Pop-Location

foreach ($img in $os, $pd) {
  "== $img"
  & $cp2 test $img | Select-Object -Last 1
  & $cp2 catalog $img | Select-String -NotMatch "DIR:"
}
Remove-Item -Recurse -Force $w
