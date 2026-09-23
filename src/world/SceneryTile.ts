export interface SceneryTile {
  key: string;
  x: number;
  y: number;
  variant: number;
  detail: number;
}


/** A coordinate hash avoids retaining any history when distant chunks are released. */
export function generateSceneryTile(x: number, y: number, seed: number): SceneryTile {
  let hash = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263) ^ seed;
  hash = Math.imul(hash ^ (hash >>> 13), 1274126177);
  hash = (hash ^ (hash >>> 16)) >>> 0;
  return { key: `${x},${y}`, x, y, variant: hash % 5, detail: (hash >>> 4) % 4 };
}

