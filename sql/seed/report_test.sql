-- Positive demo data only. Use run_demo.sql or psql --single-transaction.
-- Refuse to overwrite an existing dataset; IDs are resolved from unique keys.
DO $$
DECLARE
  table_name text;
  has_rows boolean;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'role', 'app_user', 'category', 'news_source', 'news', 'news_category',
    'subscription_category', 'subscription_source', 'favorite',
    'scrape_run', 'import_result', 'scrape_error_log'
  ] LOOP
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I)', table_name) INTO has_rows;
    IF has_rows THEN
      RAISE EXCEPTION 'Demo loading requires empty tables; % already contains data', table_name;
    END IF;
  END LOOP;
END;
$$;

INSERT INTO role (name) VALUES
  ('Гость'), ('Зарегистрированный пользователь'), ('Администратор');

-- Actual demonstration scrypt hashes, not plain passwords.
-- Password-length validation belongs to registration before hashing.
INSERT INTO app_user (role_id, email, password_hash)
SELECT r.id, d.email, d.password_hash
FROM (VALUES
  ('Зарегистрированный пользователь', 'ivan.petrov@example.com', 'scrypt$16384$8$1$6c61622d6976616e$3c6787dbb06c0a73ea0f10a2af63509675f864f5e5480a5d0595ded71650f48f'),
  ('Зарегистрированный пользователь', 'elena.sidorova@example.com', 'scrypt$16384$8$1$6c61622d656c656e61$974a0e5edf2eacdefb19e9a32845038ada4e33556cf587d4322fae30dea4ba25'),
  ('Администратор', 'admin.news@example.com', 'scrypt$16384$8$1$6c61622d61646d696e$dff4dfe0dd686e85bb53468b57c5c94a30267743e2bce8009c27621a8e14fdd3')
) AS d(role_name, email, password_hash)
JOIN role r ON r.name = d.role_name;

INSERT INTO category (name) VALUES
  ('Домашний'), ('Спорт'), ('Политика'), ('Экономика'), ('Без категории');

INSERT INTO news_source (name, url, status) VALUES
  ('Бабушкины рецепты', 'https://бабушкины-рецепты.рф/rss', 'активен'),
  ('Sport Express API', 'https://sportexpress.example/api', 'активен'),
  ('Global News Feed', 'https://globalnews.example/feed', 'ошибка подключения'),
  ('Old Archive Source', 'https://oldarchive.example/rss', 'отключён вручную'),
  ('Unstable News Hub', 'https://unstable.example/rss', 'неактивен');

INSERT INTO news (source_id, canonical_url, title, content, published_at)
SELECT s.id, d.url, d.title, d.content, CURRENT_TIMESTAMP - d.age
FROM (VALUES
  ('https://бабушкины-рецепты.рф/rss', 'https://бабушкины-рецепты.рф/новости/рассолы', 'Прорыв в сфере засолки огурцов', 'Опубликованы новые данные по бабушкиным рецептам...', INTERVAL '3 hours'),
  ('https://бабушкины-рецепты.рф/rss', 'https://бабушкины-рецепты.рф/новости/лайфхаки', '100 заговоров для домохозяек', 'Современные заговоры 2026...', INTERVAL '2 hours'),
  ('https://sportexpress.example/api', 'https://sportexpress.example/news/champions-league', 'Обзор матча Лиги Чемпионов', 'Вчера состоялся яркий матч завершившегося тура...', INTERVAL '1.5 hours'),
  ('https://globalnews.example/feed', 'https://globalnews.example/news/un-summit', 'Срочные новости с саммита ООН', 'Делегаты обсудили вопросы глобальной безопасности...', INTERVAL '5 hours'),
  ('https://sportexpress.example/api', 'https://sportexpress.example/news/transfer-window', 'Итоги зимнего трансферного окна', 'Клубы завершили сделки на сумму...', INTERVAL '30 minutes')
) AS d(source_url, url, title, content, age)
JOIN news_source s ON s.url = d.source_url;

INSERT INTO news_category (news_id, category_id)
SELECT n.id, c.id
FROM (VALUES
  ('https://бабушкины-рецепты.рф/новости/рассолы', 'Домашний'),
  ('https://бабушкины-рецепты.рф/новости/лайфхаки', 'Домашний'),
  ('https://sportexpress.example/news/champions-league', 'Спорт'),
  ('https://globalnews.example/news/un-summit', 'Политика'),
  ('https://globalnews.example/news/un-summit', 'Экономика'),
  ('https://sportexpress.example/news/transfer-window', 'Спорт')
) AS d(news_url, category_name)
JOIN news n ON n.canonical_url = d.news_url
JOIN category c ON c.name = d.category_name;

DO $$
DECLARE
  v_home_run bigint;
  v_sport_run bigint;
  v_global_success bigint;
  v_global_error bigint;
BEGIN
  INSERT INTO scrape_run (source_id, started_at, status)
    VALUES ((SELECT id FROM news_source WHERE url = 'https://бабушкины-рецепты.рф/rss'),
            CURRENT_TIMESTAMP - INTERVAL '1 hour', 'завершен') RETURNING id INTO v_home_run;
  INSERT INTO scrape_run (source_id, started_at, status)
    VALUES ((SELECT id FROM news_source WHERE url = 'https://sportexpress.example/api'),
            CURRENT_TIMESTAMP - INTERVAL '20 minutes', 'завершен') RETURNING id INTO v_sport_run;
  -- Global News was reachable earlier; its saved publication remains available.
  INSERT INTO scrape_run (source_id, started_at, status)
    VALUES ((SELECT id FROM news_source WHERE url = 'https://globalnews.example/feed'),
            CURRENT_TIMESTAMP - INTERVAL '4 hours', 'завершен') RETURNING id INTO v_global_success;
  INSERT INTO scrape_run (source_id, started_at, status)
    VALUES ((SELECT id FROM news_source WHERE url = 'https://globalnews.example/feed'),
            CURRENT_TIMESTAMP - INTERVAL '30 minutes', 'ошибка') RETURNING id INTO v_global_error;

  INSERT INTO import_result (scrape_run_id, news_id, status)
  SELECT CASE s.url
           WHEN 'https://бабушкины-рецепты.рф/rss' THEN v_home_run
           WHEN 'https://sportexpress.example/api' THEN v_sport_run
           ELSE v_global_success
         END, n.id, 'успех'
  FROM news n JOIN news_source s ON s.id = n.source_id;

  INSERT INTO import_result (scrape_run_id, news_id, status) VALUES
    (v_home_run, NULL, 'дубликат');
  -- Connection failed before receiving materials: only a run error, no import result.
  INSERT INTO scrape_error_log (scrape_run_id, error_message)
    VALUES (v_global_error, 'Connection timeout: https://globalnews.example/feed');
END;
$$;

INSERT INTO subscription_category (user_id, category_id)
SELECT u.id, c.id
FROM (VALUES
  ('ivan.petrov@example.com', 'Домашний'),
  ('ivan.petrov@example.com', 'Спорт'),
  ('elena.sidorova@example.com', 'Политика')
) AS d(email, category_name)
JOIN app_user u ON u.email = d.email
JOIN category c ON c.name = d.category_name;

INSERT INTO subscription_source (user_id, source_id)
SELECT u.id, s.id
FROM (VALUES
  ('ivan.petrov@example.com', 'https://бабушкины-рецепты.рф/rss'),
  ('elena.sidorova@example.com', 'https://sportexpress.example/api')
) AS d(email, source_url)
JOIN app_user u ON u.email = d.email
JOIN news_source s ON s.url = d.source_url;

INSERT INTO favorite (user_id, news_id)
SELECT u.id, n.id
FROM (VALUES
  ('ivan.petrov@example.com', 'https://бабушкины-рецепты.рф/новости/рассолы'),
  ('ivan.petrov@example.com', 'https://sportexpress.example/news/champions-league'),
  ('elena.sidorova@example.com', 'https://globalnews.example/news/un-summit')
) AS d(email, news_url)
JOIN app_user u ON u.email = d.email
JOIN news n ON n.canonical_url = d.news_url;
