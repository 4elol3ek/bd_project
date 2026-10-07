-- Демонстрация: ошибка на втором шаге откатывает первый.
-- Ожидание: ERROR (fk_news_source), после ROLLBACK запуск «запущен» не сохранён.

SELECT COUNT(*) AS running_before FROM scrape_run WHERE status = 'запущен';

BEGIN;

INSERT INTO scrape_run (source_id, status)
VALUES ((SELECT id FROM news_source WHERE url = 'https://globalnews.example/feed'),
        'запущен');

-- несуществующий источник -> нарушение внешнего ключа
INSERT INTO news (source_id, canonical_url, title, content, published_at)
VALUES (9999, 'https://x.example/rollback', 't', 'c', NOW());

ROLLBACK;

SELECT COUNT(*) AS running_after FROM scrape_run WHERE status = 'запущен';
-- running_before = running_after = 0