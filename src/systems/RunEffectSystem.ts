import { VFX_CONFIG, VFX_PRESETS } from '../data/vfx';
import type { RunEffect, RunEffectKind } from '../state/RunEffect';
import type { RunState } from '../state/RunState';

type EffectInput = Partial<Omit<RunEffect, 'kind' | 'remaining'>> & Pick<RunEffect, 'x' | 'y'>;

export function spawnRunEffect(run: RunState, kind: RunEffectKind, input: EffectInput): void {
  if (run.effects.length >= VFX_CONFIG.maxActive) return;
  const duration = input.duration ?? VFX_PRESETS[kind]?.duration ?? 0.3;
  const seed = input.seed ?? hashEffect(kind, input.x, input.y, run.stageCombatTime);
  run.effects.push({
    kind,
    x: input.x,
    y: input.y,
    endX: input.endX ?? input.x,
    endY: input.endY ?? input.y,
    radius: input.radius ?? 20,
    angle: input.angle ?? 0,
    arc: input.arc ?? 0,
    remaining: duration,
    duration,
    color: input.color ?? 0x8fdcff,
    value: input.value,
    seed,
  });
}

function hashEffect(kind: string, x: number, y: number, time: number): number {
  let value = Math.imul(Math.round(x * 17), 73856093) ^ Math.imul(Math.round(y * 19), 19349663);
  value ^= Math.imul(Math.round(time * 1000), 83492791);
  for (let i = 0; i < kind.length; i++) value = Math.imul(value ^ kind.charCodeAt(i), 16777619);
  return value >>> 0;
}
