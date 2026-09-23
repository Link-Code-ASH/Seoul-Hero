import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const rate = 48_000;
const output = resolve('assets/audio/sfx');
const clamp = value => Math.max(-1, Math.min(1, value));
let noiseSeed = 0x51a7c3;
const noise = () => {
  noiseSeed = (noiseSeed * 1664525 + 1013904223) >>> 0;
  return noiseSeed / 0xffffffff * 2 - 1;
};

function writeStereo24(path, seconds, render) {
  const frames = Math.ceil(seconds * rate);
  const channels = [new Float64Array(frames), new Float64Array(frames)];
  for (let i = 0; i < frames; i++) render(i / rate, channels[0], channels[1], i);
  let peak = 0;
  for (const channel of channels) for (const value of channel) peak = Math.max(peak, Math.abs(value));
  const gain = peak > 0 ? 0.78 / peak : 1;
  const dataSize = frames * 2 * 3;
  const buffer = Buffer.alloc(44 + dataSize);
  buffer.write('RIFF', 0); buffer.writeUInt32LE(36 + dataSize, 4); buffer.write('WAVE', 8);
  buffer.write('fmt ', 12); buffer.writeUInt32LE(16, 16); buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(2, 22); buffer.writeUInt32LE(rate, 24); buffer.writeUInt32LE(rate * 6, 28);
  buffer.writeUInt16LE(6, 32); buffer.writeUInt16LE(24, 34); buffer.write('data', 36); buffer.writeUInt32LE(dataSize, 40);
  let offset = 44;
  for (let i = 0; i < frames; i++) for (let channel = 0; channel < 2; channel++) {
    let sample = Math.round(clamp(channels[channel][i] * gain) * 0x7fffff);
    if (sample < 0) sample += 0x1000000;
    buffer[offset++] = sample & 255; buffer[offset++] = sample >> 8 & 255; buffer[offset++] = sample >> 16 & 255;
  }
  mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, buffer);
}

const latchClick = (t, start, strength = 1) => {
  const x = t - start; if (x < 0 || x > .12) return 0;
  const contact = Math.tanh(noise() * 3.2) * Math.exp(-155 * x);
  const latch = (Math.sin(2 * Math.PI * 1180 * x + .25) + .52 * Math.sin(2 * Math.PI * 1870 * x + 1.1) + .2 * Math.sin(2 * Math.PI * 2860 * x)) * Math.exp(-72 * x);
  const shell = (Math.sin(2 * Math.PI * 520 * x) + .28 * Math.sin(2 * Math.PI * 790 * x + .6)) * Math.exp(-48 * x);
  return strength * (.42 * contact + .38 * latch + .2 * shell);
};

writeStereo24(resolve(output, 'ui_supply_latch_01.wav'), .34, (t, left, right, i) => {
  const value = latchClick(t, .026, .72) + latchClick(t, .104, 1);
  left[i] = value; right[i] = value * .98 + latchClick(t, .107, .07);
});

const note = (t, start, frequency, duration, gain) => {
  const x = t - start; if (x < 0 || x > duration) return 0;
  const attack = Math.min(1, x / .024); const release = Math.pow(Math.max(0, 1 - x / duration), 1.7);
  const phase = 2 * Math.PI * frequency * x;
  return gain * attack * release * (Math.sin(phase) + .22 * Math.sin(2 * phase) + .08 * Math.sin(3 * phase));
};

writeStereo24(resolve(output, 'ui_supply_fanfare_01.wav'), 1.55, (t, left, right, i) => {
  const chord = note(t, .02, 261.63, .78, .48) + note(t, .02, 329.63, .78, .34) + note(t, .02, 392, .78, .28)
    + note(t, .43, 392, .9, .4) + note(t, .43, 493.88, .9, .3) + note(t, .43, 587.33, .9, .24);
  const crown = note(t, .78, 523.25, .67, .34) + note(t, .78, 659.25, .67, .2);
  const body = t < 1.05 ? Math.sin(2 * Math.PI * 98 * t) * Math.exp(-2.9 * t) * .13 : 0;
  left[i] = chord + crown + body; right[i] = chord * .96 + note(t, .045, 392, .8, .08) + crown * 1.03 + body;
});
