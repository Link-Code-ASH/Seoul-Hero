import fs from 'node:fs/promises';
const root=new URL('../',import.meta.url);
const file=new URL('briefs/additional.json',root);
const entries=JSON.parse(await fs.readFile(file,'utf8'));
const changes={
 'facility-079':[
  'an open 2:1 transparent overlay of two low brass corner caps and sparse pearl streamers across the upper rear corners, no badges or labels',
  'a sparse 2:1 transparent overlay consisting ONLY of two small matte brass corner caps at the far upper left and upper right, with short pearl streamers and ivory fabric ribbons hanging beside each cap. The middle 65 percent and the entire lower 70 percent are completely empty transparent pixels. No badges, labels, room, architecture, wall, floor, stage, furniture, instruments, enclosing frame or central object'
 ],
 'facility-080':[
  'an open 2:1 transparent overlay of plum cracks running across the rear corners, two displaced teal pipe joints and sparse white sparks',
  'a sparse 2:1 transparent overlay consisting ONLY of two small isolated ivory broken corner fragments at the far upper left and upper right, purple mana fissures across each fragment, one disconnected teal elbow pipe joint at each corner, and a few white sparks. The middle 65 percent and the entire lower 70 percent remain completely empty transparent pixels. No rear wall connecting the corners, room, architecture, floor, platform, large frame, reactor, tanks or central machinery'
 ]
};
for(const [id,[before,after]] of Object.entries(changes)){
 const entry=entries.find(item=>item.id===id);
 entry.visualBrief=entry.visualBrief.replace(before,after);
 const promptFile=new URL(`prompts/${id}.txt`,root);
 const prompt=await fs.readFile(promptFile,'utf8');
 await fs.writeFile(promptFile,prompt.replace(before,after)+'\nSparse transparent corner overlay ONLY. Two small groups at the upper left and upper right; the center and lower canvas are entirely transparent. Never draw a room, rear wall, architecture, floor, booth, full-width support frame or central object.\n','utf8');
}
await fs.writeFile(file,JSON.stringify(entries,null,2)+'\n','utf8');
console.log('Revised facility-079 and facility-080 next-request overlays; original v01 and provenance preserved.');
