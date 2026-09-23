import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CloudSync } from './CloudSync';
import { readCloudSave, writeCloudSave } from './CloudSave';

vi.mock('./CloudSave', () => ({ readCloudSave: vi.fn(), writeCloudSave: vi.fn() }));

const tick = async () => { await Promise.resolve(); await Promise.resolve(); await Promise.resolve(); };

describe('cloud save revisions', () => {
  beforeEach(() => vi.clearAllMocks());

  it('serializes writes and sends the newest pending save', async () => {
    let completeFirst: (value: number) => void = () => {};
    vi.mocked(writeCloudSave)
      .mockImplementationOnce(() => new Promise(resolve => { completeFirst = resolve; }))
      .mockResolvedValueOnce(3);
    const statuses: string[] = [];
    const sync = new CloudSync('account', 1, status => statuses.push(status), () => {});
    sync.queue('first');
    sync.queue('middle');
    sync.queue('latest');
    expect(writeCloudSave).toHaveBeenCalledTimes(1);
    completeFirst(2);
    await tick();
    expect(writeCloudSave).toHaveBeenNthCalledWith(2, 'account', 'latest', 2);
    expect(statuses).toEqual(['동기화 완료']);
  });

  it('never overwrites a changed remote revision', async () => {
    vi.mocked(writeCloudSave).mockRejectedValueOnce(new Error('CLOUD_CONFLICT'));
    vi.mocked(readCloudSave).mockResolvedValueOnce({ raw: 'remote', revision: 5 });
    const conflicts: number[] = [];
    const sync = new CloudSync('account', 1, () => {}, remote => conflicts.push(remote?.revision ?? -1));
    sync.queue('local');
    await tick();
    expect(conflicts).toEqual([5]);
    expect(writeCloudSave).toHaveBeenCalledTimes(1);
    sync.retry();
    await tick();
    expect(writeCloudSave).toHaveBeenCalledTimes(1);
  });
});
