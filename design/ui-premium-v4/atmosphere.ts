/** Decorative mockup layer: no gameplay timers or persistent state. */
export function mountAtmosphere(canvas: HTMLCanvasElement, scene: string): () => void {
  const ctx=canvas.getContext('2d');
  if(!ctx)return ()=>{};
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const points=Array.from({length:scene==='rain'?90:34},()=>({x:Math.random()*915,y:Math.random()*412,z:.4+Math.random()*.6,phase:Math.random()*6.28}));
  let handle=0,last=0,time=0;
  function frame(now:number){
    const dt=Math.min((now-last)/1000,.04);last=now;
    if(!document.hidden){
      time+=dt;ctx!.clearRect(0,0,915,412);
      for(const p of points){
        if(scene==='rain'){
          p.x-=dt*90*p.z;p.y+=dt*380*p.z;
          ctx!.strokeStyle=`rgba(180,213,232,${.13*p.z})`;ctx!.lineWidth=.6*p.z;
          ctx!.beginPath();ctx!.moveTo(p.x,p.y);ctx!.lineTo(p.x-3*p.z,p.y+13*p.z);ctx!.stroke();
        }else if(scene==='wind'){
          p.x+=dt*39*p.z;p.y+=Math.sin(time+p.phase)*dt*9;
          ctx!.fillStyle=`rgba(217,197,150,${.2*p.z})`;ctx!.save();ctx!.translate(p.x,p.y);ctx!.rotate(time*.8+p.phase);ctx!.fillRect(-1,-.5,3*p.z,1*p.z);ctx!.restore();
        }else{
          p.x+=Math.sin(time*.5+p.phase)*dt*9;p.y-=dt*12*p.z;
          ctx!.fillStyle=`rgba(124,204,218,${(.2+.15*Math.sin(time+p.phase))*p.z})`;ctx!.beginPath();ctx!.arc(p.x,p.y,1.2*p.z,0,Math.PI*2);ctx!.fill();
        }
        if(p.x>925)p.x=-10;if(p.x< -10)p.x=925;if(p.y>425)p.y=-12;if(p.y< -12)p.y=425;
      }
      // Slow atmospheric light breath, never a full-screen flash.
      const glow=ctx!.createRadialGradient(370,180,0,370,180,105);
      glow.addColorStop(0,`rgba(77,193,204,${.025+.018*Math.sin(time*.65)})`);glow.addColorStop(1,'rgba(77,193,204,0)');
      ctx!.fillStyle=glow;ctx!.fillRect(250,65,240,230);
    }
    if(!reduced)handle=requestAnimationFrame(frame);
  }
  handle=requestAnimationFrame(frame);
  return ()=>cancelAnimationFrame(handle);
}
