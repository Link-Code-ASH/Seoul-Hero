import { readCloudSave, writeCloudSave, type CloudSnapshot } from './CloudSave';

/** Serializes saves and stops on revision conflicts instead of overwriting another device. */
export class CloudSync {
  private pending: string | null = null;
  private writing = false;
  private stopped = false;
  private conflict = false;
  constructor(
    readonly userId: string,
    private revision: number | null,
    private readonly onStatus: (status: string) => void,
    private readonly onConflict: (remote: CloudSnapshot | null) => void,
  ) {}

  queue(raw: string): void {
    if (this.stopped) return;
    this.pending = raw;
    void this.flush();
  }

  retry(): void { void this.flush(); }
  stop(): void { this.stopped = true; this.pending = null; }

  resolve(revision: number | null, upload: string | null): void {
    this.revision = revision;
    this.conflict = false;
    this.pending = upload;
    if (upload) void this.flush();
  }

  private async flush(): Promise<void> {
    if (this.writing || this.stopped || this.conflict || !this.pending) return;
    this.writing = true;
    try {
      while (this.pending && !this.stopped && !this.conflict) {
        const raw = this.pending;
        this.pending = null;
        try {
          this.revision = await writeCloudSave(this.userId, raw, this.revision);
        } catch (error) {
          this.pending ??= raw;
          if (error instanceof Error && error.message === 'CLOUD_CONFLICT') {
            this.conflict = true;
            try { this.onConflict(await readCloudSave(this.userId)); }
            catch {
              this.conflict = false;
              this.onStatus('다른 기기의 기록을 확인하지 못했습니다. 연결 후 다시 시도하세요.');
            }
          } else this.onStatus('오프라인 · 이 기기에 저장됨');
          break;
        }
      }
      if (!this.pending && !this.stopped && !this.conflict) this.onStatus('동기화 완료');
    } finally { this.writing = false; }
  }
}
