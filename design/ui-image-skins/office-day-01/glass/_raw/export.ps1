$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location,[System.Drawing.Rectangle].Assembly.Location,'System.Runtime') -TypeDefinition @'
using System;
using System.Drawing;
public static class GlassExport {
 static int Clamp(int a,int lo,int hi){return Math.Max(lo,Math.Min(hi,a));}
 public static Bitmap Make(Bitmap src,int w,int h,int skew,bool round,bool pressed) {
  int top=src.Height,bottom=0,left=src.Width,right=0;
  int[] ls=new int[src.Height],rs=new int[src.Height],counts=new int[src.Height];
  for(int y=0;y<src.Height;y++){
   ls[y]=src.Width;rs[y]=0;
   for(int x=0;x<src.Width;x++) if(src.GetPixel(x,y).A>180){ls[y]=Math.Min(ls[y],x);rs[y]=Math.Max(rs[y],x);counts[y]++;}
   if(counts[y]>src.Width*(round?.05:.55)){top=Math.Min(top,y);bottom=Math.Max(bottom,y);}
  }
  for(int y=top;y<=bottom;y++){left=Math.Min(left,ls[y]);right=Math.Max(right,rs[y]);}
  int stripe=0;
  if(w==452){int row=(top+bottom)/2;double best=0;for(int xx=ls[row]+10;xx<src.Width*.4;xx++){Color cc=src.GetPixel(xx,row);double score=cc.G-cc.R;if(score>best){best=score;stripe=xx;}}}
  Bitmap b=new Bitmap(w,h,System.Drawing.Imaging.PixelFormat.Format32bppArgb);
  int dy=pressed?3:0; double bh=h-11, bw=w-8-skew;
  double rad=(w-12)/2.0,cy=4+rad;
  for(int y=0;y<h;y++) for(int x=0;x<w;x++){
   double v=(y+.5-dy-4)/bh,u=0,coverage=0;
   for(int yy=0;yy<4;yy++)for(int xx=0;xx<4;xx++){
    double px=x+(xx+.5)/4,py=y+(yy+.5)/4-dy;
    bool inside;
    if(round)inside=Math.Pow(px-w/2.0,2)+Math.Pow(py-cy,2)<=rad*rad;
    else {double vv=(py-4)/bh,edge=4+skew*(1-vv);inside=vv>=0&&vv<=1&&px>=edge&&px<=edge+bw;}
    if(inside)coverage+=1.0/16;
   }
   if(coverage==0)continue;
   double sx,sy;
   if(round){u=(x+.5-(w/2.0-rad))/(2*rad);v=(y+.5-dy-4)/(2*rad);sx=left+u*(right-left);sy=top+v*(bottom-top);}
   else {u=(x+.5-4-skew*(1-v))/bw;sy=top+Math.Max(0,Math.Min(1,v))*(bottom-top);int row=Clamp((int)Math.Round(sy),top,bottom);sx=ls[row]+Math.Max(0,Math.Min(1,u))*(rs[row]-ls[row]);}
   if(w==452){int row=Clamp((int)Math.Round(sy),top,bottom);double dl=4+skew*(1-v),dr=dl+bw; sx=x+.5<130?ls[row]+(x+.5-dl)/(130-dl)*(stripe-ls[row]):stripe+(x+.5-130)/(dr-130)*(rs[row]-stripe);}
   Color c=src.GetPixel(Clamp((int)Math.Round(sx),0,src.Width-1),Clamp((int)Math.Round(sy),0,src.Height-1));
   int alpha=(int)Math.Round((140+10*Math.Max(0,Math.Min(1,v))+(pressed?15:0))*coverage);
   b.SetPixel(x,y,Color.FromArgb(alpha,c.R,c.G,c.B));
  }
  return b;
 }
 public static long[] Check(Bitmap b){long z=0,core=0,edge=0,min=255,max=0;
  for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){int a=b.GetPixel(x,y).A;if(a==0)z++;if(a>=140){core++;min=Math.Min(min,a);max=Math.Max(max,a);}if((x==0||y==0||x==b.Width-1||y==b.Height-1)&&a!=0)edge++;}
  return new long[]{z,core,min,max,edge};
 }
 public static int MaskDiff(Bitmap a,Bitmap b,int dy){int n=0;for(int y=0;y<a.Height-dy;y++)for(int x=0;x<a.Width;x++)if((a.GetPixel(x,y).A>0)!=(b.GetPixel(x,y+dy).A>0))n++;return n;}
 public static int AlphaDiff(Bitmap a,Bitmap b){int n=0;for(int y=2;y<a.Height-5;y++)for(int x=2;x<a.Width-2;x++){bool core=true;for(int yy=-2;yy<=2;yy++)for(int xx=-2;xx<=2;xx++)if(a.GetPixel(x+xx,y+yy).A<140)core=false;if(core&&b.GetPixel(x,y+3).A-a.GetPixel(x,y).A!=15)n++;}return n;}
}
'@
$root=Split-Path $PSScriptRoot -Parent
$items=Get-Content (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$report=@();$images=@{}
foreach($item in $items){
 $raw=Join-Path $PSScriptRoot ($item.name+'.png')
 Copy-Item -LiteralPath $item.source -Destination $raw -Force
 $src=[System.Drawing.Bitmap]::new($raw)
 if($item.name -like '*chevron*'){
  $dst=[System.Drawing.Bitmap]::new([int]$item.width,[int]$item.height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g=[System.Drawing.Graphics]::FromImage($dst);$g.InterpolationMode='HighQualityBicubic';$g.PixelOffsetMode='HighQuality'
  $g.DrawImage($src,[System.Drawing.Rectangle]::new(2,2,$dst.Width-4,$dst.Height-4));$g.Dispose()
 }else{
  $skew=24;if($item.name -like '*deploy*'){$skew=36}
  $dst=[GlassExport]::Make($src,$item.width,$item.height,$skew,($item.name -like '*round*'),($item.name -like '*pressed*'))
 }
 $dst.Save((Join-Path $root ($item.name+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
 $v=[GlassExport]::Check($dst)
 $report += [pscustomobject]@{file=$item.name+'.png';width=$dst.Width;height=$dst.Height;transparentPixels=$v[0];coreAlphaMin=$v[2];coreAlphaMax=$v[3];edgeNonzero=$v[4]}
 $images[$item.name]=$dst;$src.Dispose()
}
$stateChecks=@()
foreach($family in @('menu','deploy','round')){
 $a=$images['glass_'+$family+'_normal'];$b=$images['glass_'+$family+'_pressed']
 $stateChecks += [pscustomobject]@{family=$family;pressedOffsetY=3;maskMismatchAfterAlignment=[GlassExport]::MaskDiff($a,$b,3);coreAlphaDeltaMismatch=[GlassExport]::AlphaDiff($a,$b)}
}
$hoverDiff=[GlassExport]::MaskDiff($images['glass_menu_normal'],$images['glass_menu_hover'],0)
$sheet=[System.Drawing.Bitmap]::new(1830,474)
$sg=[System.Drawing.Graphics]::FromImage($sheet);$sg.Clear([System.Drawing.ColorTranslator]::FromHtml('#FBF6EC'))
$sg.InterpolationMode='HighQualityBicubic';$sg.PixelOffsetMode='HighQuality'
$bg=[System.Drawing.Bitmap]::new((Join-Path (Get-Location) 'godot/assets/ui/office-day-01/lobby_office_bg_soft.png'))
$sg.DrawImage($bg,[System.Drawing.Rectangle]::new(0,48,915,412))
$font=[System.Drawing.Font]::new('Arial',11)
$ink=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#24395C'))
$sg.DrawString('OFFICE / 915 x 412',$font,$ink,18,14)
$sg.DrawString('CREAM / #FBF6EC',$font,$ink,933,14)
$layout=@(
 @('glass_menu_normal',18,25),@('glass_menu_pressed',18,115),@('glass_menu_hover',18,205),
 @('glass_deploy_normal',455,25),@('glass_deploy_pressed',455,220),
 @('glass_round_normal',18,315),@('glass_round_pressed',140,315),
 @('glass_chevron_double',275,323),@('glass_chevron_triple',352,316))
foreach($shift in @(0,915)){
 foreach($p in $layout){
  $im=$images[$p[0]];$x=[int]$p[1]+$shift;$y=[int]$p[2]+48
  $sg.DrawImage($im,[System.Drawing.Rectangle]::new($x,$y,[int]($im.Width*.75),[int]($im.Height*.75)))
  $label=$p[0].Replace('glass_','').Replace('chevron_','')
  $sg.DrawString($label,$font,$ink,[single]$x,[single]($y-18))
 }
}
$sg.Dispose();$bg.Dispose();$font.Dispose();$ink.Dispose()
$sheet.Save((Join-Path $root 'contact_sheet.png'),[System.Drawing.Imaging.ImageFormat]::Png);$sheet.Dispose()
foreach($im in $images.Values){$im.Dispose()}
@{files=$report;states=$stateChecks;hoverMaskMismatch=$hoverDiff} | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $PSScriptRoot 'validation.json') -Encoding utf8
$report | Format-Table
$stateChecks | Format-Table
Write-Output "Hover mask mismatch: $hoverDiff"
