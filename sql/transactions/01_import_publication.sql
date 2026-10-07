-- Транзакция: импорт одной публикации за один запуск сбора (SC-05)
-- Изменяемые таблицы: scrape_run, news, news_category, import_result, news_source.
-- Шаги:
--   1. создать запуск сбора («запущен»);
--   2. сохранить новость (дубликат по canonical_url не вставляется, БП-4);
--   3. привязать категорию; если не найдена/неактивна - «Без категории» (БП-5);
--   4. записать результат импорта («успех» или «дубликат»);
--   5. закрыть запуск («завершен»);
--   6. вернуть источник из «ошибка подключения» в «активен» (AC-SC06-06).
BEGIN;
DO $$
DECLARE v_source_id INT := (
        SELECT id
        FROM news_source
        WHERE url = 'https://globalnews.example/feed'
    );
v_url TEXT := 'https://globalnews.example/news/climate-report';
v_title TEXT := 'Доклад о климате: ключевые выводы';
v_content TEXT := 'Эксперты представили новый климатический доклад...';
v_published_at TIMESTAMPTZ := NOW() - INTERVAL '10 minutes';
v_category_name TEXT := 'Экономика';
v_run_id BIGINT;
v_news_id BIGINT;
v_category_id INT;
BEGIN -- Шаг 1. 
INSERT INTO scrape_run (source_id, status)
VALUES (v_source_id, 'запущен')
RETURNING id INTO v_run_id;
-- Шаг 2.
INSERT INTO news (
        source_id,
        canonical_url,
        title,
        content,
        published_at
    )
VALUES (
        v_source_id,
        v_url,
        v_title,
        v_content,
        v_published_at
    ) ON CONFLICT (canonical_url) DO NOTHING
RETURNING id INTO v_news_id;
IF v_news_id IS NULL THEN -- Дубликат новости не создается
INSERT INTO import_result (scrape_run_id, news_id, status)
VALUES (v_run_id, NULL, 'дубликат');
ELSE -- Шаг 3.
SELECT id INTO v_category_id
FROM category
WHERE name = v_category_name
    AND is_active;
IF v_category_id IS NULL THEN
SELECT id INTO v_category_id
FROM category
WHERE name = 'Без категории';
END IF;
INSERT INTO news_category (news_id, category_id)
VALUES (v_news_id, v_category_id);
-- Шаг 4.
INSERT INTO import_result (scrape_run_id, news_id, status)
VALUES (v_run_id, v_news_id, 'успех');
END IF;
-- Шаг 5.
UPDATE scrape_run
SET status = 'завершен'
WHERE id = v_run_id;
-- Шаг 6.
UPDATE news_source
SET status = 'активен'
WHERE id = v_source_id
    AND status = 'ошибка подключения';
END $$;
-- Проверка внутри транзакции (до фиксации)
SELECT s.status AS source_status,
    r.id AS run_id,
    r.status AS run_status,
    ir.status AS import_status,
    n.title,
    c.name AS category
FROM scrape_run r
    JOIN news_source s ON s.id = r.source_id
    JOIN import_result ir ON ir.scrape_run_id = r.id
    LEFT JOIN news n ON n.id = ir.news_id
    LEFT JOIN news_category nc ON nc.news_id = n.id
    LEFT JOIN category c ON c.id = nc.category_id
WHERE s.url = 'https://globalnews.example/feed'
ORDER BY r.id DESC
LIMIT 1;
COMMIT;