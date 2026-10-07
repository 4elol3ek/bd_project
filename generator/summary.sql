SELECT current_schema() AS dataset_schema,
  obj_description(current_schema()::regnamespace, 'pg_namespace') AS parameters;

SELECT 'news' AS table_name, count(*) AS rows FROM news
UNION ALL SELECT 'import_result', count(*) FROM import_result
UNION ALL SELECT 'news_category', count(*) FROM news_category
UNION ALL SELECT 'app_user', count(*) FROM app_user
UNION ALL SELECT 'favorite', count(*) FROM favorite
UNION ALL SELECT 'scrape_run', count(*) FROM scrape_run
UNION ALL SELECT 'scrape_error_log', count(*) FROM scrape_error_log
ORDER BY rows DESC, table_name;

SELECT status, count(*) AS rows FROM import_result GROUP BY status ORDER BY status;
SELECT status, count(*) AS rows FROM news_source GROUP BY status ORDER BY status;
SELECT status, count(*) AS rows FROM scrape_run GROUP BY status ORDER BY status;

SELECT CASE WHEN source_id <= 5 THEN '01: top 5 sources'
            WHEN source_id <= 30 THEN '02: sources 6-30'
            ELSE '03: sources 31-100' END AS source_group,
  count(*) AS news_count, round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS percent
FROM news GROUP BY source_group ORDER BY source_group;

SELECT c.name, count(*) AS news_count
FROM news_category nc JOIN category c ON c.id = nc.category_id
GROUP BY c.id, c.name ORDER BY news_count DESC, c.id;

SELECT CASE WHEN published_at >= TIMESTAMPTZ '2026-10-01 00:00:00+00' - INTERVAL '7 days'
              THEN '01: last 7 days'
            WHEN published_at >= TIMESTAMPTZ '2026-10-01 00:00:00+00' - INTERVAL '30 days'
              THEN '02: 7-30 days'
            ELSE '03: 30-365 days' END AS age_group,
  count(*) AS news_count, round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS percent
FROM news GROUP BY age_group ORDER BY age_group;
