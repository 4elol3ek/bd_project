\set ON_ERROR_STOP on
BEGIN;
\ir /workspace/migrations/001_init.up.sql
\ir /workspace/migrations/002_add_scrape_run_status_check.up.sql
COMMIT;
