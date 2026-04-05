import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { db } from '@/storage/db';
import { authMiddleware } from '@/auth/middleware';

export async function pairingRoutes(app: FastifyInstance) {

    // Step 1: CodeIsland creates a pairing request (authenticated)
    app.post('/v1/pairing/request', {
        preHandler: authMiddleware,
        schema: {
            body: z.object({
                tempPublicKey: z.string(),
                serverUrl: z.string(),
                deviceName: z.string(),
            }),
        },
    }, async (request) => {
        const { tempPublicKey, serverUrl, deviceName } = request.body as {
            tempPublicKey: string;
            serverUrl: string;
            deviceName: string;
        };
        const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

        const pairing = await db.pairingRequest.upsert({
            where: { tempPublicKey },
            create: { tempPublicKey, serverUrl, deviceName, expiresAt },
            update: { serverUrl, deviceName, expiresAt, response: null, responseDeviceId: null },
        });

        return { id: pairing.id, expiresAt: pairing.expiresAt.toISOString() };
    });

    // Step 2: CodeLight scans QR, responds with its public key (authenticated)
    app.post('/v1/pairing/respond', {
        preHandler: authMiddleware,
        schema: {
            body: z.object({
                tempPublicKey: z.string(),
                response: z.string(),
            }),
        },
    }, async (request, reply) => {
        const { tempPublicKey, response } = request.body as {
            tempPublicKey: string;
            response: string;
        };

        const pairing = await db.pairingRequest.findUnique({
            where: { tempPublicKey },
        });

        if (!pairing) {
            return reply.code(404).send({ error: 'Pairing request not found' });
        }

        if (pairing.expiresAt < new Date()) {
            return reply.code(410).send({ error: 'Pairing request expired' });
        }

        await db.pairingRequest.update({
            where: { id: pairing.id },
            data: { response, responseDeviceId: request.deviceId },
        });

        return { success: true };
    });

    // Step 3: CodeIsland polls for response
    app.get('/v1/pairing/status', {
        preHandler: authMiddleware,
        schema: {
            querystring: z.object({
                tempPublicKey: z.string(),
            }),
        },
    }, async (request, reply) => {
        const { tempPublicKey } = request.query as {
            tempPublicKey: string;
        };

        const pairing = await db.pairingRequest.findUnique({
            where: { tempPublicKey },
        });

        if (!pairing) {
            return reply.code(404).send({ error: 'Not found' });
        }

        if (pairing.response) {
            await db.pairingRequest.delete({ where: { id: pairing.id } });
            return {
                status: 'paired',
                response: pairing.response,
                responseDeviceId: pairing.responseDeviceId,
            };
        }

        if (pairing.expiresAt < new Date()) {
            await db.pairingRequest.delete({ where: { id: pairing.id } });
            return { status: 'expired' };
        }

        return { status: 'pending' };
    });
}
