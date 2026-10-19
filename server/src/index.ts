import Fastify from 'fastify';
import websocket from '@fastify/websocket';
import { registerSignaling } from './signaling.js';

const PORT = Number(process.env.PORT ?? 8080);

async function main(): Promise<void> {
  const app = Fastify({ logger: { level: 'info' } });

  await app.register(websocket, {
    options: { maxPayload: 1 * 1024 * 1024 }, // 1 MB — SDP blobs are small
  });

  app.get('/health', async () => ({ status: 'ok', service: 'nm-connect-server', v: 1 }));

  app.register(async (fastify) => {
    fastify.get('/ws', { websocket: true }, (socket) => {
      registerSignaling(socket);
    });
  });

  await app.listen({ port: PORT, host: '0.0.0.0' });
  app.log.info(`NM Connect signaling listening on ws://localhost:${PORT}/ws`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});