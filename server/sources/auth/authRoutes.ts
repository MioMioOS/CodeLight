import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { verifySignature, createToken } from './crypto';
import { db } from '@/storage/db';
import { config } from '@/config';

export async function authRoutes(app: FastifyInstance) {
    app.post('/v1/auth', {
        schema: {
            body: z.object({
                publicKey: z.string(),
                challenge: z.string(),
                signature: z.string(),
                // Optional client-chosen TTL in days. Clamped to a sane
                // range; falls back to the server default if absent or
                // out of bounds. Lets the iOS Settings picker actually
                // control how long the JWT lives.
                expiryDays: z.number().int().min(1).max(365).optional(),
            }),
        },
    }, async (request, reply) => {
        const { publicKey, challenge, signature, expiryDays } = request.body as {
            publicKey: string;
            challenge: string;
            signature: string;
            expiryDays?: number;
        };

        if (!verifySignature(challenge, signature, publicKey)) {
            return reply.code(401).send({ error: 'Invalid signature' });
        }

        const device = await db.device.upsert({
            where: { publicKey },
            create: { publicKey, name: 'Unknown Device' },
            update: {},
        });

        const ttl = expiryDays && expiryDays > 0 ? expiryDays : config.tokenExpiryDays;
        const token = createToken(device.id, config.masterSecret, ttl);
        return { success: true, token, deviceId: device.id, expiresInDays: ttl };
    });
}
