\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO public, pg_catalog;
\ir sql/seed/report_test.sql
COMMIT;
\echo 'Seed loaded.'