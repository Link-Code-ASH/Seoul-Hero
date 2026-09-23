import { createDefaultMeta } from '../state/MetaState';
import type { MetaState } from '../state/MetaState';
import { BACKUP_KEY, RECOVERY_KEY, SAVE_KEY, SAVE_VERSION } from './SaveData';
import { FutureSaveVersionError, parseSave } from './migrations';
import type { StorageAdapter } from './StorageAdapter';
import { validateMeta } from './validation';

export class SaveManager {
  status = '';
  private futureVersionProtected = false;
  private observedPrimary: string | null | undefined;

  constructor(private readonly adapter: StorageAdapter) {}

  load(): MetaState {
    this.futureVersionProtected = false;
    try {
      const primary = this.adapter.getItem(SAVE_KEY);
      this.observedPrimary = primary;
      if (primary !== null) {
        try {
          const save = parseSave(primary);
          this.status = '저장된 진행을 불러왔습니다.';
          return save.meta;
        } catch (error) {
          if (error instanceof FutureSaveVersionError) {
            this.futureVersionProtected = true;
            this.status = error.message;
          } else {
            this.status = '저장이 손상되어 복구 사본을 확인합니다.';
            this.preserveRecovery(primary);
          }
        }
      }
      const backup = this.adapter.getItem(BACKUP_KEY);
      if (backup !== null) {
        try {
          const save = parseSave(backup);
          if (!this.futureVersionProtected) this.status = '이전 자동 저장 사본에서 진행을 복구했습니다.';
          return save.meta;
        } catch (error) {
          if (error instanceof FutureSaveVersionError) {
            this.futureVersionProtected = true;
            this.status = error.message;
          }
        }
      }
      const defaults = createDefaultMeta();
      if (this.futureVersionProtected) return defaults;
      if (primary !== null || backup !== null) {
        this.status = '저장 복구에 실패하여 기본 진행으로 시작합니다. 손상된 원본은 가능한 경우 보관됩니다.';
        return defaults;
      }
      this.save(defaults);
      return defaults;
    } catch {
      this.status = '브라우저 저장소를 사용할 수 없습니다. 현재 진행은 메모리에만 유지되므로 JSON 백업을 이용하세요.';
      return createDefaultMeta();
    }
  }

  save(meta: MetaState): boolean {
    if (this.futureVersionProtected) {
      this.status = new FutureSaveVersionError().message;
      return false;
    }
    try {
      const serialized = this.export(meta);
      const previous = this.adapter.getItem(SAVE_KEY);
      // Another tab may have progressed since this instance loaded. Never replace
      // its primary or backup with this tab's stale in-memory snapshot.
      if (this.observedPrimary !== undefined && previous !== this.observedPrimary) {
        this.status = '다른 창에서 저장 기록이 변경되어 자동 저장을 중지했습니다. 현재 기록을 JSON으로 내보낸 뒤 새로고침하세요.';
        return false;
      }
      if (previous !== null) {
        let validPrevious = false;
        try {
          parseSave(previous);
          validPrevious = true;
        } catch (error) {
          if (error instanceof FutureSaveVersionError) {
            this.futureVersionProtected = true;
            this.status = error.message;
            return false;
          }
          this.preserveRecovery(previous);
        }
        // Keep the last valid snapshot. A failed primary write leaves that snapshot usable.
        if (validPrevious) this.adapter.setItem(BACKUP_KEY, previous);
      }
      this.adapter.setItem(SAVE_KEY, serialized);
      this.observedPrimary = serialized;
      this.status = '자동 저장 완료';
      return true;
    } catch {
      this.status = '저장하지 못했습니다. 저장 용량·브라우저 권한을 확인하고 JSON 백업을 내려받으세요.';
      return false;
    }
  }

  export(meta: MetaState): string {
    return JSON.stringify({ saveVersion: SAVE_VERSION, savedAt: new Date().toISOString(), meta: validateMeta(meta) }, null, 2);
  }

  /** Import succeeds only after a valid save was actually persisted. */
  import(json: string): MetaState {
    const save = parseSave(json);
    if (!this.save(save.meta)) throw new Error(this.status);
    this.status = 'JSON 백업을 불러오고 저장했습니다.';
    return save.meta;
  }

  /** An explicit user reset may discard even an unknown future-version save. */
  reset(): MetaState {
    const defaults = createDefaultMeta();
    try {
      this.adapter.removeItem(SAVE_KEY);
      this.adapter.removeItem(BACKUP_KEY);
      this.adapter.removeItem(RECOVERY_KEY);
      this.futureVersionProtected = false;
      this.observedPrimary = null;
      if (this.save(defaults)) this.status = '영구 진행과 설정을 초기화했습니다.';
    } catch {
      this.status = '저장소의 데이터를 초기화하지 못했습니다. 브라우저 저장 권한을 확인하세요.';
    }
    return defaults;
  }

  private preserveRecovery(raw: string): void {
    try { this.adapter.setItem(RECOVERY_KEY, raw); } catch { /* Recovery must never prevent launching. */ }
  }
}
