// Places API routes - famous attractions and their tracklogs
export default async function placesRoutes(fastify) {
  // GET /api/v1/places - List all places with optional filters
  fastify.get('/places', async (request, reply) => {
    const { category, limit, offset } = request.query;
    const limitNum = parseInt(limit) || 50;
    const offsetNum = parseInt(offset) || 0;

    let query = fastify.supabase
      .from('v_places_with_stats')
      .select('*')
      .order('popularity_score', { ascending: false })
      .range(offsetNum, offsetNum + limitNum - 1);

    if (category) {
      query = query.eq('category', category);
    }

    const { data, error } = await query;

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { places: data || [] };
  });

  // GET /api/v1/places/popular - Get popular places (featured + high score)
  fastify.get('/places/popular', async (request, reply) => {
    const { category, limit } = request.query;
    const limitNum = parseInt(limit) || 10;

    let query = fastify.supabase
      .from('v_places_with_stats')
      .select('*')
      .or('is_featured.eq.true,popularity_score.gt.50')
      .order('popularity_score', { ascending: false })
      .limit(limitNum);

    if (category) {
      query = query.eq('category', category);
    }

    const { data, error } = await query;

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { places: data || [] };
  });

  // GET /api/v1/places/:id - Get single place details
  fastify.get('/places/:id', async (request, reply) => {
    const { id } = request.params;

    const { data, error } = await fastify.supabase
      .from('v_places_with_stats')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !data) {
      return reply.code(404).send({ error: 'Place not found' });
    }

    return { place: data };
  });

  // GET /api/v1/places/:id/tracklogs - Get tracklogs associated with a place
  fastify.get('/places/:id/tracklogs', async (request, reply) => {
    const { id } = request.params;
    const { limit } = request.query;
    const limitNum = parseInt(limit) || 20;

    // Get place info
    const { data: place, error: placeError } = await fastify.supabase
      .from('places')
      .select('id, name, description, latitude, longitude, category, image_url, popularity_score')
      .eq('id', id)
      .single();

    if (placeError || !place) {
      return reply.code(404).send({ error: 'Place not found' });
    }

    // Get tracklogs for this place
    const { data: tracklogs, error: tracklogsError } = await fastify.supabase
      .from('v_public_tracklogs')
      .select('id, title, description, distance_meters, elevation_gain, author_name, avg_rating, created_at')
      .limit(limitNum);

    if (tracklogsError) {
      return reply.code(500).send({ error: tracklogsError.message });
    }

    // Filter tracklogs that are associated with this place
    // (In production, you'd have a proper join)
    const { data: placeTracklogs } = await fastify.supabase
      .from('place_tracklogs')
      .select('tracklog_id')
      .eq('place_id', id);

    const tracklogIds = (placeTracklogs || []).map(pt => pt.tracklog_id);
    const filteredTracklogs = (tracklogs || []).filter(t => tracklogIds.includes(t.id));

    return {
      place,
      tracklogs: filteredTracklogs
    };
  });

  // POST /api/v1/places - Create a new place (admin)
  fastify.post('/places', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { name, description, latitude, longitude, category, image_url, popularity_score, is_featured } = request.body;

    const { data, error } = await fastify.supabase
      .from('places')
      .insert({
        name,
        description,
        latitude,
        longitude,
        category,
        image_url,
        popularity_score: popularity_score || 0,
        is_featured: is_featured || false
      })
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return reply.code(201).send(data);
  });

  // PUT /api/v1/places/:id - Update a place
  fastify.put('/places/:id', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { id } = request.params;
    const updates = request.body;
    updates.updated_at = new Date().toISOString();

    const { data, error } = await fastify.supabase
      .from('places')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return data;
  });

  // POST /api/v1/places/:id/tracklogs - Associate a tracklog with a place
  fastify.post('/places/:id/tracklogs', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { id: placeId } = request.params;
    const { tracklog_id } = request.body;

    // Verify tracklog ownership
    const { data: tracklog } = await fastify.supabase
      .from('tracklogs')
      .select('user_id')
      .eq('id', tracklog_id)
      .single();

    if (!tracklog || tracklog.user_id !== request.user.sub) {
      return reply.code(403).send({ error: 'Access denied' });
    }

    const { data, error } = await fastify.supabase
      .from('place_tracklogs')
      .insert({
        place_id: placeId,
        tracklog_id
      })
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return reply.code(201).send(data);
  });

  // DELETE /api/v1/places/:id/tracklogs/:tracklogId - Remove tracklog from place
  fastify.delete('/places/:id/tracklogs/:tracklogId', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { id: placeId, tracklogId } = request.params;

    // Verify tracklog ownership
    const { data: tracklog } = await fastify.supabase
      .from('tracklogs')
      .select('user_id')
      .eq('id', tracklogId)
      .single();

    if (!tracklog || tracklog.user_id !== request.user.sub) {
      return reply.code(403).send({ error: 'Access denied' });
    }

    const { error } = await fastify.supabase
      .from('place_tracklogs')
      .delete()
      .eq('place_id', placeId)
      .eq('tracklog_id', tracklogId);

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return reply.code(204).send();
  });

  // Search places by name
  fastify.get('/places/search', async (request, reply) => {
    const { q } = request.query;

    if (!q || q.length < 2) {
      return reply.code(400).send({ error: 'Query must be at least 2 characters' });
    }

    const { data, error } = await fastify.supabase
      .from('v_places_with_stats')
      .select('*')
      .ilike('name', `%${q}%`)
      .order('popularity_score', { ascending: false })
      .limit(20);

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { places: data || [] };
  });
}