import { describe, it, expect, vi } from 'vitest';
import { allocateDeviceSeq, allocateSessionSeq, allocateSessionSeqBatch } from './seq';

vi.mock('./db', () => ({
    db: {
        device: {
            update: vi.fn().mockResolvedValue({ seq: 1 }),
        },
        session: {
            update: vi.fn().mockResolvedValue({ seq: 1 }),
        },
    },
}));

describe('allocateDeviceSeq', () => {
    it('should increment and return new seq', async () => {
        const seq = await allocateDeviceSeq('device-1');
        expect(seq).toBe(1);
    });
});

describe('allocateSessionSeq', () => {
    it('should increment and return new seq', async () => {
        const seq = await allocateSessionSeq('session-1');
        expect(seq).toBe(1);
    });
});

describe('allocateSessionSeqBatch', () => {
    it('should allocate N sequences and return start seq', async () => {
        const { db } = await import('./db');
        (db.session.update as any).mockResolvedValueOnce({ seq: 5 });
        const startSeq = await allocateSessionSeqBatch('session-1', 5);
        expect(startSeq).toBe(1);
    });
});
