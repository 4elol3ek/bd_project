-- Repeat read-only data validation, e.g. -v mode=load; defaults to dev.
\set ON_ERROR_STOP on
\if :{?mode}
\else
  \set mode dev
\endif
BEGIN;
SET LOCAL timezone TO 'UTC';
SET LOCAL search_path TO :"mode", pg_catalog;
CREATE TEMP TABLE generation_config ON COMMIT DROP AS
SELECT metadata->>'mode' AS mode, (metadata->>'seed')::bigint AS seed,
  (metadata->>'news_count')::bigint AS news_count,
  (metadata->>'user_count')::bigint AS user_count,
  (metadata->>'reference_time')::timestamptz AS reference_time
FROM (SELECT obj_description(oid, 'pg_namespace')::jsonb AS metadata
      FROM pg_namespace WHERE nspname = :'mode' AND :'mode' IN ('dev', 'load')) AS saved;
\ir validate.sql
\ir summary.sql
ROLLBACK;
