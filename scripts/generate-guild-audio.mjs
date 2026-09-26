import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const rate = 22050;
const bpm = 124;
const beat = 60 / bpm;
const bars = 16;
const length = Math.round(bars * 4 * beat * rate);
const samples = new Float64Array(length);
let seed = 0x6a11d;
const noise = () => ((seed = (1664525 * seed + 1013904223) >>> 0) / 0x100000000) * 2 - 1;
const chords = [
  { bass: 130.81, notes: [261.63, 329.63, 392.00], melody: [523.25, 659.25, 783.99, 659.25] },
  { bass: 110.00, notes: [220.00, 261.63, 329.63], melody: [440.00, 523.25, 659.25, 523.25] },
  { bass: 87.31, notes: [174.61, 220.00, 261.63], melody: [523.25, 440.00, 698.46, 523.25] },
  { bass: 98.00, notes: [196.00, 246.94, 293.66], melody: [493.88, 587.33, 783.99, 587.33] },
];

function tone(at, duration, frequency, volume, voice) {
  const start = Math.floor(at * rate);
  const count = Math.min(Math.floor(duration * rate), length - start);
  for (let i = 0; i < count; i++) {
    const t = i / rate;
    const attack = Math.min(1, t / (voice === 'pad' ? 0.045 : 0.008));
    const release = Math.min(1, (duration - t) / (voice === 'pad' ? 0.12 : 0.055));
    const angle = 2 * Math.PI * frequency * t;
    let wave;
    if (voice === 'bass') wave = Math.sin(angle) + 0.19 * Math.sin(angle * 2);
    else if (voice === 'bell') wave = Math.sin(angle) + 0.2 * Math.sin(angle * 2.01) + 0.09 * Math.sin(angle * 3.98);
    else wave = Math.sin(angle) + 0.13 * Math.sin(angle * 2);
    const decay = voice === 'bell' ? Math.exp(-t * 5.8) : voice === 'bass' ? Math.exp(-t * 2.7) : 1;
    samples[start + i] += wave * attack * Math.max(0, release) * decay * volume;
  }
}

function kick(at) {
  const start = Math.floor(at * rate);
  for (let i = 0; i < rate * 0.18 && start + i < length; i++) {
    const t = i / rate;
    samples[start + i] += Math.sin(2 * Math.PI * (62 * t + 1.3 * (1 - Math.exp(-t * 34)))) * Math.exp(-t * 25) * 0.18;
  }
}

function clap(at) {
  const start = Math.floor(at * rate);
  let filtered = 0;
  for (let i = 0; i < rate * 0.11 && start + i < length; i++) {
    const t = i / rate;
    filtered += (noise() - filtered) * 0.26;
    samples[start + i] += filtered * Math.exp(-t * 31) * 0.11;
  }
}

function tick(at, volume) {
  const start = Math.floor(at * rate);
  for (let i = 0; i < rate * 0.045 && start + i < length; i++) {
    const t = i / rate;
    samples[start + i] += noise() * Math.exp(-t * 105) * volume;
  }
}

for (let bar = 0; bar < bars; bar++) {
  const at = bar * 4 * beat;
  const chord = chords[bar % chords.length];
  for (const note of chord.notes) tone(at, 4 * beat, note, 0.025, 'pad');
  for (let step = 0; step < 8; step++) {
    const time = at + step * beat / 2;
    tone(time, beat * 0.39, chord.bass * (step === 7 ? 2 : 1), 0.13, 'bass');
    tick(time, step % 2 === 0 ? 0.017 : 0.01);
  }
  for (let pulse = 0; pulse < 4; pulse++) {
    if (pulse % 2 === 0) kick(at + pulse * beat);
    else clap(at + pulse * beat);
    tone(at + pulse * beat + beat * 0.48, beat * 0.42, chord.melody[pulse], 0.073, 'bell');
  }
  if (bar % 4 === 3) tone(at + 3.5 * beat, beat * 0.45, chord.melody[0] * 2, 0.028, 'bell');
}

const seam = Math.floor(rate * 0.02);
for (let i = 0; i < seam; i++) {
  samples[i] *= i / seam;
  samples[length - seam + i] *= (seam - i) / seam;
}
let peak = 0;
for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
const scale = 0.65 / Math.max(peak, 0.001);
const wav = Buffer.alloc(44 + length * 2);
wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28);
wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
wav.write('data', 36); wav.writeUInt32LE(length * 2, 40);
for (let i = 0; i < length; i++) wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i] * scale)) * 32767), 44 + i * 2);
const directory = join(process.cwd(), 'assets/audio/bgm');
mkdirSync(directory, { recursive: true });
writeFileSync(join(directory, 'guild_daylight_01.wav'), wav);
process.stdout.write(`guild_daylight_01.wav: ${(length / rate).toFixed(2)}s, peak ${(peak * scale).toFixed(2)}\n`);
