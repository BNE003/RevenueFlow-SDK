-- =====================================================
-- RevenueFlow Database Reset - Force Delete
-- =====================================================
-- This script removes all RevenueFlow tables and functions
-- WARNING: This will delete ALL data in these tables!

-- Force drop everything with CASCADE

-- Drop views first
DROP VIEW IF EXISTS user_purchases CASCADE;
DROP VIEW IF EXISTS recent_purchases CASCADE;
DROP VIEW IF EXISTS user_purchase_stats CASCADE;
DROP VIEW IF EXISTS app_purchase_stats CASCADE;
DROP VIEW IF EXISTS daily_purchase_counts CASCADE;
DROP VIEW IF EXISTS purchase_stats_by_app CASCADE;

-- Drop all triggers (ignore errors)
DO $$
BEGIN
    DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    DROP TRIGGER IF EXISTS update_apps_updated_at ON public.apps;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    DROP TRIGGER IF EXISTS on_purchase_grant_access ON public.purchases;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Drop all tables with CASCADE (this removes all dependencies)
DROP TABLE IF EXISTS public.purchases CASCADE;
DROP TABLE IF EXISTS public.apps CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Drop all functions with CASCADE
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at() CASCADE;
DROP FUNCTION IF EXISTS grant_access_on_purchase() CASCADE;
DROP FUNCTION IF EXISTS handle_purchase_access() CASCADE;
DROP FUNCTION IF EXISTS grant_user_access(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS user_has_access(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_user_stats(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_app_stats(TEXT) CASCADE;
DROP FUNCTION IF EXISTS link_purchase_to_profile(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS user_has_purchase(UUID, TEXT) CASCADE;

-- Success message
SELECT 'Database reset complete. All tables, triggers, views and functions removed.' as message;
