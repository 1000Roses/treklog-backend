-- TrekTrack Backend - Supabase Schema
-- Run this in Supabase SQL Editor to set up the database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT,
    phone TEXT,
    avatar_url TEXT,
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tracklogs table
CREATE TABLE IF NOT EXISTS public.tracklogs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    distance_meters FLOAT DEFAULT 0,
    elevation_gain FLOAT DEFAULT 0,
    elevation_loss FLOAT DEFAULT 0,
    gpx_data TEXT, -- GPX/KML data as text
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SOS Alerts table
CREATE TABLE IF NOT EXISTS public.sos_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message TEXT,
    location_lat FLOAT,
    location_lng FLOAT,
    severity TEXT DEFAULT 'high', -- low, medium, high, critical
    status TEXT DEFAULT 'active', -- active, acknowledged, resolved
    resolution_notes TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User locations (for presence tracking)
CREATE TABLE IF NOT EXISTS public.user_locations (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    accuracy FLOAT,
    heading FLOAT,
    speed FLOAT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_tracklogs_user_id ON public.tracklogs(user_id);
CREATE INDEX IF NOT EXISTS idx_tracklogs_public ON public.tracklogs(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_sos_alerts_status ON public.sos_alerts(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_sos_alerts_user_id ON public.sos_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_locations_updated ON public.user_locations(updated_at DESC);

-- Row Level Security (RLS) - Critical for security

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracklogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sos_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_locations ENABLE ROW LEVEL SECURITY;

-- Users: users can read all, update only their own
CREATE POLICY "Users readable by all authenticated" ON public.users
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- Tracklogs: owner can do all, public tracks readable by all
CREATE POLICY "Users can read own tracklogs" ON public.tracklogs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can read public tracklogs" ON public.tracklogs
    FOR SELECT USING (is_public = true);

CREATE POLICY "Users can insert own tracklogs" ON public.tracklogs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tracklogs" ON public.tracklogs
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own tracklogs" ON public.tracklogs
    FOR DELETE USING (auth.uid() = user_id);

-- SOS: users can create, read own, authorities can read all active
CREATE POLICY "Users can create sos alerts" ON public.sos_alerts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own sos alerts" ON public.sos_alerts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own sos alerts" ON public.sos_alerts
    FOR UPDATE USING (auth.uid() = user_id);

-- User locations: only own location readable/writable
CREATE POLICY "Users can manage own location" ON public.user_locations
    FOR ALL USING (auth.uid() = user_id);

-- Function to auto-create user record on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, name, phone)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
        NEW.raw_user_meta_data->>'phone'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create user
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Allow authenticated users to read other users' basic info
CREATE POLICY "Authenticated users can read other users info" ON public.users
    FOR SELECT USING (auth.role() = 'authenticated');