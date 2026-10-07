INSERT INTO news (
    source_id,
    canonical_url,
    title,
    content,
    published_at
)
VALUES (
    1,
    'https://example.com/news/123',
    'Другая версия новости',
    'Другой текст',
    CURRENT_TIMESTAMP
); 
