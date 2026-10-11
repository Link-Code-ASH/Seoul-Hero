$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location,[System.Drawing.Rectangle].Assembly.Location,'System.Runtime') -TypeDefinition @'
using System;
using System.Drawing;
public static class IconPixels {
 public static Rectangle Bounds(Bitmap b) {
  int l=b.Width,t=b.Height,r=0,d=0;
  for(int y=0;y<b.Height;y++) for(int x=0;x<b.Width;x++) if(b.GetPixel(x,y).A>32) {l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);d=Math.Max(d,y);}
  return Rectangle.FromLTRB(Math.Max(0,l-2),Math.Max(0,t-2),Math.Min(b.Width,r+3),Math.Min(b.Height,d+3));
 }
 public static long[] Check(Bitmap b) {
  long z=0,p=0,o=0,e=0;
  for(int y=0;y<b.Height;y++) for(int x=0;x<b.Width;x++) {int a=b.GetPixel(x,y).A;if(a==0)z++;else if(a==255)o++;else p++;if((x==0||y==0||x==b.Width-1||y==b.Height-1)&&a!=0)e++;}
  return new long[]{z,p,o,e};
 }
}
'@
$root=Split-Path $PSScriptRoot -Parent
$items=Get-Content (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$cream=[System.Drawing.ColorTranslator]::FromHtml('#FBF6EC')
$orange=[System.Drawing.ColorTranslator]::FromHtml('#FF9A4D')
$navy=[System.Drawing.ColorTranslator]::FromHtml('#24395C')
$brush=[System.Drawing.SolidBrush]::new($navy)
$font=[System.Drawing.Font]::new('Arial',12)
$sheet=[System.Drawing.Bitmap]::new(1200,870)
$sg=[System.Drawing.Graphics]::FromImage($sheet)
$sg.Clear($cream); $sg.InterpolationMode='HighQualityBicubic'; $sg.PixelOffsetMode='HighQuality'
$small=[System.Drawing.Bitmap]::new(800,150)
$sm=[System.Drawing.Graphics]::FromImage($small)
$sm.Clear($cream); $sm.InterpolationMode='HighQualityBicubic'; $sm.PixelOffsetMode='HighQuality'
$round=[System.Drawing.Bitmap]::new((Join-Path (Split-Path $root -Parent) 'button_round_normal.png'))
$report=@()
$speakerBox=$null
for($i=0;$i -lt $items.Count;$i++){
 $item=$items[$i]
 $raw=Join-Path $PSScriptRoot ($item.name+'.png')
 Copy-Item -LiteralPath $item.source -Destination $raw -Force
 $src=[System.Drawing.Bitmap]::new($raw)
 $box=[IconPixels]::Bounds($src)
 if($item.name -eq 'icon_sound_on'){$speakerBox=$box}
 if($item.name -eq 'icon_sound_off'){$box=$speakerBox}
 $scale=[math]::Min(408.0/$box.Width,408.0/$box.Height)
 $w=[int]($box.Width*$scale); $h=[int]($box.Height*$scale)
 $x=[int]((512-$w)/2); $y=[int]((512-$h)/2)
 $dst=[System.Drawing.Bitmap]::new(512,512,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $g=[System.Drawing.Graphics]::FromImage($dst)
 $g.InterpolationMode='HighQualityBicubic';$g.PixelOffsetMode='HighQuality';$g.CompositingMode='SourceCopy'
 $g.DrawImage($src,[System.Drawing.Rectangle]::new($x,$y,$w,$h),$box,[System.Drawing.GraphicsUnit]::Pixel)
 $g.Dispose()
 $path=Join-Path $root ($item.name+'.png')
 $dst.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
 $v=[IconPixels]::Check($dst)
 $report += [pscustomobject]@{file=$item.name+'.png';width=512;height=512;mode='RGBA';transparentPixels=$v[0];partialAlphaPixels=$v[1];opaquePixels=$v[2];edgesTransparent=($v[3]-eq 0);placement=@($x,$y,$w,$h);sourceCrop=@($box.X,$box.Y,$box.Width,$box.Height);sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
 $cx=($i%4)*300; $cy=[int][math]::Floor($i/4)*340
 $sg.DrawImage($dst,[System.Drawing.Rectangle]::new($cx+22,$cy+12,256,256))
 $sg.DrawString(($item.name+'.png'),$font,$brush,[single]($cx+10),[single]($cy+278))
 $sg.DrawImage($round,[System.Drawing.Rectangle]::new($cx+125,$cy+300,42,42))
 $sg.DrawImage($dst,[System.Drawing.Rectangle]::new($cx+125,$cy+300,42,42))
 $sm.DrawImage($round,[System.Drawing.Rectangle]::new(20+$i*95,36,42,42))
 $sm.DrawImage($dst,[System.Drawing.Rectangle]::new(20+$i*95,36,42,42))
 $sm.DrawString(([string]($i+1)),$font,$brush,[single](32+$i*95),[single]90)
 if($item.name -eq 'icon_deploy_gate'){
  $ob=[System.Drawing.SolidBrush]::new($orange)
  $sg.FillRectangle($ob,900,340,300,340)
  $sg.DrawImage($dst,[System.Drawing.Rectangle]::new(922,352,256,256))
  $sg.DrawString('deploy / #FF9A4D',$font,$brush,920,618)
  $sg.DrawImage($dst,[System.Drawing.Rectangle]::new(1010,640,42,42))
  $sm.FillRectangle($ob,690,20,90,100)
  $sm.DrawImage($dst,[System.Drawing.Rectangle]::new(705,28,60,60))
  $sm.DrawString('60px',$font,$brush,712,92)
  $ob.Dispose()
 }
 $src.Dispose();$dst.Dispose()
}
$sg.DrawString('42px on existing cream buttons / deploy 60px on orange',$font,$brush,20,720)
$sg.DrawImageUnscaled($small,20,742)
$sg.Dispose();$sm.Dispose();$round.Dispose();$font.Dispose();$brush.Dispose()
$sheet.Save((Join-Path $root 'contact_sheet.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$small.Save((Join-Path $PSScriptRoot 'preview_42px.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose();$small.Dispose()
$report | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $PSScriptRoot 'validation.json') -Encoding utf8
$report | Format-Table file,width,height,edgesTransparent,transparentPixels,partialAlphaPixels
