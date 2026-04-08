import { FastifyRequest, FastifyReply } from 'fastify';
import { verifyToken } from './crypto';
import { config } from '@/config';
import { db } from '@/storage/db';

declare module 'fastify' {
    interface FastifyRequest {
        deviceId?: string;
    }
}

export function extractToken(header: string | undefined): string | null {
    if (!header || !header.startsWith('Bearer ')) return null;
    return header.slice(7) || null;
}

/// Throttle lastSeenAt writes per device to at most once per minute.
/// Without this an active iPhone fetching messages every few seconds
/// would write the column hundreds of times a minute for no benefit.
const lastSeenWriteAt = new Map<string, number>();
const LAST_SEEN_THROTTLE_MS = 60_000;

export function bumpLastSeenAt(deviceId: string) {
    const now = Date.now();
    const prev = lastSeenWriteAt.get(deviceId);
    if (prev && now - prev < LAST_SEEN_THROTTLE_MS) return;
    lastSeenWriteAt.set(deviceId, now);
    // Fire-and-forget — never block the request on this.
    db.device.update({
        where: { id: deviceId },
        data: { lastSeenAt: new Date() },
    }).catch(() => {
        // Most likely cause: deviceId no longer exists (device was deleted
        // out from under us). Drop the throttle entry so a re-registered
        // device with the same id gets a fresh write next time.
        lastSeenWriteAt.delete(deviceId);
    });
}

export async function authMiddleware(
    request: FastifyRequest,
    reply: FastifyReply
): Promise<void> {
    const token = extractToken(request.headers.authorization);
    if (!token) {
        reply.code(401).send({ error: 'Missing authorization token' });
        return;
    }

    const payload = verifyToken(token, config.masterSecret);
    if (!payload) {
        reply.code(401).send({ error: 'Invalid token' });
        return;
    }

    request.deviceId = payload.deviceId;
    bumpLastSeenAt(payload.deviceId);
}
