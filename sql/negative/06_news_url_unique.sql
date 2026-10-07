-- Expected: SQLSTATE 23505, news_canonical_url_key. Requires only the seed.
INSERT INTO news (source_id, canonical_url, title, content, published_at)
VALUES ((SELECT source_id FROM news WHERE canonical_url = 'https://sportexpress.example/news/champions-league'),
        'https://sportexpress.example/news/champions-league', 'Другая версия новости',
        'Другой текст', CURRENT_TIMESTAMP);
