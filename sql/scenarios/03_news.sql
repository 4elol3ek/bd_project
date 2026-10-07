-- Проверка наличия новости с такой канонической ссылкой
SELECT id
FROM news
WHERE canonical_url = 'https://example.com/news/123'; 

-- Сохранение полученной новости
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
    'Новая публикация',
    'Текст новости',
    CURRENT_TIMESTAMP
)
RETURNING id; 

-- Фиксация успешного импорта
INSERT INTO import_result (
    scrape_run_id,
    news_id,
    status
)
VALUES (
    1,
    6,
    'успех'
); 
