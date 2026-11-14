# Turns a rendered PNG into a coarse luminance map + band colour report, so the
# composition can be judged without opening the image.
param(
  [string]$Path,
  [string]$Back = '#f0dcbd',
  [int]$Cols = 96,
  [int]$Rows = 30,
  [switch]$Auto
)
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap($Path)
$W = $bmp.Width; $H = $bmp.Height
$backCol = [System.Drawing.ColorTranslator]::FromHtml($Back)
$ramp = ' .:-=+*#%@'
$lumGrid = New-Object 'double[,]' $Rows, $Cols
$minL = 1e9; $maxL = -1e9
for ($r = 0; $r -lt $Rows; $r++) {
  for ($c = 0; $c -lt $Cols; $c++) {
    $x0 = [int]($c * $W / $Cols); $x1 = [int](($c + 1) * $W / $Cols)
    $y0 = [int]($r * $H / $Rows); $y1 = [int](($r + 1) * $H / $Rows)
    $sum = 0.0; $n = 0
    for ($y = $y0; $y -lt $y1; $y += 3) {
      for ($x = $x0; $x -lt $x1; $x += 3) {
        $p = $bmp.GetPixel($x, $y)
        $a = $p.A / 255.0
        $rr = $p.R * $a + $backCol.R * (1 - $a)
        $gg = $p.G * $a + $backCol.G * (1 - $a)
        $bb = $p.B * $a + $backCol.B * (1 - $a)
        $sum += (0.299 * $rr + 0.587 * $gg + 0.114 * $bb)
        $n++
      }
    }
    $lum = $sum / [math]::Max($n, 1)
    $lumGrid[$r, $c] = $lum
    if ($lum -lt $minL) { $minL = $lum }
    if ($lum -gt $maxL) { $maxL = $lum }
  }
}
if (-not $Auto) { $minL = 0; $maxL = 255 }
$span = [math]::Max($maxL - $minL, 1.0)
$lines = @()
for ($r = 0; $r -lt $Rows; $r++) {
  $sb = ''
  for ($c = 0; $c -lt $Cols; $c++) {
    $t = ($lumGrid[$r, $c] - $minL) / $span
    $idx = [int]([math]::Round($t * ($ramp.Length - 1)))
    $idx = [math]::Min([math]::Max($idx, 0), $ramp.Length - 1)
    $sb += $ramp[$idx]
  }
  $lines += $sb
}
Write-Output ("FILE: " + (Split-Path $Path -Leaf) + "  " + $W + "x" + $H)
$lines | ForEach-Object { Write-Output $_ }
Write-Output '--- band means (r,g,b) ---'
for ($b = 0; $b -lt 6; $b++) {
  $y0 = [int]($b * $H / 6); $y1 = [int](($b + 1) * $H / 6)
  $sr = 0.0; $sg = 0.0; $sbb = 0.0; $n = 0
  for ($y = $y0; $y -lt $y1; $y += 4) {
    for ($x = 0; $x -lt $W; $x += 8) {
      $p = $bmp.GetPixel($x, $y)
      $a = $p.A / 255.0
      $sr += $p.R * $a + $backCol.R * (1 - $a)
      $sg += $p.G * $a + $backCol.G * (1 - $a)
      $sbb += $p.B * $a + $backCol.B * (1 - $a)
      $n++
    }
  }
  Write-Output ("band $b  y $y0..$y1   ({0,3:N0},{1,3:N0},{2,3:N0})" -f ($sr/$n), ($sg/$n), ($sbb/$n))
}
$bmp.Dispose()
