import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [ids,status,...notes]=process.argv.slice(2);
if(!ids||!['complete','needs-revision'].includes(status))throw new Error('Usage: review.mjs <id[,id...]> complete|needs-revision <actual visual review note>');
for(const id of ids.split(',')){
if(!/^[a-z]+-\d{3}$/.test(id))throw new Error('Invalid asset ID');
const recordPath=path.join(root,'records',id+'.json');const record=JSON.parse(await fs.readFile(recordPath,'utf8'));
if(status==='complete'&&record.files.some(file=>file.alphaChannel&&!file.hasTransparency)&&record.id.startsWith('effect-'))throw new Error('Opaque effect needs alpha repair');
record.status=status;record.review={...record.review,visualChecked:true,notes:notes.join(' '),reviewedAt:new Date().toISOString()};
if(record.sequence)record.sequence.aligned=status==='complete';
await fs.writeFile(recordPath+'.tmp',JSON.stringify(record,null,2)+'\n');await fs.rename(recordPath+'.tmp',recordPath);
const originalDirectory=path.dirname(record.files[0].path);
await fs.writeFile(path.join(root,originalDirectory,'provenance.json'),JSON.stringify(record,null,2)+'\n');
console.log(JSON.stringify({id,status,review:record.review}));
}
