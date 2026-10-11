$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$outDir = Split-Path $PSScriptRoot -Parent
$items = Get-Content (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$report = @()
$sheet = [System.Drawing.Bitmap]::new(1500, 2050)
$sg = [System.Drawing.Graphics]::FromImage($sheet)
$sg.Clear([System.Drawing.Color]::FromArgb(164,164,164))
$sg.InterpolationMode = 'HighQualityBicubic'
$font = [System.Drawing.Font]::new('Arial', 12)
$brush = [System.Drawing.Brushes]::Black
$index = 0
foreach ($item in $items) {
  $rawPath = Join-Path $PSScriptRoot ($item.name + '.png')
  Copy-Item -LiteralPath $item.source -Destination $rawPath -Force
  $src = [System.Drawing.Bitmap]::new($rawPath)
  $dst = [System.Drawing.Bitmap]::new([int]$item.width, [int]$item.height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.CompositingMode = 'SourceCopy'
  if (-not $item.transparent) { $g.Clear([System.Drawing.Color]::FromArgb(240,202,149)); $g.CompositingMode = 'SourceOver' }
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'
  $g.DrawImage($src, [System.Drawing.Rectangle]::new(0,0,$dst.Width,$dst.Height), 0,0,$src.Width,$src.Height,[System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $dst.Save((Join-Path $outDir ($item.name + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
  $zero = 0; $partial = 0; $opaque = 0; $min = 255; $max = 0
  for ($y=0; $y -lt $dst.Height; $y++) { for ($x=0; $x -lt $dst.Width; $x++) {
    $alpha = [int]$dst.GetPixel($x,$y).A
    if ($alpha -eq 0) { $zero++ } elseif ($alpha -eq 255) { $opaque++ } else { $partial++ }
    if ($alpha -lt $min) {$min=$alpha}; if ($alpha -gt $max) {$max=$alpha}
  }}
  $report += [pscustomobject]@{name=$item.name; width=$dst.Width; height=$dst.Height; sourceWidth=$src.Width; sourceHeight=$src.Height; alphaMin=$min; alphaMax=$max; transparentPixels=$zero; partialPixels=$partial; opaquePixels=$opaque}
  if ($index -eq 0) {
    $sg.DrawImage($dst, [System.Drawing.Rectangle]::new(30,30,915,412))
    $sg.DrawString('desk_background.png  1830 x 824', $font, $brush, 970,60)
  } else {
    $col = ($index-1) % 5; $row = [math]::Floor(($index-1)/5)
    $scale = [math]::Min(265.0/$dst.Width, 210.0/$dst.Height)
    $pw=[int]($dst.Width*$scale); $ph=[int]($dst.Height*$scale)
    $left=[int]($col*300+15+(265-$pw)/2); $top=[int](480+$row*260+(210-$ph)/2)
    $sg.DrawImage($dst,[System.Drawing.Rectangle]::new($left,$top,$pw,$ph))
    $sg.DrawString(($item.name+'.png'),$font,$brush,[single]($col*300+15),[single](480+$row*260+220))
  }
  $src.Dispose(); $dst.Dispose(); $index++
}
$sg.Dispose(); $font.Dispose()
$sheet.Save((Join-Path $outDir 'contact_sheet.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
$report | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'validation.json') -Encoding utf8
$report | Format-Table name,width,height,alphaMin,alphaMax,transparentPixels,partialPixels
