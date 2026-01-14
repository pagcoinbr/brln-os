-- BRLN-OS Atomic Swap Module - Database Initialization Script
-- This script creates initial extensions and schemas for the swap database

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- For UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- For cryptographic functions

-- Create schema for swap module (optional - can use public schema)
-- CREATE SCHEMA IF NOT EXISTS brln_swap;
-- SET search_path TO brln_swap, public;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE brln_swaps TO brln_swap_user;

-- Note: Tables will be created via Alembic migrations
-- This file is just for initial setup and extensions
