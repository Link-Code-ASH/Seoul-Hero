// Clear, pleasant modern-fantasy SFX. Original procedural audio.
// 48 kHz mono, 24-bit PCM. Definite low/mid attack, rounded body, short tail.
import { mkdirSync, writeFileSync } from 'node:fs';
const rate=48000,tau=Math.PI*2,outDir='assets/audio/sfx';mkdirSync(outDir,{recursive:true});
let seed=0x5e0a1;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296)*2-1;
const audio=s=>new Float64Array(Math.ceil(s*rate));const add=(o,i,v)=>{if(i>=0&&i<o.length)o[i]+=v;};
function tone(o,start,dur,from,to,gain,attack=.0025,decay=10,partials=[1]){let phase=0;const off=Math.floor(start*rate),n=Math.floor(dur*rate);for(let i=0;i<n;i++){const t=i/rate,p=i/Math.max(1,n-1),f=from*(to/from)**p;phase+=tau*f/rate;const env=Math.min(1,t/attack)*Math.exp(-decay*t);let v=0;for(let h=0;h<partials.length;h++)v+=Math.sin(phase*(h+1))*partials[h];add(o,off+i,v*gain*env);}}
function noise(o,start,dur,gain,cutoff=1800,attack=.0015,decay=18){let low=0;const a=1-Math.exp(-tau*cutoff/rate),off=Math.floor(start*rate),n=Math.floor(dur*rate);for(let i=0;i<n;i++){const t=i/rate;low+=(random()-low)*a;add(o,off+i,low*gain*Math.min(1,t/attack)*Math.exp(-decay*t));}}
function bandNoise(o,start,dur,gain,lowCut=180,highCut=2200,attack=.002,decay=14){let hi=0,lo=0;const ha=1-Math.exp(-tau*highCut/rate),la=1-Math.exp(-tau*lowCut/rate),off=Math.floor(start*rate),n=Math.floor(dur*rate);for(let i=0;i<n;i++){const t=i/rate,s=random();hi+=(s-hi)*ha;lo+=(s-lo)*la;add(o,off+i,(hi-lo)*gain*Math.min(1,t/attack)*Math.exp(-decay*t));}}
function knock(o,at,pitch=1,weight=1){tone(o,at,.22,250*pitch,112*pitch,.48*weight,.0012,16,[1,.22,.07]);noise(o,at,.055,.24*weight,2100,.0008,48);tone(o,at+.008,.18,470*pitch,250*pitch,.12*weight,.0018,19,[1,.12]);}
function pulse(o,at,pitch=1,weight=1){tone(o,at,.3,180*pitch,105*pitch,.4*weight,.003,10,[1,.2,.05]);tone(o,at+.012,.2,390*pitch,245*pitch,.11*weight,.0025,15,[1]);}
function chime(o,at,f,w=1){tone(o,at,.42,f,f*.985,.28*w,.002,9.5,[1,.12,.035]);tone(o,at+.006,.25,f*.5,f*.49,.11*w,.002,13,[1]);}
function whoosh(o,at,dur,w=1,pitch=1){bandNoise(o,at,dur,.32*w,180*pitch,1750*pitch,.018,9);tone(o,at+dur*.28,dur*.55,330*pitch,145*pitch,.13*w,.004,13,[1,.1]);}
function blast(o,at,pitch=1,w=1){tone(o,at,.58,105*pitch,48*pitch,.58*w,.0015,7.5,[1,.3,.09]);tone(o,at+.012,.36,205*pitch,82*pitch,.25*w,.0015,11,[1,.18]);bandNoise(o,at,.42,.38*w,55,1250,.0012,9.5);noise(o,at+.12,.4,.12*w,750,.015,7);}
function delay(o,s,g){const dry=o.slice(),n=Math.floor(s*rate);for(let i=n;i<o.length;i++)o[i]+=dry[i-n]*g;}
function write(name,o,ceiling=.52,drive=1.08){let mean=0;for(const s of o)mean+=s;mean/=Math.max(1,o.length);const div=Math.tanh(drive);for(let i=0;i<o.length;i++)o[i]=Math.tanh((o[i]-mean)*drive)/div;const fi=Math.min(32,o.length),fo=Math.min(720,o.length);for(let i=0;i<fi;i++)o[i]*=i/fi;for(let i=0;i<fo;i++)o[o.length-1-i]*=i/fo;let peak=0;for(const s of o)peak=Math.max(peak,Math.abs(s));const scale=peak?ceiling/peak:1,bytes=3,data=o.length*bytes,wav=Buffer.alloc(44+data);wav.write('RIFF',0);wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(rate,24);wav.writeUInt32LE(rate*bytes,28);wav.writeUInt16LE(bytes,32);wav.writeUInt16LE(24,34);wav.write('data',36);wav.writeUInt32LE(data,40);for(let i=0;i<o.length;i++){const d=(random()+random())/16777216;wav.writeIntLE(Math.round(Math.max(-1,Math.min(1,o[i]*scale+d))*8388607),44+i*bytes,bytes);}writeFileSync(`${outDir}/${name}.wav`,wav);}
const build=(name,seconds,make,ceiling=.52,drive=1.08)=>{const o=audio(seconds);make(o);write(name,o,ceiling,drive);};

for(let v=0;v<3;v++)build(`mana_bolt_0${v+1}`,.34,o=>{knock(o,0,1+v*.025,.68);tone(o,.012,.28,620+v*18,245,.2,.002,14,[1,.09]);},.48);
for(let v=0;v<3;v++)build(`hit_light_0${v+1}`,.28,o=>{knock(o,0,.9+v*.025,.9);pulse(o,.018,.78+v*.02,.45);},.5,1.12);
for(let v=0;v<2;v++)build(`critical_0${v+1}`,.46,o=>{knock(o,0,.76+v*.025,1.1);pulse(o,.018,.63,.9);chime(o,.025,520+v*18,.48);},.54,1.12);
for(let v=0;v<3;v++)build(`enemy_death_0${v+1}`,.48,o=>{pulse(o,0,.65+v*.025,1.08);knock(o,.006,.7,.55);noise(o,.07,.34,.18,900,.01,9);},.5);
for(let v=0;v<2;v++)build(`player_hit_0${v+1}`,.44,o=>{knock(o,0,.66+v*.025,1.15);tone(o,.004,.38,145,67,.36,.0015,9,[1,.25]);},.54,1.14);
for(let v=0;v<2;v++)build(`slash_0${v+1}`,.34,o=>{whoosh(o,0,.28,.85,.9+v*.025);knock(o,.075,.9,.48);},.49);
for(let v=0;v<2;v++)build(`piercing_0${v+1}`,.3,o=>{knock(o,0,1.08+v*.025,.58);tone(o,0,.27,560,185,.22,.0012,15,[1,.1]);},.47);
for(let v=0;v<2;v++)build(`orbit_blade_0${v+1}`,.27,o=>{whoosh(o,0,.22,.46,.82);knock(o,.045,.82+v*.02,.3);},.42);
for(let v=0;v<2;v++)build(`chain_discharge_0${v+1}`,.48,o=>{[0,.072,.145].forEach((at,i)=>{knock(o,at,.88+i*.07+v*.02,.45);tone(o,at,.2,430+i*45,230,.11,.0015,17,[1]);});},.48);
for(const [prefix,pitch] of [['explosion_arcane',1],['explosion_mine',.82]])for(let v=0;v<2;v++)build(`${prefix}_0${v+1}`,.68,o=>{blast(o,0,pitch+v*.018,1);knock(o,.006,pitch*.72,.52);},.55,1.14);
for(let v=0;v<2;v++)build(`turret_soft_0${v+1}`,.22,o=>{knock(o,0,1.02+v*.025,.42);tone(o,.006,.18,390,210,.08,.0015,19,[1]);},.4);
build('mine_arm_01',.36,o=>{knock(o,0,.72,.5);chime(o,.07,430,.3);},.44);
build('field_pulse_01',.56,o=>{pulse(o,0,.66,.8);tone(o,.025,.48,185,245,.2,.01,7,[1,.1]);},.45);

build('level_up_arcade_01',.78,o=>{[0,.115,.245].forEach((at,i)=>chime(o,at,[430,540,675][i],.9));pulse(o,0,.9,.35);},.5);
build('boss_warning_arcade_01',1.25,o=>{for(const at of [0,.46]){blast(o,at,.62,.56);tone(o,at,.43,118,78,.3,.002,8,[1,.2]);}},.54);
build('elite_warning_01',.66,o=>{knock(o,0,.72,.9);chime(o,.14,410,.5);pulse(o,.015,.75,.4);},.49);
build('wave_start_01',.58,o=>{[0,.105,.215].forEach((at,i)=>chime(o,at,[360,455,565][i],.65));knock(o,0,.9,.3);},.47);
build('wave_clear_01',.64,o=>{[0,.11,.235].forEach((at,i)=>chime(o,at,[410,515,650][i],.72));pulse(o,0,.92,.28);},.48);

// One tuned ceramic-glass tap. Fixed 660 Hz with octave harmonics; no sweep or variant pitch.
build('ui_click_01',.14,o=>{tone(o,0,.13,660,660,.25,.0006,27,[1,.18,.045]);tone(o,.001,.09,1320,1320,.065,.0005,36,[1]);noise(o,0,.012,.035,2200,.0003,110);},.36,1.01);
build('ui_purchase_01',.42,o=>{knock(o,0,.95,.42);chime(o,.055,520,.55);chime(o,.14,650,.48);},.47);
build('ui_reroll_01',.36,o=>{whoosh(o,0,.22,.32,1);knock(o,.08,1.08,.38);chime(o,.1,540,.32);},.44);
build('ui_lock_01',.24,o=>{knock(o,0,.82,.62);chime(o,.055,445,.32);},.46);
build('ui_reward_01',.56,o=>{knock(o,0,1,.34);[0,.105,.22].forEach((at,i)=>chime(o,at,[430,540,680][i],.68));},.48);
build('ui_branch_01',.66,o=>{pulse(o,0,.82,.42);chime(o,.08,465,.55);chime(o,.25,620,.68);},.49);
build('stage_clear_01',1.25,o=>{pulse(o,0,.82,.55);[0,.13,.29,.48].forEach((at,i)=>chime(o,at,[360,455,565,715][i],.82));delay(o,.105,.075);},.52);
build('game_over_01',1.12,o=>{knock(o,0,.68,.54);[0,.22,.47].forEach((at,i)=>chime(o,at,[430,350,275][i],.58));noise(o,.22,.65,.07,700,.015,6);},.48);
console.log('Clear warm SFX generated: 48 kHz / 24-bit, strong low-mid core, restrained highs, short tails.');
