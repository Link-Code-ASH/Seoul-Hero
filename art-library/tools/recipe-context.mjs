// Display-only motion for the existing reference PNGs; contains no game decisions.
export function buildContextLayers(recipe) {
  const d=recipe.duration;
  const key=(fraction,x,y,scale,rotation,opacity,easing='easeInOutSine')=>({t:Math.round(d*fraction*1000)/1000,x,y,scale,rotation,opacity,easing});
  if(recipe.context==='upgrade')return [{referenceId:'upgrade-icon',start:0,end:d,z:-20,displaySize:76,keyframes:[key(0,0,0,1,0,1),key(0.46,0,0,1.08,0,1),key(0.75,0,0,1,0,1),key(1,0,0,1,0,1)]}];
  if(recipe.context!=='opening')return [];
  return [
    {referenceId:'supply-crate',start:0,end:d,z:-20,displaySize:160,keyframes:[key(0,0,48,1,0,1),key(0.08,-3,48,1,-1,1),key(0.14,3,48,1,1,1),key(0.22,-2,48,1,0,1),key(0.36,0,48,1,0,1),key(1,0,48,1,0,1)]},
    {referenceId:'supply-lid',start:0,end:d,z:-10,displaySize:160,keyframes:[key(0,0,8,1,0,1),key(0.15,0,8,1,0,1),key(0.37,10,-54,1,-9,1,'easeOutCubic'),key(0.56,24,-96,1,-19,1),key(0.80,35,-112,1,-26,0.15),key(1,35,-112,1,-26,0)]}
  ];
}
