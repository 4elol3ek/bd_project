-- Expected: SQLSTATE 23502, column title. Requires the seed.
INSERT INTO news (source_id, canonical_url, title, content, published_at)
VALUES ((SELECT id FROM news_source WHERE url = 'https://sportexpress.example/api'),
        'https://example.test/null-title', NULL, 'Текст новости', CURRENT_TIMESTAMP);
