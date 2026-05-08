// Auth routes using Supabase Auth
export default async function authRoutes(fastify) {
  // ─────────────────────────────────────────────
  // Supabase Auth callback (email confirmation)
  // Handles redirect from Supabase after email confirmation
  // URL format: /auth/callback?token=xxx&email=xxx&type=signup
  // ─────────────────────────────────────────────
  fastify.get('/auth/callback', async (request, reply) => {
    const { token, email, type, redirectTo } = request.query;
    
    // Default frontend URL - can be overridden via redirectTo
    const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:3000';

    if (type === 'signup' && token) {
      // Verify OTP token from Supabase
      try {
        const { data, error } = await fastify.supabase.auth.verifyOtp({
          type: 'email',
          token,
          email
        });

        if (!error && data?.user) {
          // Create our own JWT for the frontend
          const jwtToken = fastify.jwt.sign({
            sub: data.user.id,
            email: data.user.email
          });

          // Ensure user exists in public.users
          await ensureUserProfile(data.user);

          // Redirect to frontend with token
          return reply.redirect(`${frontendUrl}/auth/callback?token=${jwtToken}&type=confirmed`);
        }
      } catch (err) {
        fastify.log.error('OTP verification failed:', err);
      }
    }

    // Fallback redirect
    return reply.redirect(`${frontendUrl}/login?email_confirmed=true`);
  });

  // ─────────────────────────────────────────────
  // Email confirmation status check
  // Frontend polls this to check if email was confirmed
  // ─────────────────────────────────────────────
  fastify.get('/auth/confirm/status', async (request, reply) => {
    const { user_id } = request.query;

    if (!user_id) {
      return reply.code(400).send({ error: 'user_id required' });
    }

    try {
      // Use service role or admin query to check confirmation
      const { data: { users }, error } = await fastify.supabase.admin
        ? await fastify.supabase.admin.getUserById(user_id)
        : { data: null, error: 'Admin not available' };

      // Fallback: check via public users table
      if (error || !users) {
        const { data: userData } = await fastify.supabase
          .from('users')
          .select('created_at')
          .eq('id', user_id)
          .single();

        if (userData) {
          return {
            confirmed: true,
            user_id
          };
        }
      }

      return { confirmed: false, user_id };
    } catch (err) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // ─────────────────────────────────────────────
  // Manual token verification (for testing)
  // POST /auth/verify with token in body
  // ─────────────────────────────────────────────
  fastify.post('/auth/verify', async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: 'token required' });
    }

    try {
      // Verify Supabase token
      const { data: { user }, error } = await fastify.supabase.auth.getUser(token);

      if (error || !user) {
        // Try to verify our own JWT
        try {
          const decoded = fastify.jwt.verify(token);
          return {
            valid: true,
            user_id: decoded.sub,
            email: decoded.email
          };
        } catch {
          return reply.code(401).send({ error: 'Invalid token' });
        }
      }

      // Ensure profile exists
      await ensureUserProfile(user);

      // Return our own JWT
      const jwtToken = fastify.jwt.sign({
        sub: user.id,
        email: user.email
      });

      return {
        valid: true,
        token: jwtToken,
        user_id: user.id,
        email: user.email
      };
    } catch (err) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // ─────────────────────────────────────────────
  // Resend confirmation email
  // POST /auth/resend-confirmation
  // ─────────────────────────────────────────────
  fastify.post('/auth/resend-confirmation', async (request, reply) => {
    const { email } = request.body;

    if (!email) {
      return reply.code(400).send({ error: 'email required' });
    }

    try {
      const { error } = await fastify.supabase.auth.resend({
        type: 'signup',
        email
      });

      if (error) {
        return reply.code(400).send({ error: error.message });
      }

      return { message: 'Confirmation email sent' };
    } catch (err) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // ─────────────────────────────────────────────
  // Register new user
  // POST /auth/register
  // ─────────────────────────────────────────────
  fastify.post('/auth/register', async (request, reply) => {
    const { email, password, name, phone } = request.body;

    if (!email || !password) {
      return reply.code(400).send({ error: 'email and password required' });
    }

    if (password.length < 8) {
      return reply.code(400).send({ error: 'Password must be at least 8 characters' });
    }

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

    // If email confirmation is disabled, create profile immediately
    if (data.user && !data.session) {
      // Email confirmation required - session only created after confirmation
      await ensureUserProfile(data.user);
    }

    return {
      user: {
        id: data.user.id,
        email: data.user.email,
        name: data.user.user_metadata?.name,
        phone: data.user.user_metadata?.phone
      },
      needs_confirmation: !data.session
    };
  });

  // ─────────────────────────────────────────────
  // Login - returns JWT token
  // POST /auth/login
  // ─────────────────────────────────────────────
  fastify.post('/auth/login', async (request, reply) => {
    const { email, password } = request.body;

    if (!email || !password) {
      return reply.code(400).send({ error: 'email and password required' });
    }

    const { data, error } = await fastify.supabase
      .auth.signInWithPassword({ email, password });

    if (error) {
      return reply.code(401).send({ error: 'Invalid credentials' });
    }

    // Create our own JWT
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

  // ─────────────────────────────────────────────
  // Refresh token
  // POST /auth/refresh
  // ─────────────────────────────────────────────
  fastify.post('/auth/refresh', async (request, reply) => {
    const { refresh_token } = request.body;

    if (!refresh_token) {
      return reply.code(400).send({ error: 'refresh_token required' });
    }

    try {
      const { data, error } = await fastify.supabase
        .auth.refreshSession({ refresh_token });

      if (error) {
        return reply.code(401).send({ error: 'Invalid refresh token' });
      }

      const token = fastify.jwt.sign({
        sub: data.user.id,
        email: data.user.email
      });

      return {
        token,
        user: {
          id: data.user.id,
          email: data.user.email
        }
      };
    } catch (err) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // ─────────────────────────────────────────────
  // Get current user profile (protected)
  // GET /auth/me
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // Update user profile (protected)
  // PUT /auth/me
  // ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// Helper: Ensure user profile exists in public.users
// Called after Supabase auth confirmation
// ─────────────────────────────────────────────
async function ensureUserProfile(supabaseUser) {
  try {
    // Check if profile exists
    const { data: existing } = await fastify.supabase
      .from('users')
      .select('id')
      .eq('id', supabaseUser.id)
      .single();

    if (!existing) {
      // Create profile
      await fastify.supabase
        .from('users')
        .insert({
          id: supabaseUser.id,
          name: supabaseUser.user_metadata?.name || supabaseUser.email,
          phone: supabaseUser.user_metadata?.phone || null,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        });
    }
  } catch (err) {
    // Log but don't fail - profile creation is best effort
    console.error('Failed to ensure user profile:', err.message);
  }
}