-- Called only by generate.sql inside its transaction and chosen search_path.
INSERT INTO role (id, name) OVERRIDING SYSTEM VALUE VALUES
  (1, 'Гость'), (2, 'Зарегистрированный пользователь'), (3, 'Администратор');

INSERT INTO category (id, name, is_active) OVERRIDING SYSTEM VALUE
SELECT id, name, id <= 13
FROM (VALUES
  (1, 'Без категории'), (2, 'Политика'), (3, 'Экономика'), (4, 'Спорт'),
  (5, 'Технологии'), (6, 'Наука'), (7, 'Культура'), (8, 'Общество'),
  (9, 'Здоровье'), (10, 'Образование'), (11, 'Путешествия'),
  (12, 'Экология'), (13, 'Местные новости'), (14, 'Архив: транспорт'),
  (15, 'Архив: выставки'), (16, 'Архив: погода')
) AS categories(id, name);

INSERT INTO news_source (id, name, url, status) OVERRIDING SYSTEM VALUE
SELECT id, 'Источник ' || id, 'https://source-' || id || '.example/rss',
  CASE WHEN id <= 80 THEN 'активен'
       WHEN id <= 90 THEN 'неактивен'
       WHEN id <= 95 THEN 'отключён вручную'
       ELSE 'ошибка подключения' END
FROM generate_series(1, 100) AS sources(id);

-- Reuse three valid demonstration scrypt hashes: no authentication is performed.
INSERT INTO app_user (id, role_id, email, password_hash) OVERRIDING SYSTEM VALUE
SELECT id, CASE WHEN id % 100 = 0 THEN 3 ELSE 2 END,
  'user-' || id || '@example.test',
  (ARRAY[
    'scrypt$16384$8$1$6c61622d6976616e$3c6787dbb06c0a73ea0f10a2af63509675f864f5e5480a5d0595ded71650f48f',
    'scrypt$16384$8$1$6c61622d656c656e61$974a0e5edf2eacdefb19e9a32845038ada4e33556cf587d4322fae30dea4ba25',
    'scrypt$16384$8$1$6c61622d61646d696e$dff4dfe0dd686e85bb53468b57c5c94a30267743e2bce8009c27621a8e14fdd3'
  ])[1 + pg_temp.draw(cfg.seed, 'password', id, 3)::integer]
FROM generation_config cfg
CROSS JOIN LATERAL generate_series(1::bigint, cfg.user_count) AS users(id);

-- 365 completed collection windows for each source, including empty windows.
-- The run occurs after all synthetic publications within its window.
INSERT INTO scrape_run (id, source_id, started_at, status) OVERRIDING SYSTEM VALUE
SELECT (source_id - 1)::bigint * 365 + day + 1, source_id,
  cfg.reference_time - (day + 1) * INTERVAL '1 day' + INTERVAL '23 hours 55 minutes',
  'завершен'
FROM generation_config cfg
CROSS JOIN generate_series(1, 100) AS sources(source_id)
CROSS JOIN generate_series(0, 364) AS days(day);

-- The latest history agrees with the snapshot: 3 failures for inactive sources,
-- 1 failure for sources with a connection error, 8 unfinished active runs.
INSERT INTO scrape_run (id, source_id, started_at, status) OVERRIDING SYSTEM VALUE
SELECT 36500 + (source_id - 1)::bigint * 3 + attempt, source_id,
  cfg.reference_time - (5 - attempt) * INTERVAL '1 minute',
  CASE WHEN source_id <= 8 THEN 'запущен' ELSE 'ошибка' END
FROM generation_config cfg
CROSS JOIN generate_series(1, 100) AS sources(source_id)
CROSS JOIN generate_series(1, 3) AS attempts(attempt)
WHERE (source_id <= 8 AND attempt = 1)
   OR source_id BETWEEN 81 AND 90
   OR (source_id >= 96 AND attempt = 1);

-- Compute shared choices once; imports use the same source/window as the news.
CREATE TEMP TABLE generated_news ON COMMIT DROP AS
WITH draws AS MATERIALIZED (
  SELECT id, cfg.seed, cfg.reference_time,
    pg_temp.draw(cfg.seed, 'source-bucket', id, 10000) AS source_bucket,
    pg_temp.draw(cfg.seed, 'date-bucket', id, 10000) AS date_bucket,
    pg_temp.draw(cfg.seed, 'category-bucket', id, 10000) AS category_bucket
  FROM generation_config cfg
  CROSS JOIN LATERAL generate_series(1::bigint, cfg.news_count) AS news_ids(id)
), sources AS MATERIALIZED (
  SELECT *, CASE WHEN source_bucket < 7000 THEN 1 + pg_temp.draw(seed, 'source', id, 5)
                 WHEN source_bucket < 9500 THEN 6 + pg_temp.draw(seed, 'source', id, 25)
                 ELSE 31 + pg_temp.draw(seed, 'source', id, 70) END::integer AS source_id
  FROM draws
), dates AS MATERIALIZED (
  SELECT *, CASE WHEN source_id > 80 THEN 30 + pg_temp.draw(seed, 'age', id, 335)
                 WHEN date_bucket < 6000 THEN pg_temp.draw(seed, 'age', id, 7)
                 WHEN date_bucket < 8500 THEN 7 + pg_temp.draw(seed, 'age', id, 23)
                 ELSE 30 + pg_temp.draw(seed, 'age', id, 335) END::integer AS day
  FROM sources
)
SELECT id, source_id, (source_id - 1)::bigint * 365 + day + 1 AS run_id,
  reference_time - (day + 1) * INTERVAL '1 day'
    + pg_temp.draw(seed, 'second', id, 85800) * INTERVAL '1 second' AS published_at,
  CASE WHEN category_bucket < 500 THEN 1
       WHEN category_bucket < 6500 THEN 2 + pg_temp.draw(seed, 'category', id, 3)
       WHEN category_bucket < 9800 THEN 5 + pg_temp.draw(seed, 'category', id, 9)
       WHEN day >= 30 THEN 14 + pg_temp.draw(seed, 'category', id, 3)
       ELSE 13 END::integer AS category_id,
  1 + pg_temp.draw(seed, 'paragraphs', id, 6)::integer AS paragraph_count
FROM dates;
ALTER TABLE generated_news ADD PRIMARY KEY (id);
ANALYZE generated_news;

\echo 'Inserting news...'
INSERT INTO news (id, source_id, canonical_url, title, content, published_at)
OVERRIDING SYSTEM VALUE
SELECT g.id, source_id, 'https://source-' || source_id || '.example/news/' || g.id,
  'Публикация ' || g.id || ': ' || c.name,
  repeat('Материал по теме «' || c.name || '». Источник ' || source_id
         || ', публикация ' || g.id || '. Подробности события и комментарии участников. ',
         paragraph_count), published_at
FROM generated_news g JOIN category c ON c.id = g.category_id
ORDER BY g.id;

INSERT INTO news_category (news_id, category_id)
SELECT id, category_id FROM generated_news ORDER BY id;

\echo 'Inserting import results and error logs...'
INSERT INTO import_result (id, scrape_run_id, news_id, status) OVERRIDING SYSTEM VALUE
SELECT id, run_id, id, 'успех' FROM generated_news ORDER BY id;

-- Extra receipts do not create another news row or attach NULL-result to old news.
INSERT INTO import_result (id, scrape_run_id, status) OVERRIDING SYSTEM VALUE
SELECT cfg.news_count + duplicate.id, n.run_id, 'дубликат'
FROM generation_config cfg
CROSS JOIN LATERAL generate_series(1::bigint, cfg.news_count * 8 / 100) AS duplicate(id)
JOIN generated_news n ON n.id = 1 + pg_temp.draw(cfg.seed, 'duplicate-news', duplicate.id, cfg.news_count)
ORDER BY duplicate.id;

CREATE TEMP TABLE generated_errors ON COMMIT DROP AS
SELECT error.id, n.run_id,
  'Материал ' || error.id || ': отсутствует обязательный заголовок' AS message
FROM generation_config cfg
CROSS JOIN LATERAL generate_series(1::bigint, cfg.news_count * 2 / 100) AS error(id)
JOIN generated_news n ON n.id = 1 + pg_temp.draw(cfg.seed, 'error-news', error.id, cfg.news_count);

INSERT INTO import_result (id, scrape_run_id, status) OVERRIDING SYSTEM VALUE
SELECT cfg.news_count * 108 / 100 + e.id, e.run_id, 'ошибка'
FROM generated_errors e CROSS JOIN generation_config cfg ORDER BY e.id;

INSERT INTO scrape_error_log (id, scrape_run_id, error_message, created_at)
OVERRIDING SYSTEM VALUE
SELECT e.id, e.run_id, e.message, r.started_at + INTERVAL '10 seconds'
FROM generated_errors e JOIN scrape_run r ON r.id = e.run_id ORDER BY e.id;

INSERT INTO scrape_error_log (id, scrape_run_id, error_message, created_at)
OVERRIDING SYSTEM VALUE
SELECT cfg.news_count * 2 / 100 + row_number() OVER (ORDER BY r.id), r.id,
  'Источник ' || r.source_id || ': не удалось подключиться',
  r.started_at + INTERVAL '10 seconds'
FROM scrape_run r CROSS JOIN generation_config cfg WHERE r.status = 'ошибка';

\echo 'Inserting subscriptions and favorites...'
-- 20% have no subscriptions; 60% have one of each; 20% have 5/4.
INSERT INTO subscription_category (user_id, category_id)
SELECT u.id, CASE WHEN slot = 1 THEN 2 + pg_temp.draw(cfg.seed, 'subscription-hot-category', u.id, 3)
                 ELSE 5 + (pg_temp.draw(cfg.seed, 'subscription-category', u.id, 9) + slot - 2) % 9 END
FROM app_user u CROSS JOIN generation_config cfg
CROSS JOIN LATERAL generate_series(1, CASE WHEN u.id % 5 = 0 THEN 0
                                          WHEN u.id % 5 = 4 THEN 5 ELSE 1 END) AS slots(slot);

INSERT INTO subscription_source (user_id, source_id)
SELECT u.id, CASE WHEN slot = 1 THEN 1 + pg_temp.draw(cfg.seed, 'subscription-hot-source', u.id, 5)
                 ELSE 6 + (pg_temp.draw(cfg.seed, 'subscription-source', u.id, 75) + slot - 2) % 75 END
FROM app_user u CROSS JOIN generation_config cfg
CROSS JOIN LATERAL generate_series(1, CASE WHEN u.id % 5 = 0 THEN 0
                                          WHEN u.id % 5 = 4 THEN 4 ELSE 1 END) AS slots(slot);

-- Distinct slots within disjoint hot/cold ranges avoid duplicate composite keys.
-- Normal users save 1 hot + 1 other news; heavy users save 16 hot + 4 other news.
INSERT INTO favorite (user_id, news_id)
SELECT u.id,
  CASE WHEN slot <= CASE WHEN u.id % 5 = 4 THEN 16 ELSE 1 END
       THEN 1 + (pg_temp.draw(cfg.seed, 'favorite-hot', u.id, cfg.news_count / 100) + slot - 1)
                  % (cfg.news_count / 100)
       ELSE cfg.news_count / 100 + 1
            + (pg_temp.draw(cfg.seed, 'favorite-other', u.id, cfg.news_count * 99 / 100) + slot - 1)
                % (cfg.news_count * 99 / 100) END
FROM app_user u CROSS JOIN generation_config cfg
CROSS JOIN LATERAL generate_series(1, CASE WHEN u.id % 5 = 0 THEN 0
                                          WHEN u.id % 5 = 4 THEN 20 ELSE 2 END) AS slots(slot);
