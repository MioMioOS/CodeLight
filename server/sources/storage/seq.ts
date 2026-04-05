import { db } from './db';

export async function allocateDeviceSeq(deviceId: string): Promise<number> {
    const result = await db.device.update({
        where: { id: deviceId },
        data: { seq: { increment: 1 } },
        select: { seq: true },
    });
    return result.seq;
}

export async function allocateSessionSeq(sessionId: string): Promise<number> {
    const result = await db.session.update({
        where: { id: sessionId },
        data: { seq: { increment: 1 } },
        select: { seq: true },
    });
    return result.seq;
}

export async function allocateSessionSeqBatch(sessionId: string, count: number): Promise<number> {
    const result = await db.session.update({
        where: { id: sessionId },
        data: { seq: { increment: count } },
        select: { seq: true },
    });
    return result.seq - count + 1;
}
