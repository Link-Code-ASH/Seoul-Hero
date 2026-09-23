/** Other hosts can supply their own adapter without changing game rules. */
export interface StorageAdapter {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export class LocalStorageAdapter implements StorageAdapter {
  getItem(key: string): string | null { return globalThis.localStorage.getItem(key); }
  setItem(key: string, value: string): void { globalThis.localStorage.setItem(key, value); }
  removeItem(key: string): void { globalThis.localStorage.removeItem(key); }
}

/** The legacy unscoped keys remain the guest save. Signed-in users get separate local backups. */
export class AccountStorageAdapter implements StorageAdapter {
  constructor(private readonly userId: string) {}
  private key(key: string): string { return `${key}.account.${this.userId}`; }
  getItem(key: string): string | null { return globalThis.localStorage.getItem(this.key(key)); }
  setItem(key: string, value: string): void { globalThis.localStorage.setItem(this.key(key), value); }
  removeItem(key: string): void { globalThis.localStorage.removeItem(this.key(key)); }
}
