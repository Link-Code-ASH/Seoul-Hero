// Scoped compiler diagnostics for the audio integration only; no build or whole-project check.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const files = [
  'src/data/audio.ts', 'src/data/sourcedAudio.ts', 'src/audio/AudioManager.ts', 'src/audio/AudioPolicy.ts',
  'src/core/AppController.ts', 'src/core/GameEvents.ts', 'src/core/Simulation.ts',
  'src/systems/CombatSystem.ts', 'src/systems/WeaponBehaviors.ts', 'src/systems/StructureSystem.ts',
  'src/systems/EnemySystem.ts', 'src/systems/EnemyBehaviors.ts', 'src/systems/HostileAttackSystem.ts',
];
const config = ts.readConfigFile(path.join(root, 'tsconfig.json'), ts.sys.readFile);
const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, root);
const program = ts.createProgram({
  rootNames: [...files.map(file => path.join(root, file)), ...parsed.fileNames.filter(file => file.endsWith('.d.ts'))],
  options: { ...parsed.options, noEmit: true, skipLibCheck: true },
});
const diagnostics = files.flatMap(file => {
  const source = program.getSourceFile(path.join(root, file));
  return [...program.getSyntacticDiagnostics(source), ...program.getSemanticDiagnostics(source)];
}).map(error => ({
  file: error.file ? path.relative(root, error.file.fileName).replaceAll('\\', '/') : null,
  line: error.file && error.start !== undefined ? error.file.getLineAndCharacterOfPosition(error.start).line + 1 : null,
  code: error.code, message: ts.flattenDiagnosticMessageText(error.messageText, '\n'),
}));
fs.writeFileSync(path.join(root, 'audio-library/reborn-01/qa/typescript-audio.json'), JSON.stringify({
  scope: 'changed audio and audio-event files only; no full typecheck/build/tests', files, diagnostics,
}, null, 2) + '\n');
console.log(JSON.stringify({ files: files.length, diagnostics }));
process.exitCode = diagnostics.length ? 1 : 0;
