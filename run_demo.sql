\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO public, pg_catalog;
\ir sql/seed/report_test.sql
\ir sql/scenarios/01_user.sql
\ir sql/scenarios/02_source.sql
\ir sql/scenarios/03_news.sql
COMMIT;
\echo 'Demo data and three lifecycle scenarios loaded successfully.'
