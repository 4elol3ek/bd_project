-- Expected: SQLSTATE 23503, fk_news_source.
INSERT INTO news (source_id, canonical_url, title, content, published_at)
VALUES (-1, 'https://example.test/missing-source', 'Тестовая новость',
        'Текст новости', CURRENT_TIMESTAMP);
