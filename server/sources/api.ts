import fastify from 'fastify';
import cors from '@fastify/cors';
import {
    serializerCompiler,
    validatorCompiler,
    type ZodTypeProvider,
} from 'fastify-type-provider-zod';
import { authRoutes } from '@/auth/authRoutes';
import { pairingRoutes } from '@/pairing/pairingRoutes';
import { sessionRoutes } from '@/session/sessionRoutes';
import { config } from '@/config';

export async function startApi() {
    const app = fastify({
        bodyLimit: 10 * 1024 * 1024,
    }).withTypeProvider<ZodTypeProvider>();

    app.setValidatorCompiler(validatorCompiler);
    app.setSerializerCompiler(serializerCompiler);

    await app.register(cors, {
        origin: '*',
        methods: ['GET', 'POST', 'DELETE', 'OPTIONS'],
    });

    app.get('/health', async () => ({ status: 'ok' }));

    await app.register(authRoutes);
    await app.register(pairingRoutes);
    await app.register(sessionRoutes);

    await app.listen({ port: config.port, host: '0.0.0.0' });
    console.log(`CodeLight Server listening on port ${config.port}`);

    return app;
}
