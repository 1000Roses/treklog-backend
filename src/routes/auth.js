// Auth routes using Supabase Auth
export default async function authRoutes(fastify) {
  // Register new user
  fastify.post('/auth/register', async (request, reply) => {
    const { email, password, name, phone } = request.body;

    // Use signUp (works with anon key) instead of admin.createUser
    const { data, error } = await fastify.supabase
      .auth.signUp({
        email,
        password,
        options: {
          data: { name, phone }
        }
      });

    if (error) {
      return reply.code(400).send({ error: error.message });
    }

    return {
      user: {
        id: data.user.id,
        email: data.user.email,
        name: data.user.user_metadata?.name,
        phone: data.user.user_metadata?.phone
      }
    };
  });

  // Login (returns JWT token)
  fastify.post('/auth/login', async (request, reply) => {
    const { email, password } = request.body;

    const { data, error } = await fastify.supabase
      .auth.signInWithPassword({ email, password });

    if (error) {
      return reply.code(401).send({ error: 'Invalid credentials' });
    }

    const token = fastify.jwt.sign({ 
      sub: data.user.id, 
      email: data.user.email 
    });

    return {
      token,
      user: {
        id: data.user.id,
        email: data.user.email,
        name: data.user.user_metadata?.name,
        phone: data.user.user_metadata?.phone
      }
    };
  });

  // Get current user profile
  fastify.get('/auth/me', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { data, error } = await fastify.supabase
      .from('users')
      .select('*')
      .eq('id', request.user.sub)
      .single();

    if (error || !data) {
      return reply.code(404).send({ error: 'User not found' });
    }

    return data;
  });

  // Update user profile
  fastify.put('/auth/me', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { name, phone, emergency_contact_name, emergency_contact_phone } = request.body;

    const { data, error } = await fastify.supabase
      .from('users')
      .update({
        name,
        phone,
        emergency_contact_name,
        emergency_contact_phone,
        updated_at: new Date().toISOString()
      })
      .eq('id', request.user.sub)
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ error: error.message });
    }

    return data;
  });
}
