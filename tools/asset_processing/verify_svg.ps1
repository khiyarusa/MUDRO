# MUDRO asset verification: XML well-formedness, canvas bounds, forbidden features.
$ErrorActionPreference = 'Stop'
$root = "F:\Save folder\My full Project\MUDRO"
$regions = @('zagros','alpine','glacier')
$bad = 0
$rows = @()

foreach ($reg in $regions) {
  $dir = Join-Path $root "assets\environments\$reg"
  foreach ($file in Get-ChildItem $dir -Filter *.svg | Sort-Object Name) {
    $raw = Get-Content $file.FullName -Raw
    $doc = $null
    try { $doc = [xml]$raw } catch { Write-Output ("XML-FAIL  " + $file.FullName + " :: " + $_.Exception.Message); $bad++; continue }
    $svg = $doc.DocumentElement
    $w = [double]$svg.width; $h = [double]$svg.height

    # forbidden constructs
    $forbidden = @()
    if ($raw -match '<text') { $forbidden += 'text' }
    if ($raw -match '<filter') { $forbidden += 'filter' }
    if ($raw -match '<image') { $forbidden += 'image' }
    if ($raw -match 'xlink:href|href=') { $forbidden += 'external-ref' }
    if ($raw -match 'http://(?!www\.w3\.org)') { $forbidden += 'remote-url' }

    # coordinate bounds: every numeric pair must sit inside the canvas
    $minX = [double]::MaxValue; $maxX = [double]::MinValue
    $minY = [double]::MaxValue; $maxY = [double]::MinValue
    $outside = 0
    $ns = @($svg.GetElementsByTagName('path'))
    foreach ($p in $ns) {
      $d = $p.d
      if (-not $d) { continue }
      $nums = [regex]::Matches($d, '-?\d+(?:\.\d+)?') | ForEach-Object { [double]$_.Value }
      for ($i = 0; $i + 1 -lt $nums.Count; $i += 2) {
        $x = $nums[$i]; $y = $nums[$i + 1]
        if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
        if ($x -lt 0 -or $x -gt $w -or $y -lt 0 -or $y -gt $h) { $outside++ }
      }
    }
    foreach ($e in @($svg.GetElementsByTagName('ellipse'))) {
      $cx=[double]$e.cx; $cy=[double]$e.cy; $rx=[double]$e.rx; $ry=[double]$e.ry
      if ($cx-$rx -lt 0 -or $cx+$rx -gt $w -or $cy-$ry -lt 0 -or $cy+$ry -gt $h) { $outside++ }
    }
    foreach ($e in @($svg.GetElementsByTagName('circle'))) {
      $cx=[double]$e.cx; $cy=[double]$e.cy; $r=[double]$e.r
      if ($cx-$r -lt 0 -or $cx+$r -gt $w -or $cy-$r -lt 0 -or $cy+$r -gt $h) { $outside++ }
    }
    foreach ($e in @($svg.GetElementsByTagName('rect'))) {
      $x=[double]$e.x; $y=[double]$e.y; $rw=[double]$e.width; $rh=[double]$e.height
      if ($x -lt 0 -or $y -lt 0 -or $x+$rw -gt $w -or $y+$rh -gt $h) { $outside++ }
    }

    $status = 'OK  '
    if ($outside -gt 0 -or $forbidden.Count -gt 0) { $status = 'FAIL'; $bad++ }
    $rows += [pscustomobject]@{
      Region = $reg; File = $file.Name; W = [int]$w; H = [int]$h
      KB = [math]::Round($file.Length/1024,1)
      Paths = $ns.Count; Bounds = "$([math]::Round($minX,1))..$([math]::Round($maxX,1)) x $([math]::Round($minY,1))..$([math]::Round($maxY,1))"
      Outside = $outside; Bad = ($forbidden -join ','); Status = $status
    }
  }
}

$rows | Format-Table -AutoSize | Out-String -Width 220
Write-Output ("TOTAL FILES: " + $rows.Count + "   FAILURES: " + $bad)
