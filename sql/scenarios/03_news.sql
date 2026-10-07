-- Run after 02_source.sql; the seed supplies the categories.
DO $$
DECLARE
  v_source_id integer;
  v_run_id bigint;
  v_news_id bigint;
  v_fallback_id integer;
  v_category_id integer;
  v_bad_column text;
BEGIN
  SELECT id INTO STRICT v_source_id FROM news_source
    WHERE url = 'https://example.com/rss' AND status = 'активен';
  SELECT id INTO STRICT v_fallback_id FROM category
    WHERE name = 'Без категории' AND is_active;
  SELECT id INTO STRICT v_category_id FROM category WHERE name = 'Спорт' AND is_active;
  INSERT INTO scrape_run (source_id, status) VALUES (v_source_id, 'запущен')
    RETURNING id INTO v_run_id;

  -- UNIQUE plus ON CONFLICT makes the URL decision atomic.
  INSERT INTO news (source_id, canonical_url, title, content, published_at)
    VALUES (v_source_id, 'https://example.com/news/123', 'Новая публикация',
            'Текст новости', CURRENT_TIMESTAMP)
    ON CONFLICT (canonical_url) DO NOTHING RETURNING id INTO v_news_id;
  IF v_news_id IS NULL THEN
    INSERT INTO import_result (scrape_run_id, status) VALUES (v_run_id, 'дубликат');
  ELSE
    -- Category assignment and the successful import commit with the news.
    INSERT INTO news_category (news_id, category_id) VALUES (v_news_id, v_fallback_id);
    INSERT INTO import_result (scrape_run_id, news_id, status)
      VALUES (v_run_id, v_news_id, 'успех');

    -- Simulated later manual classification: replace the service category.
    INSERT INTO news_category (news_id, category_id) VALUES (v_news_id, v_category_id);
    DELETE FROM news_category WHERE news_id = v_news_id AND category_id = v_fallback_id;
  END IF;

  -- Another receipt of the same material does not create a second news row.
  INSERT INTO news (source_id, canonical_url, title, content, published_at)
    VALUES (v_source_id, 'https://example.com/news/123', 'Повторная публикация',
            'Текст повтора', CURRENT_TIMESTAMP)
    ON CONFLICT (canonical_url) DO NOTHING RETURNING id INTO v_news_id;
  IF v_news_id IS NOT NULL THEN
    RAISE EXCEPTION 'Duplicate URL unexpectedly created a news row';
  END IF;
  INSERT INTO import_result (scrape_run_id, status) VALUES (v_run_id, 'дубликат');

  -- A malformed material is rolled back, then recorded as an import error.
  BEGIN
    INSERT INTO news (source_id, canonical_url, title, content, published_at)
      VALUES (v_source_id, 'https://example.com/news/invalid', NULL, 'Текст', CURRENT_TIMESTAMP);
    RAISE EXCEPTION 'News with a NULL title was unexpectedly accepted';
  EXCEPTION WHEN not_null_violation THEN
    GET STACKED DIAGNOSTICS v_bad_column = COLUMN_NAME;
    IF v_bad_column <> 'title' THEN RAISE; END IF;
    INSERT INTO import_result (scrape_run_id, status) VALUES (v_run_id, 'ошибка');
    INSERT INTO scrape_error_log (scrape_run_id, error_message)
      VALUES (v_run_id, 'https://example.com/news/invalid: отсутствует заголовок');
  END;
  -- Material errors do not mean the source connection failed.
  UPDATE scrape_run SET status = 'завершен' WHERE id = v_run_id;
END;
$$;

SELECT n.id, n.canonical_url, c.name AS category
FROM news n JOIN news_category nc ON nc.news_id = n.id
JOIN category c ON c.id = nc.category_id
WHERE n.canonical_url = 'https://example.com/news/123';
