import type { Vec2 } from '../data/types';

/** Entities occupy one center cell. Queries expand their bounds by the largest radius. */
export class SpatialGrid<T extends Vec2> {
  private readonly cells = new Map<string, T[]>();
  private readonly unusedBuckets: T[][] = [];

  constructor(private readonly cellSize: number) {}

  rebuild(entities: readonly T[]): void {
    for (const bucket of this.cells.values()) {
      bucket.length = 0;
      this.unusedBuckets.push(bucket);
    }
    this.cells.clear();
    for (const entity of entities) {
      const key = `${Math.floor(entity.x / this.cellSize)},${Math.floor(entity.y / this.cellSize)}`;
      let bucket = this.cells.get(key);
      if (!bucket) {
        bucket = this.unusedBuckets.pop() ?? [];
        this.cells.set(key, bucket);
      }
      bucket.push(entity);
    }
  }

  query(minX: number, minY: number, maxX: number, maxY: number, output: T[]): void {
    output.length = 0;
    for (let y = Math.floor(minY / this.cellSize); y <= Math.floor(maxY / this.cellSize); y++) {
      for (let x = Math.floor(minX / this.cellSize); x <= Math.floor(maxX / this.cellSize); x++) {
        const bucket = this.cells.get(`${x},${y}`);
        if (bucket) for (const entity of bucket) output.push(entity);
      }
    }
  }
}
