import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// Run after generate-clear-sfx.mjs. The dry synthetic transient is only one
// layer; short CC0 foley recordings supply the irregular, physical texture.
const rate = 48_000;
const clearDir = join(process.cwd(), 'assets/audio/sfx/clear');
const sourceDir = join(process.cwd(), 'scripts/audio-sources/wet-foley');

function readWav(path) {
  const bytes = readFileSync(path);
  if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WAVE') {
    throw new Error(`Not a WAV file: ${path}`);
  }
  let format;
  let data;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const id = bytes.toString('ascii', offset, offset + 4);
    const size = bytes.readUInt32LE(offset + 4);
    if (id === 'fmt ') format = {
      type: bytes.readUInt16LE(offset + 8),
      channels: bytes.readUInt16LE(offset + 10),
      sampleRate: bytes.readUInt32LE(offset + 12),
      bits: bytes.readUInt16LE(offset + 22),
    };
    if (id === 'data') data = { offset: offset + 8, size };
    offset += 8 + size + size % 2;
  }
  if (!format || !data || format.type !== 1 || format.bits !== 16) {
    throw new Error(`Expected 16-bit PCM WAV: ${path}`);
  }
  const frames = Math.floor(data.size / (2 * format.channels));
  const samples = new Float32Array(frames);
  let peak = 0;
  for (let frame = 0; frame < frames; frame++) {
    let sum = 0;
    for (let channel = 0; channel < format.channels; channel++) {
      sum += bytes.readInt16LE(data.offset + (frame * format.channels + channel) * 2) / 32768;
    }
    samples[frame] = sum / format.channels;
    peak = Math.max(peak, Math.abs(samples[frame]));
  }
  return { samples, rate: format.sampleRate, peak: peak || 1 };
}

const sourceCache = new Map();
function source(name) {
  if (!sourceCache.has(name)) sourceCache.set(name, readWav(join(sourceDir, name)));
  return sourceCache.get(name);
}

function addLayer(output, clip, { from = 0, at = 0, duration, gain, speed = 1, lowpass = 3600 }) {
  const first = Math.round(at * rate);
  const count = Math.min(output.length - first, Math.round(duration * rate));
  const alpha = 1 - Math.exp(-2 * Math.PI * lowpass / rate);
  let filtered = 0;
  for (let i = 0; i < count; i++) {
    const position = (from + i / rate * speed) * clip.rate;
    const index = Math.floor(position);
    if (index + 1 >= clip.samples.length) break;
    const raw = clip.samples[index] * (1 - position + index)
      + clip.samples[index + 1] * (position - index);
    filtered += alpha * (raw / clip.peak - filtered);
    const fadeIn = Math.min(1, i / (rate * .0015));
    const fadeOut = Math.min(1, (count - i) / (rate * .009));
    output[first + i] += filtered * gain * fadeIn * fadeOut;
  }
}

function writeWav(path, samples, headroom) {
  let peak = 0;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  const scale = headroom / (peak || 1);
  const bytes = Buffer.alloc(44 + samples.length * 2);
  bytes.write('RIFF', 0); bytes.writeUInt32LE(bytes.length - 8, 4);
  bytes.write('WAVEfmt ', 8); bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(rate, 24); bytes.writeUInt32LE(rate * 2, 28);
  bytes.writeUInt16LE(2, 32); bytes.writeUInt16LE(16, 34);
  bytes.write('data', 36); bytes.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) {
    bytes.writeInt16LE(Math.round(Math.tanh(samples[i] * 1.18) * scale * 32767), 44 + i * 2);
  }
  writeFileSync(path, bytes);
}

const recipes = [
  { names: ['mana_bolt_01', 'mana_bolt_02', 'mana_bolt_03'], length: .17, synth: .36, layers: [
    ['snd_bulletcrackle.wav', { from: 0, at: 0, duration: .075, gain: .29, lowpass: 3500 }],
    ['snd_yoghurtblast.wav', { from: .015, at: .012, duration: .105, gain: .23, lowpass: 2700 }],
  ] },
  { names: ['piercing_01', 'piercing_02'], length: .18, synth: .35, layers: [
    ['snd_bulletcrackle.wav', { from: .012, at: 0, duration: .095, gain: .37, lowpass: 4000 }],
    ['snd_splathit.wav', { from: 0, at: .018, duration: .09, gain: .14, lowpass: 2700 }],
  ] },
  { names: ['turret_soft_01', 'turret_soft_02'], length: .12, synth: .34, layers: [
    ['snd_bulletcrackle.wav', { from: 0, at: 0, duration: .07, gain: .25, lowpass: 3200 }],
    ['snd_yoghurtblast.wav', { from: 0, at: .009, duration: .075, gain: .14, lowpass: 2300 }],
  ] },
  { names: ['hit_light_01', 'hit_light_02', 'hit_light_03'], length: .15, synth: .28, layers: [
    ['snd_splathit.wav', { from: 0, at: 0, duration: .11, gain: .49, lowpass: 3400 }],
    ['snd_splat.wav', { from: .015, at: .013, duration: .095, gain: .2, lowpass: 2300 }],
  ] },
  { names: ['critical_01', 'critical_02'], length: .19, synth: .3, layers: [
    ['snd_splathit.wav', { from: 0, at: 0, duration: .13, gain: .54, lowpass: 3600 }],
    ['snd_bulletcrackle.wav', { from: .01, at: .015, duration: .08, gain: .2, lowpass: 3200 }],
  ] },
  { names: ['player_hit_01', 'player_hit_02'], length: .16, synth: .28, layers: [
    ['snd_splathit.wav', { from: 0, at: 0, duration: .11, gain: .38, lowpass: 2800 }],
    ['snd_splurt.wav', { from: .08, at: .022, duration: .105, gain: .25, lowpass: 2100 }],
  ] },
  { names: ['enemy_death_01', 'enemy_death_02', 'enemy_death_03'], length: .2, synth: .22, layers: [
    ['snd_splurt.wav', { from: .08, at: 0, duration: .15, gain: .39, lowpass: 2700 }],
    ['snd_splat.wav', { from: 0, at: .02, duration: .12, gain: .25, lowpass: 2500 }],
  ] },
  { names: ['explosion_arcane_01', 'explosion_arcane_02', 'explosion_mine_01', 'explosion_mine_02'], length: .34, synth: .24, layers: [
    ['dull_explosion.wav', { from: 0, at: 0, duration: .25, gain: .49, lowpass: 4200 }],
    ['snd_splurt.wav', { from: .08, at: .024, duration: .17, gain: .29, lowpass: 2600 }],
  ] },
];

let count = 0;
for (const recipe of recipes) {
  recipe.names.forEach((name, variant) => {
    const path = join(clearDir, `${name}.wav`);
    const dry = readWav(path);
    const output = new Float32Array(Math.round(recipe.length * rate));
    addLayer(output, dry, { duration: Math.min(recipe.length, dry.samples.length / dry.rate), gain: recipe.synth });
    for (const [file, settings] of recipe.layers) {
      addLayer(output, source(file), { ...settings, speed: settings.speed ?? [1, 1.035, .97][variant % 3] });
    }
    writeWav(path, output, name.startsWith('explosion') ? .66 : .58);
    count++;
  });
}
process.stdout.write(`${count} layered combat SFX files generated\n`);
