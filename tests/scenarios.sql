SELECT check_that('User lifecycle: the created account was updated',
  (SELECT count(*) = 1 FROM app_user WHERE email = 'updated.user@example.com')
  AND NOT EXISTS (SELECT 1 FROM app_user WHERE email = 'new.user@example.com')
  AND (SELECT count(*) = 4 FROM app_user)
);

SELECT check_that('Source lifecycle: separate failures remain in history; source recovered',
  (SELECT status = 'активен' FROM news_source WHERE url = 'https://example.com/rss')
  AND (SELECT count(*) = 3 FROM scrape_run r JOIN news_source s ON s.id = r.source_id
       WHERE s.url = 'https://example.com/rss' AND r.status = 'ошибка')
  AND NOT EXISTS (SELECT 1 FROM scrape_run WHERE status = 'запущен')
  AND (SELECT status = 'ошибка подключения' FROM news_source WHERE url = 'https://globalnews.example/feed')
);

SELECT check_that('News lifecycle: success, duplicate and error preserve one classified news',
  (SELECT count(*) = 1 FROM news WHERE canonical_url = 'https://example.com/news/123')
  AND NOT EXISTS (SELECT 1 FROM news WHERE canonical_url = 'https://example.com/news/invalid')
  AND (SELECT count(*) = 3 FROM import_result i JOIN scrape_run r ON r.id = i.scrape_run_id
       JOIN news_source s ON s.id = r.source_id WHERE s.url = 'https://example.com/rss')
  AND (SELECT count(DISTINCT i.status) = 3 FROM import_result i JOIN scrape_run r ON r.id = i.scrape_run_id
       JOIN news_source s ON s.id = r.source_id WHERE s.url = 'https://example.com/rss')
  AND EXISTS (SELECT 1 FROM news n JOIN news_category nc ON nc.news_id = n.id
              JOIN category c ON c.id = nc.category_id
              WHERE n.canonical_url = 'https://example.com/news/123' AND c.name = 'Спорт')
  AND NOT EXISTS (SELECT 1 FROM import_result i JOIN scrape_run r ON r.id = i.scrape_run_id
                 JOIN news n ON n.id = i.news_id WHERE r.source_id <> n.source_id)
);

SELECT check_that('Every saved news has a category; service category is never mixed',
  NOT EXISTS (SELECT 1 FROM news n WHERE NOT EXISTS (SELECT 1 FROM news_category nc WHERE nc.news_id = n.id))
  AND NOT EXISTS (
    SELECT 1 FROM news_category nc JOIN category c ON c.id = nc.category_id
    WHERE c.name = 'Без категории'
      AND EXISTS (SELECT 1 FROM news_category other WHERE other.news_id = nc.news_id AND other.category_id <> nc.category_id)
  )
);

DO $$
DECLARE
  v_category_id integer;
  v_subscriptions bigint;
  v_assignments bigint;
BEGIN
  SELECT id INTO STRICT v_category_id FROM category WHERE name = 'Спорт';
  SELECT count(*) INTO v_subscriptions FROM subscription_category WHERE category_id = v_category_id;
  SELECT count(*) INTO v_assignments FROM news_category WHERE category_id = v_category_id;
  UPDATE category SET is_active = false WHERE id = v_category_id;
  PERFORM check_that('Disabling category preserves subscriptions and news assignments',
    v_subscriptions > 0 AND v_assignments > 0
    AND (SELECT count(*) = v_subscriptions FROM subscription_category WHERE category_id = v_category_id)
    AND (SELECT count(*) = v_assignments FROM news_category WHERE category_id = v_category_id)
  );
  UPDATE category SET is_active = true WHERE id = v_category_id;
END;
$$;
