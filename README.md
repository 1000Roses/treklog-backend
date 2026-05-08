# TrekTrack Backend

Backend API for TrekTrack - trekking & safety platform. Built with Fastify + Supabase.

## Features

- **Auth**: JWT-based authentication via Supabase Auth
- **Tracklogs**: Import/manage GPX tracks with metadata
- **Places**: Famous attractions and POIs with tracklog associations
- **User Profiles**: Profile management + emergency contacts
- **SOS Alerts**: Emergency alert system for safety
- **Presence**: Real-time nearby user tracking via WebSocket

## Tech Stack

- **Runtime**: Node.js 18+
- **Framework**: Fastify 4.x
- **Database**: Supabase (PostgreSQL)
- **Auth**: Supabase Auth + JWT
- **Real-time**: WebSocket via `@fastify/websocket`

## Quick Start

### 1. Clone & Install

```bash
git clone https://github.com/1000Roses/treklog-backend.git
cd treklog-backend
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your values
```

Required variables:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
JWT_SECRET=your-secret-key
PORT=3000
FRONTEND_URL=http://localhost:3000
```

### 3. Setup Supabase Database

1. Go to your Supabase project → SQL Editor
2. Copy-paste contents of `supabase/schema.sql`
3. Run the script

This creates:
- `users` table
- `tracklogs` table
- `places` table (attractions/POIs)
- `sos_alerts` table
- `user_locations` table
- `tracklog_imports` table
- `tracklog_categories` table
- `tracklog_tags` table
- `place_tracklogs` junction table
- Row Level Security (RLS) policies
- Auto-create user trigger

### 4. Start Server

```bash
# Development (with auto-reload)
npm run dev

# Production
npm start
```

Server runs at `http://localhost:3000`

## API Endpoints

### Auth

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | Login (returns JWT) |
| POST | `/api/v1/auth/refresh` | Refresh JWT token |
| POST | `/api/v1/auth/resend-confirmation` | Resend confirmation email |
| POST | `/api/v1/auth/verify` | Verify token manually |
| GET | `/api/v1/auth/confirm/status` | Check email confirmation status |
| GET | `/api/v1/auth/callback` | Handle Supabase email confirmation redirect |
| GET | `/api/v1/auth/me` | Get current user profile |
| PUT | `/api/v1/auth/me` | Update profile |

### Auth Flow (Email Confirmation)

1. **Register**: `POST /auth/register` → Supabase sends confirmation email
2. **User clicks link**: Supabase redirects to `/auth/callback?token=xxx&email=xxx&type=signup`
3. **Backend handles callback**: 
   - Verifies token with Supabase
   - Creates user profile in `public.users` if not exists
   - Returns JWT redirect to frontend
4. **Frontend receives token** and logs user in

### Tracklogs

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/tracklogs` | List user's tracklogs |
| GET | `/api/v1/tracklogs/:id` | Get single tracklog |
| POST | `/api/v1/tracklogs` | Create tracklog |
| PUT | `/api/v1/tracklogs/:id` | Update tracklog |
| DELETE | `/api/v1/tracklogs/:id` | Delete tracklog |
| POST | `/api/v1/tracklogs/:id/share` | Share/unshare tracklog |
| GET | `/api/v1/tracklogs/public/feed` | Get public tracklogs |

### Places (Attractions/POIs)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/places` | List all places (filter by category) |
| GET | `/api/v1/places/popular` | Get popular places (featured + high score) |
| GET | `/api/v1/places/search?q=` | Search places by name |
| GET | `/api/v1/places/:id` | Get place details |
| GET | `/api/v1/places/:id/tracklogs` | Get tracklogs for a place |
| POST | `/api/v1/places` | Create place (admin) |
| PUT | `/api/v1/places/:id` | Update place |
| POST | `/api/v1/places/:id/tracklogs` | Associate tracklog with place |
| DELETE | `/api/v1/places/:id/tracklogs/:tracklogId` | Remove tracklog from place |

**Place categories:** mountain, beach, forest, waterfall, temple, city, etc.

### SOS Alerts

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/sos` | Create SOS alert |
| GET | `/api/v1/sos/active` | Get user's active alerts |
| GET | `/api/v1/sos/all` | Get all active alerts (dispatchers) |
| PUT | `/api/v1/sos/:id/resolve` | Resolve/cancel alert |

### Presence

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/presence/nearby` | Get nearby users |
| POST | `/api/v1/presence/location` | Update my location |
| WS | `/ws/presence` | WebSocket for real-time presence |

## Example Requests

### Register
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123","name":"John Doe"}'
```

### Login
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'
```

### Check Confirmation Status
```bash
curl http://localhost:3000/api/v1/auth/confirm/status?user_id=USER_UUID
```

### Verify Token
```bash
curl -X POST http://localhost:3000/api/v1/auth/verify \
  -H "Content-Type: application/json" \
  -d '{"token":"YOUR_SUPABASE_TOKEN"}'
```

### Create Tracklog (with JWT)
```bash
curl -X POST http://localhost:3000/api/v1/tracklogs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"title":"Morning Trek","started_at":"2024-01-15T06:00:00Z","distance_meters":5000}'
```

### Get Popular Places
```bash
curl http://localhost:3000/api/v1/places/popular?limit=10&category=mountain
```

### Get Place Tracklogs
```bash
curl http://localhost:3000/api/v1/places/PLACE_ID/tracklogs?limit=20
```

### Send SOS Alert
```bash
curl -X POST http://localhost:3000/api/v1/sos \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"message":"Need help","location_lat":10.8231,"location_lng":106.6297}'
```

## Database Schema

See `supabase/schema.sql` for full schema including:

**Tables:**
- `users` - User profiles
- `tracklogs` - GPS track data
- `places` - Famous attractions/POIs
- `place_tracklogs` - Junction for tracklog-place associations
- `sos_alerts` - Emergency alerts
- `user_locations` - Presence tracking
- `tracklog_imports` - Import history
- `tracklog_categories` - Hierarchical categories
- `tracklog_tags` - Many-to-many tags
- `tracklog_admin` - Moderation queue

**Views:**
- `v_public_tracklogs` - Public feed with ratings
- `v_tracklog_stats` - Per-user aggregated stats
- `v_nearby_tracklogs` - Map viewport queries
- `v_places_with_stats` - Places with tracklog count

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUPABASE_URL` | Supabase project URL | ✅ |
| `SUPABASE_KEY` | Supabase anon/public key | ✅ |
| `JWT_SECRET` | Secret for JWT signing | ✅ |
| `FRONTEND_URL` | Frontend URL for redirects | ✅ |
| `PORT` | Server port (default: 3000) | ❌ |
| `HOST` | Server host (default: 0.0.0.0) | ❌ |

## License

MIT