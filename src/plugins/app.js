import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import websocket from '@fastify/websocket';

export async function buildApp() {
  const app = Fastify({
    logger: true
  });

  // CORS
  await app.register(cors, {
    origin: true,
    credentials: true
  });

  // JWT
  await app.register(jwt, {
    secret: process.env.JWT_SECRET || 'fallback-secret-change-me'
  });

  // WebSocket support
  await app.register(websocket);

  // Global auth decorator
  app.decorate('authenticate', async function (request, reply) {
    try {
      await request.jwtVerify();
    } catch (err) {
      reply.code(401).send({ error: 'Unauthorized' });
    }
  });

  return app;
}