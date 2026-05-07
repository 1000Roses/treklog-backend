// SOS Alert routes - emergency safety features
import { v4 as uuidv4 } from 'uuid';

export default async function sosRoutes(fastify) {
  // Create SOS alert
  fastify.post('/sos', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { message, location_lat, location_lng, severity } = request.body;
    const userId = request.user.sub;

    // Get user info for emergency contact
    const { data: user } = await fastify.supabase
      .from('users')
      .select('name, phone, emergency_contact_name, emergency_contact_phone')
      .eq('id', userId)
      .single();

    const id = uuidv4();
    const now = new Date().toISOString();

    const { data, error } = await fastify.supabase
      .from('sos_alerts')
      .insert({
        id,
        user_id: userId,
        message: message || 'Emergency alert',
        location_lat,
        location_lng,
        severity: severity || 'high',
        status: 'active',
        created_at: now,
        updated_at: now
      })
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    // Notify nearby users (future: implement notification service)
    // For now, just return the alert
    return reply.code(201).send({
      alert: data,
      emergency_contact: {
        name: user?.emergency_contact_name,
        phone: user?.emergency_contact_phone
      }
    });
  });

  // Get active SOS alerts for current user
  fastify.get('/sos/active', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { data, error } = await fastify.supabase
      .from('sos_alerts')
      .select('*')
      .eq('user_id', request.user.sub)
      .eq('status', 'active')
      .order('created_at', { ascending: false });

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { alerts: data || [] };
  });

  // Get all active SOS alerts (for authorities/dispatchers)
  fastify.get('/sos/all', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { data, error } = await fastify.supabase
      .from('sos_alerts')
      .select(`
        *,
        user:users(name, phone, emergency_contact_name, emergency_contact_phone)
      `)
      .eq('status', 'active')
      .order('created_at', { ascending: false });

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { alerts: data || [] };
  });

  // Resolve/cancel SOS alert
  fastify.put('/sos/:id/resolve', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { id } = request.params;
    const { resolution_notes } = request.body;

    const { data, error } = await fastify.supabase
      .from('sos_alerts')
      .update({
        status: 'resolved',
        resolution_notes,
        resolved_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .eq('user_id', request.user.sub) // only owner can resolve
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { resolved: true, alert: data };
  });

  // Get nearby users (for safety awareness)
  fastify.get('/presence/nearby', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { lat, lng, radius_km } = request.query;
    
    if (!lat || !lng) {
      return reply.code(400).send({ error: 'lat and lng required' });
    }

    const radius = parseFloat(radius_km) || 10; // default 10km

    // Get users with recent location updates (last 30 mins)
    const thirtyMinsAgo = new Date(Date.now() - 30 * 60 * 1000).toISOString();

    const { data, error } = await fastify.supabase
      .from('user_locations')
      .select('user_id, latitude, longitude, updated_at, user:users(name)')
      .gte('updated_at', thirtyMinsAgo)
      .order('updated_at', { ascending: false });

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    // Filter by distance (simple approximation for demo)
    // In production, use PostGIS ST_DWithin
    const nearbyUsers = (data || []).filter(u => u.user_id !== request.user.sub);

    return { nearby_users: nearbyUsers };
  });

  // Update my location (for presence tracking)
  fastify.post('/presence/location', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { latitude, longitude, accuracy, heading, speed } = request.body;
    const userId = request.user.sub;

    // Upsert location
    const { data, error } = await fastify.supabase
      .from('user_locations')
      .upsert({
        user_id: userId,
        latitude,
        longitude,
        accuracy,
        heading,
        speed,
        updated_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return { location: data };
  });
}