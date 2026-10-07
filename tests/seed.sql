-- Ensure natural-key joins did not silently omit a seed row.
DO $$
DECLARE
  item record;
  actual_count bigint;
BEGIN
  FOR item IN SELECT * FROM (VALUES
    ('role', 3), ('app_user', 3), ('category', 5), ('news_source', 5),
    ('news', 5), ('news_category', 6), ('scrape_run', 4), ('import_result', 6),
    ('scrape_error_log', 1), ('subscription_category', 3),
    ('subscription_source', 2), ('favorite', 3)
  ) AS counts(table_name, expected_count) LOOP
    EXECUTE format('SELECT count(*) FROM %I', item.table_name) INTO actual_count;
    IF actual_count <> item.expected_count THEN
      RAISE EXCEPTION 'FAIL: seed %, expected % rows, got %',
        item.table_name, item.expected_count, actual_count;
    END IF;
  END LOOP;
  PERFORM check_that('Seed: all 12 tables contain the complete demo dataset', true);
END;
$$;

SELECT check_that('Seed: import statuses, news links and sources agree', NOT EXISTS (
  SELECT 1 FROM import_result i
  JOIN scrape_run r ON r.id = i.scrape_run_id
  LEFT JOIN news n ON n.id = i.news_id
  WHERE (i.status = 'успех' AND i.news_id IS NULL)
     OR (i.status <> 'успех' AND i.news_id IS NOT NULL)
     OR (i.news_id IS NOT NULL AND n.source_id <> r.source_id)
));

SELECT check_that('Seed: every saved news row has one successful import', NOT EXISTS (
  SELECT 1 FROM news n
  WHERE (SELECT count(*) FROM import_result i WHERE i.news_id = n.id AND i.status = 'успех') <> 1
));
