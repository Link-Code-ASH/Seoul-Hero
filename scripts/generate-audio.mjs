// Original procedural score and effects. Run with node scripts/generate-audio.mjs.
// No external samples, runtime synthesizer, or third-party audio dependencies.
import { mkdirSync, writeFileSync } from 'node:fs';
const rate = 22050;
const tau = Math.PI * 2;
let seed = 7319;
const noise = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 2147483648 - 1; };
const hz = midi => 440 * 2 ** ((midi - 69) / 12);
function buffer(seconds) { return new Float64Array(Math.round(seconds * rate)); }
function voice(out, start, duration, frequency, gain, timbre = 'bell', loop = false) {
  const length = Math.round(duration * rate);
  for (let i = 0; i < length; i++) {
    const t = i / rate, progress = i / length;
    const attack = Math.min(1, t / (timbre === 'pad' ? 0.18 : 0.009));
    const release = Math.min(1, (duration - t) / (timbre === 'pad' ? 0.5 : 0.07));
    const envelope = attack * release * (timbre === 'pad' ? 1 : Math.exp(-progress * 3.2));
    let value;
    if (timbre === 'kick') value = Math.sin(tau * (45 * t + 9 * (1 - Math.exp(-t * 35)))) * Math.exp(-t * 17);
    else if (timbre === 'hat') value = noise() * Math.exp(-t * 75) * 0.45;
    else if (timbre === 'pad') value = (Math.sin(tau * frequency * t) + 0.35 * Math.sin(tau * frequency * 1.002 * t) + 0.16 * Math.sin(tau * frequency * 2 * t)) / 1.51;
    else value = Math.sin(tau * frequency * t) + 0.25 * Math.sin(tau * frequency * 2 * t) * Math.exp(-t * 9);
    const index = Math.round(start * rate) + i;
    if (loop || index < out.length) out[index % out.length] += value * gain * envelope;
  }
}
function write(name, data, ceiling = 0.7) {
  let peak = 0;
  for (const sample of data) peak = Math.max(peak, Math.abs(sample));
  const scale = peak > ceiling ? ceiling / peak : 1;
  const wav = Buffer.alloc(44 + data.length * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28); wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
  wav.write('data', 36); wav.writeUInt32LE(data.length * 2, 40);
  data.forEach((value, i) => wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, value * scale)) * 32767), 44 + i * 2));
  writeFileSync(`assets/audio/${name}.wav`, wav);
  console.log(`${name}: ${(data.length / rate).toFixed(2)}s, ${Math.round(wav.length / 1024)} KB`);
}
mkdirSync('assets/audio/sfx', { recursive: true }); mkdirSync('assets/audio/bgm', { recursive: true });
function score(name, bpm, roots, melody, intensity) {
  const beat = 60 / bpm, out = buffer(beat * 32);
  for (let bar = 0; bar < 8; bar++) {
    const root = roots[bar % roots.length], start = bar * 4 * beat;
    for (const interval of [0, 7, 10, 14]) voice(out, start, beat * 4 + .7, hz(root + 12 + interval), .065, 'pad', true);
    for (let step = 0; step < 8; step++) {
      voice(out, start + step * beat / 2, .65, hz(root + 24 + melody[(bar * 8 + step) % melody.length]), .105, 'bell', true);
      if (intensity > 0) voice(out, start + step * beat / 2, .06, 0, step % 2 ? .1 : .06, 'hat', true);
    }
    for (let step = 0; step < 4; step++) {
      voice(out, start + step * beat, beat * .85, hz(root - 12), .15, 'bass', true);
      if (intensity > 0) voice(out, start + step * beat, .19, 0, step % 2 === 0 ? .28 : .16, 'kick', true);
      if (intensity > 1 && step % 2) voice(out, start + step * beat, .1, 0, .3, 'hat', true);
    }
  }
  const dry = out.slice();
  for (const [seconds, gain] of [[beat * .75, .18], [beat * 1.5, .09]]) {
    const delay = Math.round(seconds * rate);
    for (let i = 0; i < out.length; i++) out[(i + delay) % out.length] += dry[i] * gain;
  }
  write(`bgm/${name}_01`, out, .58);
}
score('seoul_after_dusk', 80, [45, 41, 48, 43], [0, 7, 12, 14, 7, 3, 10, 7, 0, 7, 15, 14, 12, 7, 3, 7], 0);
score('gate_patrol', 112, [45, 45, 41, 43], [0, 7, 12, 7, 3, 7, 10, 14], 1);
score('the_gate_keeper', 128, [45, 44, 41, 43], [0, 7, 12, 7, 0, 6, 10, 6], 2);
