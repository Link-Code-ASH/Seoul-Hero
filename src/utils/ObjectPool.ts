export class ObjectPool<T> {
  private readonly available: T[] = [];

  constructor(private readonly create: () => T) {}

  acquire(): T {
    return this.available.pop() ?? this.create();
  }

  release(value: T): void {
    this.available.push(value);
  }
}
