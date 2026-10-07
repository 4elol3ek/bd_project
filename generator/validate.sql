-- Critical cross-table invariants; PK/FK/UNIQUE/NOT NULL/CHECK stay enabled.
DO $$
DECLARE
  cfg record;
  expected record;
  actual bigint;
BEGIN
  SELECT * INTO STRICT cfg FROM generation_config;
  IF cfg.mode IS NULL OR cfg.mode NOT IN ('dev', 'load')
     OR cfg.seed IS NULL OR cfg.seed NOT BETWEEN 0 AND 2147483647
     OR cfg.news_count IS DISTINCT FROM (CASE cfg.mode WHEN 'dev' THEN 80000::bigint ELSE 3000000::bigint END)
     OR cfg.user_count IS DISTINCT FROM (CASE cfg.mode WHEN 'dev' THEN 10000::bigint ELSE 100000::bigint END)
     OR cfg.reference_time IS DISTINCT FROM TIMESTAMPTZ '2026-10-01 00:00:00+00'
  THEN RAISE EXCEPTION 'Missing or incompatible generator parameters'; END IF;
  FOR expected IN SELECT * FROM (VALUES
    ('role', 3::bigint), ('category', 16::bigint), ('news_source', 100::bigint),
    ('app_user', cfg.user_count), ('news', cfg.news_count),
    ('news_category', cfg.news_count), ('scrape_run', 36543::bigint),
    ('import_result', cfg.news_count * 110 / 100),
    ('scrape_error_log', cfg.news_count * 2 / 100 + 35),
    ('subscription_category', cfg.user_count * 16 / 10),
    ('subscription_source', cfg.user_count * 14 / 10),
    ('favorite', cfg.user_count * 52 / 10)
  ) AS counts(table_name, row_count) LOOP
    EXECUTE format('SELECT count(*) FROM %I', expected.table_name) INTO actual;
    IF actual <> expected.row_count THEN
      RAISE EXCEPTION '%: expected % rows, got %', expected.table_name, expected.row_count, actual;
    END IF;
  END LOOP;

  IF EXISTS (SELECT 1 FROM news n WHERE NOT EXISTS (
    SELECT 1 FROM news_category nc WHERE nc.news_id = n.id
  )) THEN RAISE EXCEPTION 'A publication has no category'; END IF;

  IF EXISTS (SELECT 1 FROM news_category nc WHERE nc.category_id = 1 AND EXISTS (
    SELECT 1 FROM news_category other WHERE other.news_id = nc.news_id AND other.category_id <> 1
  )) THEN RAISE EXCEPTION 'Service category mixed with ordinary categories'; END IF;

  IF EXISTS (SELECT 1 FROM import_result i
    LEFT JOIN news n ON n.id = i.news_id JOIN scrape_run r ON r.id = i.scrape_run_id
    WHERE (i.status = 'успех' AND (n.id IS NULL OR n.source_id <> r.source_id OR n.published_at > r.started_at))
       OR (i.status <> 'успех' AND i.news_id IS NOT NULL)
       OR r.status <> 'завершен'
  ) THEN RAISE EXCEPTION 'Import status, source or collection date is inconsistent'; END IF;

  IF EXISTS (SELECT 1 FROM news n WHERE NOT EXISTS (
    SELECT 1 FROM import_result i WHERE i.news_id = n.id AND i.status = 'успех'
  )) THEN RAISE EXCEPTION 'A publication has no successful import'; END IF;

  IF (SELECT count(*) FROM import_result WHERE status = 'дубликат') <> cfg.news_count * 8 / 100
     OR (SELECT count(*) FROM import_result WHERE status = 'ошибка') <> cfg.news_count * 2 / 100
  THEN RAISE EXCEPTION 'Unexpected import status distribution'; END IF;

  IF EXISTS (SELECT 1 FROM import_result i WHERE i.status = 'ошибка' AND NOT EXISTS (
    SELECT 1 FROM scrape_error_log e WHERE e.scrape_run_id = i.scrape_run_id
  )) OR EXISTS (SELECT 1 FROM scrape_run r WHERE r.status = 'ошибка' AND NOT EXISTS (
    SELECT 1 FROM scrape_error_log e WHERE e.scrape_run_id = r.id
  )) THEN RAISE EXCEPTION 'An error has no log entry'; END IF;

  IF EXISTS (SELECT 1 FROM scrape_error_log e JOIN scrape_run r ON r.id = e.scrape_run_id
    WHERE e.created_at < r.started_at OR e.created_at > cfg.reference_time
  ) OR EXISTS (SELECT 1 FROM news WHERE published_at >= cfg.reference_time)
  THEN RAISE EXCEPTION 'Publication or error timestamp is inconsistent'; END IF;

  IF EXISTS (SELECT 1 FROM subscription_category sc JOIN category c ON c.id = sc.category_id
    WHERE NOT c.is_active OR c.id = 1
  ) OR EXISTS (SELECT 1 FROM subscription_source ss JOIN news_source s ON s.id = ss.source_id
    WHERE s.status <> 'активен'
  ) THEN RAISE EXCEPTION 'A new subscription targets a disabled or service object'; END IF;

  IF EXISTS (SELECT 1 FROM app_user WHERE role_id = 1) THEN
    RAISE EXCEPTION 'Guests must not have registered accounts';
  END IF;

  IF EXISTS (SELECT 1 FROM news_source s WHERE
    (s.status = 'неактивен' AND (SELECT count(*) FROM (
      SELECT r.status FROM scrape_run r WHERE r.source_id = s.id
      ORDER BY r.started_at DESC, r.id DESC LIMIT 3
    ) recent WHERE recent.status = 'ошибка') <> 3)
    OR (s.status = 'ошибка подключения' AND (SELECT r.status FROM scrape_run r
      WHERE r.source_id = s.id ORDER BY r.started_at DESC, r.id DESC LIMIT 1) <> 'ошибка')
  ) THEN RAISE EXCEPTION 'Source status disagrees with recent connection failures'; END IF;

  RAISE NOTICE 'PASS: counts, classification, imports, source history, subscriptions and dates';
END;
$$;
