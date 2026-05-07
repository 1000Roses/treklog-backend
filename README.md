# TrekTrack Backend

Backend API for TrekTrack - trekking & safety platform. Built with Fastify + Supabase.

## Features

- **Auth**: JWT-based authentication via Supabase Auth
- **Tracklogs**: Import/manage GPX tracks with metadata
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
```

### 3. Setup Supabase Database

1. Go to your Supabase project → SQL Editor
2. Copy-paste contents of `supabase/schema.sql`
3. Run the script

This creates:
- `users` table
- `tracklogs` table
- `sos_alerts` table
- `user_locations` table
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
| GET | `/api/v1/auth/me` | Get current user profile |
| PUT | `/api/v1/auth/me` | Update profile |

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

### Create Tracklog (with JWT)
```bash
curl -X POST http://localhost:3000/api/v1/tracklogs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"title":"Morning Trek","started_at":"2024-01-15T06:00:00Z","distance_meters":5000}'
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
- Table definitions
- Indexes for performance
- Row Level Security (RLS) policies
- Auto-create user trigger

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUPABASE_URL` | Supabase project URL | ✅ |
| `SUPABASE_KEY` | Supabase anon/public key | ✅ |
| `JWT_SECRET` | Secret for JWT signing | ✅ |
| `PORT` | Server port (default: 3000) | ❌ |
| `HOST` | Server host (default: 0.0.0.0) | ❌ |

## License

MIT