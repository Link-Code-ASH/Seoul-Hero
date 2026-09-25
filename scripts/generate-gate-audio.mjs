import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const rate = 22050;
let seed = 0x51e0a7;
const random = () => ((seed = (1664525 * seed + 1013904223) >>> 0) / 0x100000000);
const save = (path, samples) => {
  let peak = 0;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  const scale = 0.72 / Math.max(0.72, peak);
  const pcm = Buffer.alloc(44 + samples.length * 2);
  pcm.write('RIFF', 0); pcm.writeUInt32LE(pcm.length - 8, 4); pcm.write('WAVEfmt ', 8);
  pcm.writeUInt32LE(16, 16); pcm.writeUInt16LE(1, 20); pcm.writeUInt16LE(1, 22);
  pcm.writeUInt32LE(rate, 24); pcm.writeUInt32LE(rate * 2, 28);
  pcm.writeUInt16LE(2, 32); pcm.writeUInt16LE(16, 34);
  pcm.write('data', 36); pcm.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i] * scale)) * 32767), 44 + i * 2);
  mkdirSync(join(process.cwd(), 'assets/audio', path.split('/')[0]), { recursive: true });
  writeFileSync(join(process.cwd(), 'assets/audio', path), pcm);
  process.stdout.write(`${path}: ${(samples.length / rate).toFixed(2)}s, peak ${(peak * scale).toFixed(2)}\n`);
};

// A restrained 108 BPM minor-key combat loop: low pulse, muted percussion,
// warm synth chords and a short motif. There are no bright continuous hats.
const beat = 60 / 108;
const bars = 16;
const length = Math.round(bars * 4 * beat * rate);
const music = new Float64Array(length);
const chords = [
  { bass: 73.42, notes: [146.83, 174.61, 220.00], arp: [293.66, 220.00, 349.23, 220.00] },
  { bass: 58.27, notes: [116.54, 146.83, 174.61], arp: [233.08, 174.61, 293.66, 174.61] },
  { bass: 49.00, notes: [98.00, 116.54, 146.83], arp: [196.00, 146.83, 233.08, 146.83] },
  { bass: 55.00, notes: [110.00, 138.59, 164.81], arp: [220.00, 164.81, 277.18, 164.81] },
];
const addTone = (at, duration, frequency, volume, kind = 'pluck') => {
  const from = Math.floor(at * rate), count = Math.min(Math.floor(duration * rate), length - from);
  for (let i = 0; i < count; i++) {
    const t = i / rate;
    const attack = Math.min(1, t / (kind === 'pad' ? 0.12 : 0.012));
    const release = Math.min(1, (duration - t) / (kind === 'pad' ? 0.36 : 0.09));
    const envelope = attack * Math.max(0, release) * (kind === 'pluck' ? Math.exp(-t * 3.4) : 1);
    const angle = 2 * Math.PI * frequency * t;
    const body = Math.sin(angle) + 0.21 * Math.sin(angle * 2) + 0.07 * Math.sin(angle * 3);
    music[from + i] += body * envelope * volume;
  }
};
const addKick = at => {
  const from = Math.floor(at * rate);
  for (let i = 0; i < rate * 0.28 && from + i < length; i++) {
    const t = i / rate;
    music[from + i] += Math.sin(2 * Math.PI * (54 * t + (72 / 38) * (1 - Math.exp(-t * 38))))
      * Math.exp(-t * 17) * 0.24 + (random() * 2 - 1) * Math.exp(-t * 80) * 0.014;
  }
};
const addSoftSnare = at => {
  const from = Math.floor(at * rate);
  let filtered = 0;
  for (let i = 0; i < rate * 0.18 && from + i < length; i++) {
    const t = i / rate;
    filtered += ((random() * 2 - 1) - filtered) * 0.13;
    music[from + i] += (filtered * 0.075 + Math.sin(2 * Math.PI * 168 * t) * 0.034)
      * Math.exp(-t * 23);
  }
};
for (let bar = 0; bar < bars; bar++) {
  const at = bar * 4 * beat;
  const chord = chords[bar % chords.length];
  addTone(at, 4 * beat, chord.bass, 0.12, 'pad');
  for (const note of chord.notes) addTone(at, 4 * beat, note, 0.055, 'pad');
  for (let half = 0; half < 8; half++) {
    if (half % 4 !== 3) addTone(at + half * beat / 2, beat * 0.44, chord.arp[half % 4], 0.043);
  }
  for (let pulse = 0; pulse < 4; pulse++) {
    if (pulse % 2 === 0) addKick(at + pulse * beat);
    else addSoftSnare(at + pulse * beat);
  }
  if (bar % 4 === 3) {
    addTone(at + 3 * beat, beat * 0.95, chord.arp[2], 0.047, 'pad');
    addTone(at + 3.5 * beat, beat * 0.48, chord.arp[0], 0.036, 'pad');
  }
}
// The last quarter-second meets the opening without a sharp loop seam.
const seam = Math.floor(rate * 0.25);
for (let i = 0; i < seam; i++) music[length - seam + i] = music[length - seam + i] * (1 - i / seam) + music[i] * (i / seam);
save('bgm/gate_hunt_01.wav', music);

// One quiet cluster of staggered metallic/glass contacts accompanies the
// whole wallet sweep; it never plays once per individual stone.
const wallet = new Float64Array(Math.round(rate * 1.02));
for (const [at, frequency, volume] of [
  [0.02, 587.33, 0.19], [0.15, 739.99, 0.16], [0.31, 659.25, 0.19],
  [0.46, 880.00, 0.14], [0.64, 783.99, 0.13],
]) {
  const from = Math.floor(at * rate);
  for (let i = 0; i < rate * 0.34 && from + i < wallet.length; i++) {
    const t = i / rate;
    const envelope = (1 - Math.exp(-t * 650)) * Math.exp(-t * 17);
    const angle = 2 * Math.PI * frequency * t;
    wallet[from + i] += envelope * volume * (Math.sin(angle) + 0.25 * Math.sin(angle * 1.48) + 0.1 * Math.sin(angle * 2.02));
  }
}
save('sfx/wallet_sweep_01.wav', wallet);
