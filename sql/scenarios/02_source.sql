-- Добавление источника новостей
INSERT INTO news_source (name, url, status)
VALUES (
    'Example News',
    'https://example.com/rss',
    'активен'
)
RETURNING id; 

-- Запуск сбора новостей
INSERT INTO scrape_run (source_id, started_at, status)
VALUES (
    1,
    CURRENT_TIMESTAMP,
    'запущен'
)
RETURNING id; 

-- Успешное завершение сбора
UPDATE scrape_run
SET status = 'завершен'
WHERE id = 1; 

-- Регистрация ошибки сбора
INSERT INTO scrape_error_log (
    scrape_run_id,
    error_message
)
VALUES (
    1,
    'Не удалось подключиться к источнику'
);

UPDATE scrape_run
SET status = 'ошибка'
WHERE id = 1; 
