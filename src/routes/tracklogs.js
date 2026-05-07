// Tracklog routes - CRUD for trek sessions
import { v4 as uuidv4 } from 'uuid';

export default async function tracklogRoutes(fastify) {
  // Get all tracklogs for current user
  fastify.get('/tracklogs', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { data, error } = await fastify.supabase
      .from('tracklogs')
      .select('*')
      .eq('user_id', request.user.sub)
      .order('created_at', { ascending: false });

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { tracklogs: data || [] };
  });

  // Get single tracklog
  fastify.get('/tracklogs/:id', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { id } = request.params;

    const { data, error } = await fastify.supabase
      .from('tracklogs')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !data) {
      return reply.code(404).send({ error: 'Tracklog not found' });
    }

    // Check ownership or public
    if (data.user_id !== request.user.sub && data.is_public !== true) {
      return reply.code(403).send({ error: 'Access denied' });
    }

    return data;
  });

  // Create new tracklog
  fastify.post('/tracklogs', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { title, description, started_at, ended_at, distance_meters, elevation_gain, elevation_loss, gpx_data } = request.body;

    const id = uuidv4();
    const now = new Date().toISOString();

    const { data, error } = await fastify.supabase
      .from('tracklogs')
      .insert({
        id,
        user_id: request.user.sub,
        title,
        description,
        started_at,
        ended_at,
        distance_meters,
        elevation_gain,
        elevation_loss,
        gpx_data,
        is_public: false,
        created_at: now,
        updated_at: now
      })
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return reply.code(201).send(data);
  });

  // Update tracklog
  fastify.put('/tracklogs/:id', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { id } = request.params;
    const updates = request.body;

    // Check ownership
    const { data: existing } = await fastify.supabase
      .from('tracklogs')
      .select('user_id')
      .eq('id', id)
      .single();

    if (!existing || existing.user_id !== request.user.sub) {
      return reply.code(403).send({ error: 'Access denied' });
    }

    updates.updated_at = new Date().toISOString();

    const { data, error } = await fastify.supabase
      .from('tracklogs')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return data;
  });

  // Delete tracklog
  fastify.delete('/tracklogs/:id', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { id } = request.params;

    // Check ownership
    const { data: existing } = await fastify.supabase
      .from('tracklogs')
      .select('user_id')
      .eq('id', id)
      .single();

    if (!existing || existing.user_id !== request.user.sub) {
      return reply.code(403).send({ error: 'Access denied' });
    }

    const { error } = await fastify.supabase
      .from('tracklogs')
      .delete()
      .eq('id', id);

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return reply.code(204).send();
  });

  // Share tracklog (make public)
  fastify.post('/tracklogs/:id/share', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { id } = request.params;
    const { is_public } = request.body;

    const { data, error } = await fastify.supabase
      .from('tracklogs')
      .update({ is_public, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('user_id', request.user.sub) // ensure ownership
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { shared: data.is_public };
  });

  // Get public tracklogs (feed)
  fastify.get('/tracklogs/public/feed', async (request, reply) => {
    const limit = parseInt(request.query.limit) || 20;

    const { data, error } = await fastify.supabase
      .from('tracklogs')
      .select('id, title, description, started_at, distance_meters, elevation_gain, user_id, created_at')
      .eq('is_public', true)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { tracklogs: data || [] };
  });
}