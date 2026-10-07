\set ON_ERROR_STOP on
\echo 'Checking migrations and integrity constraints...'

BEGIN;
-- A separate schema avoids changing application rows or identity sequences.
SELECT format('lab_checks_%s', pg_backend_pid()) AS check_schema \gset
CREATE SCHEMA :"check_schema";
SET LOCAL search_path TO :"check_schema", pg_catalog;

\ir migrations/001_init.up.sql
\ir migrations/002_add_scrape_run_status_check.up.sql
\ir tests/integrity.sql

SELECT count(*) AS passed_checks FROM pg_temp.check_results;
ROLLBACK;
\echo 'All checks passed. Test schema and data rolled back.'
