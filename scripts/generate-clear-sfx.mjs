import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// UI, projectile release/impact, and other combat sounds have separate layers.
// Short filtered fracture bursts keep combat textured without a piercing hiss tail.
const rate = 48_000;
const directory = join(process.cwd(), 'assets/audio/sfx/clear');
mkdirSync(directory, { recursive: true });

const groups = {
  click: ['ui_click_01', 'ui_lock_01', 'ui_supply_latch_01'],
  reward: ['ui_purchase_01', 'ui_reward_01', 'ui_branch_01', 'ui_supply_fanfare_01', 'wave_clear_01', 'stage_clear_01'],
  shuffle: ['ui_reroll_01', 'wave_start_01', 'wallet_sweep_01'],
  warning: ['elite_warning_01', 'boss_warning_arcade_01', 'game_over_01'],
  blade: ['slash_01', 'slash_02', 'orbit_blade_01', 'orbit_blade_02'],
  magic: ['chain_discharge_01', 'chain_discharge_02', 'field_pulse_01'],
  manaShot: ['mana_bolt_01', 'mana_bolt_02', 'mana_bolt_03'],
  rifleShot: ['piercing_01', 'piercing_02'],
  turretShot: ['turret_soft_01', 'turret_soft_02'],
  explosion: ['explosion_arcane_01', 'explosion_arcane_02', 'explosion_mine_01', 'explosion_mine_02'],
  hit: ['hit_light_01', 'hit_light_02', 'hit_light_03'],
  critical: ['critical_01', 'critical_02'],
  playerHit: ['player_hit_01', 'player_hit_02'],
  mineArm: ['mine_arm_01'],
  death: ['enemy_death_01', 'enemy_death_02', 'enemy_death_03'],
  collect: ['magic_stone_chime_01', 'magic_stone_chime_02', 'magic_stone_chime_03'],
};

const profiles = {
  click:   { length: .083, root: 980,  decay: 43, body: 500, bodyGain: .18 },
  reward:  { length: .29,  root: 800,  decay: 24, body: 400, bodyGain: .12, notes: [[0, 1], [.08, 1.18], [.16, 1.32]] },
  shuffle: { length: .17,  root: 930,  decay: 34, body: 470, bodyGain: .13, notes: [[0, 1], [.055, 1.16]] },
  warning:   { combat: true, length: .25, root: 480, decay: 21, body: 190, bodyGain: .38, notes: [[0, 1], [.105, .82]] },
  blade:     { combat: true, length: .14, root: 500, decay: 32, body: 220, bodyGain: .56 },
  magic:     { combat: true, length: .17, root: 410, decay: 27, body: 185, bodyGain: .58 },
  manaShot:   { combat: true, projectile: true, length: .085, body: 205, root: 420, airGain: .035 },
  rifleShot:  { combat: true, projectile: true, length: .095, body: 195, root: 380, airGain: .03 },
  turretShot: { combat: true, projectile: true, length: .075, body: 215, root: 440, airGain: .025 },
  explosion: { combat: true, length: .27, root: 280, decay: 17, body: 145, bodyGain: .82, crack: 750 },
  hit:       { combat: true, projectileImpact: true, length: .085, root: 330, body: 205 },
  critical:  { combat: true, length: .18, root: 370, decay: 27, body: 160, bodyGain: .73, crack: 780 },
  playerHit: { combat: true, length: .16, root: 340, decay: 27, body: 150, bodyGain: .74, crack: 670 },
  mineArm:   { combat: true, length: .11, root: 420, decay: 42, body: 220, bodyGain: .28 },
  death:     { combat: true, length: .16, root: 350, decay: 29, body: 155, bodyGain: .61 },
  collect: { length: .13,  root: 1080, decay: 38, body: 540, bodyGain: .1 },
};

function render(name, kind, variant) {
  const profile = profiles[kind];
  const length = Math.ceil(profile.length * rate);
  const samples = new Float64Array(length);
  const pitch = kind === 'click' ? 1 : [1, 1.035, .965][variant % 3];
  function tap(at, frequency, gain, decay, duration = .16, harmonics = .035, attackTime = .0022) {
    const start = Math.round(at * rate);
    const end = Math.min(length, start + Math.round(duration * rate));
    for (let i = start; i < end; i++) {
      const time = (i - start) / rate;
      const remaining = (end - i) / rate;
      const attack = Math.min(1, time / attackTime);
      const release = Math.min(1, remaining / .01);
      const envelope = attack * release * Math.exp(-decay * time);
      const phase = 2 * Math.PI * frequency * time;
      samples[i] += gain * envelope * (Math.sin(phase)
        + harmonics * Math.sin(phase * 2)
        + (profile.combat ? harmonics * .35 * Math.sin(phase * 3) : 0));
    }
  }

  function strike(at, frequency, gain, decay, duration, drop = .42) {
    const start = Math.round(at * rate);
    const end = Math.min(length, start + Math.round(duration * rate));
    for (let i = start; i < end; i++) {
      const time = (i - start) / rate;
      const remaining = (end - i) / rate;
      const envelope = Math.min(1, time / .00055)
        * Math.min(1, remaining / .009) * Math.exp(-decay * time);
      // Fast downward pitch motion reads as a solid impact, not a sustained beep.
      const phase = 2 * Math.PI * frequency
        * (time + drop * .013 * (1 - Math.exp(-time / .013)));
      const tone = Math.sin(phase) + .25 * Math.sin(phase * 2 + .4)
        + .1 * Math.sin(phase * 3 + 1.1);
      samples[i] += gain * envelope * Math.tanh(tone * 1.8) / Math.tanh(1.8);
    }
  }

  function dryKnock(at, frequency, gain, duration, decay) {
    const start = Math.round(at * rate);
    const end = Math.min(length, start + Math.round(duration * rate));
    for (let i = start; i < end; i++) {
      const time = (i - start) / rate;
      const remaining = (end - i) / rate;
      const envelope = Math.min(1, time / .0004)
        * Math.min(1, remaining / .004) * Math.exp(-decay * time);
      const phase = 2 * Math.PI * frequency * time;
      const tone = Math.sin(phase) + .16 * Math.sin(phase * 2 + .7);
      samples[i] += gain * envelope * Math.tanh(tone * 1.35) / Math.tanh(1.35);
    }
  }

  function softAir(at, duration, gain, lowHz, highHz, transient = false) {
    const start = Math.round(at * rate);
    const end = Math.min(length, start + Math.round(duration * rate));
    const highAlpha = 1 - Math.exp(-2 * Math.PI * highHz / rate);
    const lowAlpha = 1 - Math.exp(-2 * Math.PI * lowHz / rate);
    let seed = (0x6d2b79f5 + variant * 917 + start) >>> 0;
    let high = 0;
    let low = 0;
    for (let i = start; i < end; i++) {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      const noise = seed / 0xffffffff * 2 - 1;
      high += highAlpha * (noise - high);
      low += lowAlpha * (noise - low);
      const progress = (i - start) / Math.max(1, end - start - 1);
      const shape = transient
        ? Math.min(1, progress * 8) * Math.exp(-4 * progress)
        : Math.sin(Math.PI * progress) ** 2;
      samples[i] += (high - low) * gain * shape;
    }
  }

  if (profile.projectile) {
    // A compact midrange snap leads; a brief rough burst replaces the arcade tone.
    dryKnock(0, profile.root * pitch, .63, .038, 74);
    dryKnock(0, profile.body * pitch, .4, .052, 61);
    softAir(.001, .014, .25, 480, 3000, true);
    softAir(.012, .02, profile.airGain * 2, 360, 2000);
  } else if (profile.projectileImpact) {
    // Contact remains short and firm, with an audible but controlled fracture.
    dryKnock(0, profile.root * pitch, .67, .04, 79);
    dryKnock(0, profile.body * pitch, .45, .052, 63);
    dryKnock(.001, profile.root * 1.45 * pitch, .14, .015, 155);
    softAir(0, .016, .28, 400, 3100, true);
    softAir(.012, .018, .12, 470, 2300, true);
  } else if (profile.combat) {
    for (const [at, ratio] of profile.notes ?? [[0, 1]]) {
      const available = profile.length - at;
      strike(at, profile.body * ratio * pitch, profile.bodyGain,
        profile.decay * .74, available, .5);
      strike(at, profile.root * ratio * pitch, .58,
        profile.decay * 1.14, Math.min(available, .13), .55);
      // A pair of dry, inharmonic cracks gives attacks a breakage edge.
      // They end in milliseconds; there is no broadband hiss or airy fade.
      const crack = (profile.crack ?? profile.root * 1.7) * ratio * pitch;
      strike(at, crack, .31, 180, Math.min(available, .026), .17);
      strike(at + .006, crack * 1.43, .14, 230,
        Math.min(available - .006, .019), .1);
      if (kind === 'explosion' || kind === 'critical') {
        strike(at + .014, profile.root * .87 * ratio * pitch, .36, 90,
          Math.min(available - .014, .07), .35);
      }
    }
    if (kind === 'explosion') {
      softAir(0, .052, .4, 300, 3500, true);
      softAir(.018, .042, .24, 420, 2800, true);
    } else if (kind === 'blade' || kind === 'magic' || kind === 'critical'
      || kind === 'playerHit' || kind === 'death') {
      softAir(0, .02, .2, 450, 3100, true);
    }
  } else if (profile.notes) {
    for (const [at, ratio] of profile.notes) tap(at, profile.root * ratio * pitch, .52, profile.decay, .14);
  } else {
    tap(0, profile.root * pitch, .68, profile.decay, profile.length);
  }
  if (!profile.combat) {
    tap(0, profile.body * pitch, profile.bodyGain, 67, .07);
  }

  // Shared headroom prevents clipping when several enemies are struck together.
  const peak = samples.reduce((max, sample) => Math.max(max, Math.abs(sample)), 0) || 1;
  const wav = Buffer.alloc(44 + length * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28);
  wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
  wav.write('data', 36); wav.writeUInt32LE(length * 2, 40);
  const headroom = profile.combat ? (kind === 'explosion' ? .68 : .62) : .5;
  for (let i = 0; i < length; i++) wav.writeInt16LE(Math.round(samples[i] / peak * headroom * 32767), 44 + i * 2);
  writeFileSync(join(directory, `${name}.wav`), wav);
}

let count = 0;
for (const [kind, names] of Object.entries(groups)) names.forEach((name, index) => {
  render(name, kind, index); count++;
});
process.stdout.write(`${count} clear SFX files generated\n`);
