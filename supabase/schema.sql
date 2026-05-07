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

-- ============================================
-- PHASE 2: Tracklog Import History
-- ============================================
CREATE TABLE IF NOT EXISTS public.tracklog_imports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tracklog_id UUID NOT NULL REFERENCES public.tracklogs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    source TEXT NOT NULL CHECK (source IN ('gpx', 'kml', 'url', 'manual')),
    original_filename TEXT,
    imported_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'success' CHECK (status IN ('success', 'failed')),
    error_message TEXT
);

-- ============================================
-- PHASE 2: Tracklog Categories (hierarchical)
-- ============================================
CREATE TABLE IF NOT EXISTS public.tracklog_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    color TEXT, -- hex color code
    parent_id UUID REFERENCES public.tracklog_categories(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- PHASE 2: Tracklog Tags (many-to-many)
-- ============================================
CREATE TABLE IF NOT EXISTS public.tracklog_tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Junction table for tracklog-tag relationship
CREATE TABLE IF NOT EXISTS public.tracklog_category_items (
    tracklog_id UUID NOT NULL REFERENCES public.tracklogs(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.tracklog_categories(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (tracklog_id, category_id)
);

-- Junction table for tracklog-tag relationship
CREATE TABLE IF NOT EXISTS public.tracklog_tag_items (
    tracklog_id UUID NOT NULL REFERENCES public.tracklogs(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES public.tracklog_tags(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (tracklog_id, tag_id)
);

-- ============================================
-- PHASE 2: Tracklog Admin/Moderation
-- ============================================
CREATE TABLE IF NOT EXISTS public.tracklog_admin (
    tracklog_id UUID PRIMARY KEY REFERENCES public.tracklogs(id) ON DELETE CASCADE,
    reviewed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    featured BOOLEAN DEFAULT FALSE,
    featured_at TIMESTAMPTZ,
    notes TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- PHASE 3: Places (attractions/POIs)
-- ============================================
CREATE TABLE IF NOT EXISTS public.places (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    category TEXT, -- mountain, beach, forest, waterfall, temple, etc.
    image_url TEXT,
    popularity_score INT DEFAULT 0,
    is_featured BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Junction: tracklogs associated with a place
CREATE TABLE IF NOT EXISTS public.place_tracklogs (
    place_id UUID NOT NULL REFERENCES public.places(id) ON DELETE CASCADE,
    tracklog_id UUID NOT NULL REFERENCES public.tracklogs(id) ON DELETE CASCADE,
    PRIMARY KEY (place_id, tracklog_id)
);

-- ============================================
-- Additional Tables for Ratings/Reviews
-- ============================================
CREATE TABLE IF NOT EXISTS public.track_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tracklog_id UUID NOT NULL REFERENCES public.tracklogs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (tracklog_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.track_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tracklog_id UUID NOT NULL REFERENCES public.tracklogs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    review TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (tracklog_id, user_id)
);

-- ============================================
-- Indexes for performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_tracklogs_user_id ON public.tracklogs(user_id);
CREATE INDEX IF NOT EXISTS idx_tracklogs_public ON public.tracklogs(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_tracklogs_created_at ON public.tracklogs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sos_alerts_status ON public.sos_alerts(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_sos_alerts_user_id ON public.sos_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_locations_updated ON public.user_locations(updated_at DESC);

-- Import history indexes
CREATE INDEX IF NOT EXISTS idx_tracklog_imports_tracklog_id ON public.tracklog_imports(tracklog_id);
CREATE INDEX IF NOT EXISTS idx_tracklog_imports_user_id ON public.tracklog_imports(user_id);
CREATE INDEX IF NOT EXISTS idx_tracklog_imports_source ON public.tracklog_imports(source);

-- Category indexes
CREATE INDEX IF NOT EXISTS idx_tracklog_categories_parent ON public.tracklog_categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_tracklog_category_items_category ON public.tracklog_category_items(category_id);

-- Tag indexes
CREATE INDEX IF NOT EXISTS idx_tracklog_tag_items_tag ON public.tracklog_tag_items(tag_id);

-- Admin indexes
CREATE INDEX IF NOT EXISTS idx_tracklog_admin_status ON public.tracklog_admin(status);
CREATE INDEX IF NOT EXISTS idx_tracklog_admin_featured ON public.tracklog_admin(featured) WHERE featured = true;

-- Places indexes
CREATE INDEX IF NOT EXISTS idx_places_category ON public.places(category);
CREATE INDEX IF NOT EXISTS idx_places_popularity ON public.places(popularity_score DESC);
CREATE INDEX IF NOT EXISTS idx_places_featured ON public.places(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_place_tracklogs_tracklog ON public.place_tracklogs(tracklog_id);

-- Ratings/Reviews indexes
CREATE INDEX IF NOT EXISTS idx_track_ratings_tracklog_id ON public.track_ratings(tracklog_id);
CREATE INDEX IF NOT EXISTS idx_track_ratings_user_id ON public.track_ratings(user_id);
CREATE INDEX IF NOT EXISTS idx_track_reviews_tracklog_id ON public.track_reviews(tracklog_id);

-- ============================================
-- Client-facing Views (read-only, optimized)
-- ============================================

-- v_public_tracklogs: Public tracklogs with metadata and author name
CREATE OR REPLACE VIEW public.v_public_tracklogs AS
SELECT 
    t.id,
    t.title,
    t.description,
    t.started_at,
    t.ended_at,
    t.distance_meters,
    t.elevation_gain,
    t.elevation_loss,
    t.created_at,
    t.user_id,
    u.name AS author_name,
    COALESCE(AVG(tr.rating), 0) AS avg_rating,
    COUNT(DISTINCT tr.id) AS review_count
FROM public.tracklogs t
JOIN public.users u ON t.user_id = u.id
LEFT JOIN public.track_ratings tr ON t.id = tr.tracklog_id
WHERE t.is_public = true
GROUP BY t.id, t.title, t.description, t.started_at, t.ended_at, t.distance_meters, 
         t.elevation_gain, t.elevation_loss, t.created_at, t.user_id, u.name;

-- v_tracklog_stats: Aggregated stats per user
CREATE OR REPLACE VIEW public.v_tracklog_stats AS
SELECT 
    user_id,
    COUNT(*) AS total_tracklogs,
    COALESCE(SUM(distance_meters), 0) AS total_distance_meters,
    COALESCE(SUM(elevation_gain), 0) AS total_elevation_gain,
    COALESCE(AVG(distance_meters), 0) AS avg_distance_meters,
    MAX(started_at) AS last_trek_date
FROM public.tracklogs
WHERE is_public = true
GROUP BY user_id;

-- v_nearby_tracklogs: Tracklogs within bounding box (for map viewport)
-- Usage: SELECT * FROM v_nearby_tracklogs WHERE bbox && ST_MakeEnvelope(106.5, 10.8, 107.0, 11.0);
-- Note: Requires PostGIS extension for proper geospatial queries
CREATE OR REPLACE VIEW public.v_nearby_tracklogs AS
SELECT 
    t.id,
    t.title,
    t.description,
    t.started_at,
    t.distance_meters,
    t.elevation_gain,
    t.user_id,
    u.name AS author_name
FROM public.tracklogs t
JOIN public.users u ON t.user_id = u.id
WHERE t.is_public = true;

-- v_places_with_stats: Places with tracklog count
CREATE OR REPLACE VIEW public.v_places_with_stats AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.latitude,
    p.longitude,
    p.category,
    p.image_url,
    p.popularity_score,
    p.is_featured,
    COUNT(pt.tracklog_id) AS tracklog_count
FROM public.places p
LEFT JOIN public.place_tracklogs pt ON p.id = pt.place_id
GROUP BY p.id, p.name, p.description, p.latitude, p.longitude, p.category, p.image_url, p.popularity_score, p.is_featured;

-- ============================================
-- Row Level Security (RLS) - Critical for security
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracklogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sos_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracklog_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracklog_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracklog_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracklog_category_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracklog_tag_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracklog_admin ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_tracklogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.track_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.track_reviews ENABLE ROW LEVEL SECURITY;

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

-- Tracklog imports: owner can manage
CREATE POLICY "Users can manage own imports" ON public.tracklog_imports
    FOR ALL USING (auth.uid() = user_id);

-- Categories: readable by all, only admin can modify (extend as needed)
CREATE POLICY "Categories readable by all" ON public.tracklog_categories
    FOR SELECT USING (true);

-- Tags: readable by all, authenticated can create
CREATE POLICY "Tags readable by all" ON public.tracklog_tags
    FOR SELECT USING (true);

CREATE POLICY "Authenticated can create tags" ON public.tracklog_tags
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Category items: owner tracklog can manage
CREATE POLICY "Manage category items" ON public.tracklog_category_items
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.tracklogs WHERE id = tracklog_id AND user_id = auth.uid())
    );

-- Tag items: owner tracklog can manage
CREATE POLICY "Manage tag items" ON public.tracklog_tag_items
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.tracklogs WHERE id = tracklog_id AND user_id = auth.uid())
    );

-- Admin: only admins can modify (basic setup)
CREATE POLICY "Admin readable by all" ON public.tracklog_admin
    FOR SELECT USING (true);

-- Places: readable by all
CREATE POLICY "Places readable by all" ON public.places
    FOR SELECT USING (true);

-- Place tracklogs: readable by all, owner can manage
CREATE POLICY "Place tracklogs readable by all" ON public.place_tracklogs
    FOR SELECT USING (true);

CREATE POLICY "Users can manage own place tracklogs" ON public.place_tracklogs
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.tracklogs WHERE id = tracklog_id AND user_id = auth.uid())
    );

-- Ratings/Reviews: readable by all, owner can manage
CREATE POLICY "Users can read track ratings" ON public.track_ratings
    FOR SELECT USING (true);

CREATE POLICY "Users can manage own ratings" ON public.track_ratings
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can read track reviews" ON public.track_reviews
    FOR SELECT USING (true);

CREATE POLICY "Users can manage own reviews" ON public.track_reviews
    FOR ALL USING (auth.uid() = user_id);

-- Views are read-only by default, no RLS needed

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