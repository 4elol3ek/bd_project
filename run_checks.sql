-- New audit runner, not recovered from the report (only its name was present there).
-- Everything runs in a fresh schema within a transaction. No production table is used.
\set ON_ERROR_STOP on
\pset pager off
\set QUIET on
\o /dev/null
\echo AUDIT_BEGIN
BEGIN;
CREATE SCHEMA bd_labs_audit;
SET LOCAL search_path = bd_labs_audit, pg_catalog;
\ir migrations/001_init.up.sql
\ir migrations/002_add_scrape_run_status_check.up.sql
\ir tests/checks.sql
\o
\set QUIET off
SELECT id, kind, name, verdict, observed FROM audit_results ORDER BY id;
SELECT verdict, count(*) FROM audit_results GROUP BY verdict ORDER BY verdict;
SELECT bool_and(verdict = 'PASS') AS audit_ok FROM audit_results \gset
ROLLBACK;
\if :audit_ok
  \echo AUDIT_PASS: original behavior matches the recorded audit expectations; schema rolled back
\else
  \echo AUDIT_FAIL: unexpected behavior; schema rolled back
  DO $$ BEGIN RAISE EXCEPTION 'Audit expectations failed'; END $$;
\endif
