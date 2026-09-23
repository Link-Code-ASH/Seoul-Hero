import {describe,it,expect} from 'vitest';
import {TouchInput} from './TouchInput';
import {InputManager} from './InputManager';
class Surface extends EventTarget {
 style={setProperty:()=>{}};
 setPointerCapture():void{}
 getBoundingClientRect(){return {left:0,top:0,width:100,height:100};}
 send(type:string,id:number,x=50,y=50){this.dispatchEvent(Object.assign(new Event(type),{pointerId:id,clientX:x,clientY:y}));}
}
describe('touch input contract',()=>{
 it('normalizes movement and clears on release/cancel/capture loss',()=>{
  const el=new Surface(),touch=new TouchInput(el as unknown as HTMLElement),input=new InputManager([touch]);
  el.send('pointerdown',1,100,100);expect(Math.hypot(input.read().x,input.read().y)).toBeCloseTo(1);
  el.send('pointermove',2,0,0);expect(input.read().x).toBeGreaterThan(0);
  el.send('pointercancel',1);expect(input.read()).toEqual({x:0,y:0});
  el.send('pointerdown',2,90,50);el.send('lostpointercapture',2);expect(input.read()).toEqual({x:0,y:0});
  el.send('pointerdown',3,90,50);el.send('pointerup',3);expect(input.read()).toEqual({x:0,y:0});
  input.destroy();el.send('pointerdown',4,90,50);expect(input.read()).toEqual({x:0,y:0});
 });
 it('does not retain direction when the game changes phase',()=>{
  const el=new Surface(),touch=new TouchInput(el as unknown as HTMLElement),input=new InputManager([touch]);
  el.send('pointerdown',1,100,50);input.clear();el.send('pointermove',1,100,50);expect(input.read()).toEqual({x:0,y:0});input.destroy();
 });
});
