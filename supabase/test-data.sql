-- =============================================================================
-- TEST DATA SETUP SCRIPT FOR TREKTRACK
-- Run this in Supabase SQL Editor to set up test user and sample tracklogs
-- =============================================================================

-- IMPORTANT: This script is for TESTING ONLY
-- Creates a pre-confirmed user and sample data for development

-- 1. Create test user (bypass email confirmation by setting email_confirm = true)
-- This creates a confirmed user in auth.users
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    raw_user_meta_data
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890', -- predefined UUID for testing
    'authenticated',
    'authenticated',
    'trektrack_test@gmail.com',
    '$2a$10$abcdefghijklmnopqrstuvwxyz', -- placeholder hash (won't work for login)
    NOW(),
    NOW(),
    NOW(),
    '{"name": "Test User", "phone": "0987654321"}'::jsonb
) ON CONFLICT (email) DO NOTHING;

-- 2. Create user profile in public.users table
INSERT INTO public.users (
    id,
    name,
    phone,
    emergency_contact_name,
    emergency_contact_phone,
    created_at,
    updated_at
) VALUES (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Test User',
    '0987654321',
    'Emergency Contact',
    '0912345678',
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- 3. Insert sample tracklogs for testing map display
INSERT INTO public.tracklogs (
    id,
    user_id,
    title,
    description,
    started_at,
    ended_at,
    distance_meters,
    elevation_gain,
    elevation_loss,
    is_public,
    created_at,
    updated_at
) VALUES
-- Núi Bà Đen (Tây Ninh) - famous mountain
(
    'b1c2d3e4-f5a6-4890-bcde-f12345678901',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Leo Núi Bà Đen - Tây Ninh',
    'Chuyến trek lên đỉnh núi Bà Đen - ngày nắng đẹp, view tuyệt vời 360°',
    '2024-03-15 06:30:00+07',
    '2024-03-15 10:45:00+07',
    8400,
    680,
    675,
    true,
    NOW(),
    NOW()
),

-- Bãi Biển Mũi Né - Phan Thiết
(
    'c2d3e4f5-a6b7-4901-cdef-123456789012',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Chạy bộ bờ biển Mũi Né',
    'Buổi sáng chạy dọc bờ biển Mũi Né, cát trắng mịn',
    '2024-03-10 06:00:00+07',
    '2024-03-10 07:30:00+07',
    5200,
    15,
    12,
    true,
    NOW(),
    NOW()
),

-- Rừng Cần Giờ - TP.HCM
(
    'd3e4f5a6-b7c8-4902-def1-234567890123',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Khám phá rừng Cần Giờ',
    'Kayaking và đi bộ trong rừng ngập mặn Cần Giờ',
    '2024-03-05 08:00:00+07',
    '2024-03-05 15:00:00+07',
    12000,
    25,
    28,
    true,
    NOW(),
    NOW()
),

-- Đồng Văn - Tà Pa (Núi rừng Tây Bắc)
(
    'e4f5a6b7-c8d9-4903-ef12-345678901234',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Trek Đồng Văn - Hà Giang',
    'Cuối tuần khám phá cao nguyên đá Đồng Văn, những cảnh quan hùng vĩ',
    '2024-02-20 07:00:00+07',
    '2024-02-20 17:00:00+07',
    15600,
    950,
    940,
    true,
    NOW(),
    NOW()
),

-- Bản Giốc - Cao Bằng (thác)
(
    'f5a6b7c8-d9e0-4904-f123-456789012345',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Thác Bản Giốc - Cao Bằng',
    'Đi bộ quanh thác Bản Giốc và khu vực lân cận',
    '2024-02-15 09:00:00+07',
    '2024-02-15 16:00:00+07',
    6800,
    180,
    175,
    true,
    NOW(),
    NOW()
);

-- 4. Insert sample places (attractions/POIs)
INSERT INTO public.places (
    id,
    name,
    description,
    latitude,
    longitude,
    category,
    popularity_score,
    is_featured,
    created_at,
    updated_at
) VALUES
(
    'p1111111-1111-4111-a111-111111111111',
    'Núi Bà Đen',
    'Đỉnh núi cao nhất Tây Ninh (986m), có khu du lịch và chùa Bà Đen nổi tiếng',
    11.3500,
    106.1333,
    'mountain',
    95,
    true,
    NOW(),
    NOW()
),
(
    'p2222222-2222-4222-a222-222222222222',
    'Mũi Né Beach',
    'Bãi biển đẹp ở Phan Thiết, nổi tiếng với cát trắng và đi bộ dọc bờ',
    10.9500,
    108.2833,
    'beach',
    88,
    true,
    NOW(),
    NOW()
),
(
    'p3333333-3333-4333-a333-333333333333',
    'Cần Giờ Mangrove',
    'Khu dự trữ sinh quyển rừng ngập mặn ven sông Sài Gòn',
    10.6000,
    106.8167,
    'forest',
    75,
    false,
    NOW(),
    NOW()
),
(
    'p4444444-4444-4444-a444-444444444444',
    'Đồng Văn Plateau',
    'Cao nguyên đá với cảnh quan núi non hùng vĩ ở Hà Giang',
    23.0833,
    105.0167,
    'mountain',
    92,
    true,
    NOW(),
    NOW()
),
(
    'p5555555-5555-4555-a555-555555555555',
    'Thác Bản Giốc',
    'Thác nước lớn nhất Việt Nam, nằm ở Cao Bằng giáp với Trung Quốc',
    22.8500,
    106.7167,
    'waterfall',
    90,
    true,
    NOW(),
    NOW()
);

-- 5. Link tracklogs to places
INSERT INTO public.place_tracklogs (place_id, tracklog_id) VALUES
('p1111111-1111-4111-a111-111111111111', 'b1c2d3e4-f5a6-4890-bcde-f12345678901'),
('p2222222-2222-4222-a222-222222222222', 'c2d3e4f5-a6b7-4901-cdef-123456789012'),
('p3333333-3333-4333-a333-333333333333', 'd3e4f5a6-b7c8-4902-def1-234567890123'),
('p4444444-4444-4444-a444-444444444444', 'e4f5a6b7-c8d9-4903-ef12-345678901234'),
('p5555555-5555-4555-a555-555555555555', 'f5a6b7c8-d9e0-4904-f123-456789012345');

-- 6. Insert user locations for presence testing
INSERT INTO public.user_locations (
    user_id,
    latitude,
    longitude,
    accuracy,
    heading,
    speed,
    updated_at
) VALUES
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    10.8231,
    106.6297,
    10.5,
    45.0,
    0.0,
    NOW()
);

-- =============================================================================
-- VERIFICATION QUERIES - Run these to confirm data was inserted
-- =============================================================================
-- SELECT * FROM public.users;
-- SELECT * FROM public.tracklogs;
-- SELECT * FROM public.places;
-- SELECT * FROM public.place_tracklogs;
-- SELECT * FROM public.user_locations;

-- For frontend testing, you can use this user ID directly:
-- User ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
-- Email: trektrack_test@gmail.com (login via Supabase Auth console)