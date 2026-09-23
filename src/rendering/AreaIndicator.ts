import type { Graphics } from 'pixi.js';
/** Filled danger footprint: the colored area is the actual hostile damage radius. */
export function drawAreaIndicator(g: Graphics, x: number, y: number, radius: number, color: number, time: number, active = false): void {
  const breathe = 0.5 + Math.sin(time * 4) * 0.5;
  g.circle(x,y,radius).fill({color,alpha:(active?0.2:0.11)+breathe*0.035});
  g.circle(x,y,radius*0.72).fill({color,alpha:(active?0.07:0.035)+breathe*0.02});
}

/** Layered field fill, circuit lattice and inward energy pulses for a damaging aura. */
export function drawManaDamageField(g: Graphics, x: number, y: number, radius: number, color: number, time: number): void {
  const breathe = 0.5 + Math.sin(time * 2.3) * 0.5;
  g.circle(x, y, radius).fill({ color: 0x160d2b, alpha: 0.16 });
  g.circle(x, y, radius * 0.82).fill({ color, alpha: 0.035 + breathe * 0.025 });
  g.circle(x, y, radius * 0.58).fill({ color, alpha: 0.045 });

  const hex = (scale: number, rotation: number, alpha: number, width: number): void => {
    const points: number[] = [];
    for (let i = 0; i < 6; i++) {
      const a = rotation + i * Math.PI / 3;
      points.push(x + Math.cos(a) * radius * scale, y + Math.sin(a) * radius * scale);
    }
    points.push(points[0]!, points[1]!);
    g.poly(points).stroke({ color, alpha, width });
  };
  hex(0.96, time * 0.08, 0.42, 2.2);
  hex(0.68, -time * 0.13, 0.25, 1.25);

  for (let i = 0; i < 6; i++) {
    const angle = i * Math.PI / 3 + time * 0.08;
    const inner = radius * 0.23, outer = radius * 0.88;
    g.moveTo(x + Math.cos(angle) * inner, y + Math.sin(angle) * inner)
      .lineTo(x + Math.cos(angle) * outer, y + Math.sin(angle) * outer)
      .stroke({ color, alpha: 0.09 + breathe * 0.06, width: 1.2 });
  }
  for (let i = 0; i < 5; i++) {
    const phase = (time * 0.34 + i * 0.2) % 1;
    const angle = i * 2.399 + time * 0.37;
    const distance = radius * (0.78 - phase * 0.55);
    g.circle(x + Math.cos(angle) * distance, y + Math.sin(angle) * distance, 2.2 + (1 - phase) * 1.8)
      .fill({ color: i % 2 ? 0xe8dcff : color, alpha: 0.25 + (1 - phase) * 0.45 });
  }
  const pulse = (time * 0.7) % 1;
  g.circle(x, y, radius * (0.94 - pulse * 0.55)).stroke({ color: 0xe7dcff, width: 2.6 - pulse, alpha: (1 - pulse) * 0.35 });
  g.circle(x, y, radius * 0.18).fill({ color, alpha: 0.1 + breathe * 0.08 });
}
