-- ============================================================
-- MIGRATION 001: Extensions
-- Enable required PostgreSQL extensions before any table
-- definitions that reference their types or functions.
-- All statements are idempotent (safe to re-run).
-- ============================================================

-- PostGIS: geospatial types (GEOGRAPHY, GEOMETRY) and functions
-- (ST_DWithin, ST_Distance, ST_MakePoint, etc.)
-- Required by collection_points.location and get_nearest_collection_points().
CREATE EXTENSION IF NOT EXISTS postgis;

-- pgcrypto: gen_random_uuid() fallback for environments where
-- uuid-ossp is not pre-installed.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- uuid-ossp: already enabled on Supabase by default, but declared
-- explicitly so local Docker dev (supabase/postgres image) is reproducible.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
