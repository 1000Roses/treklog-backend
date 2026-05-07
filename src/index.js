import { buildApp } from './plugins/app.js';
import { supabase } from './config/supabase.js';
import authRoutes from './routes/auth.js';
import tracklogRoutes from './routes/tracklogs.js';
import sosRoutes from './routes/sos.js';
import presenceWebSocket from './routes/presence.js';
import placesRoutes from './routes/places.js';

const app = await buildApp();

// Decorate with supabase client
app.decorate('supabase', supabase);

// Health check
app.get('/health', async () => {
  return { status: 'ok', timestamp: new Date().toISOString() };
});

// Register routes
app.register(authRoutes, { prefix: '/api/v1' });
app.register(tracklogRoutes, { prefix: '/api/v1' });
app.register(sosRoutes, { prefix: '/api/v1' });
app.register(placesRoutes, { prefix: '/api/v1' });
app.register(presenceWebSocket);

// Graceful shutdown
const shutdown = async () => {
  await app.close();
  process.exit(0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// Start server
const start = async () => {
  try {
    const port = parseInt(process.env.PORT) || 6666;
    const host = process.env.HOST || '0.0.0.0';

    await app.listen({ port, host });
    console.log(`🚀 TrekTrack API running at http://${host}:${port}`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
};

start();