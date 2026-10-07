-- Роли пользователей
INSERT INTO role (name) VALUES
('Гость'),
('Зарегистрированный пользователь'),
('Администратор');

-- Пользователи (проверка валидации пароля >= 8 символов и уникальности email)
INSERT INTO app_user (role_id, email, password_hash) VALUES
(2, 'ivan.petrov@example.com', 'pass_ivan123'),
(2, 'elena.sidorova@example.com', 'elena_secure_2026'),
(3, 'admin.news@example.com', 'super_admin_pass');

INSERT INTO app_user (role_id, email, password_hash) VALUES
(2, 'bigrussianboss@example.com', 'brbrbr');
INSERT INTO app_user (role_id, email, password_hash) VALUES
(2, 'elena.sidorova@example.com', 'password');

-- Категории
INSERT INTO category (name) VALUES
('Домашний'),
('Спорт'),
('Политика'),
('Экономика'),
('Без категории');

-- Источники новостей
INSERT INTO news_source (name, url, status) VALUES
('Бабушкины рецепты', 'https://бабушкины-рецепты.рф/rss', 'активен'),
('Sport Express API', 'https://sportexpress.example/api', 'активен'),
('Global News Feed', 'https://globalnews.example/feed', 'ошибка подключения'),
('Old Archive Source', 'https://oldarchive.example/rss', 'отключён вручную'),
('Unstable News Hub', 'https://unstable.example/rss', 'неактивен');

-- Запуски сбора данных
INSERT INTO scrape_run (source_id, started_at, status) VALUES
(1, NOW() - INTERVAL '2 hour', 'успешно завершен'),
(2, NOW() - INTERVAL '1 hour', 'успешно завершен'),
(3, NOW() - INTERVAL '30 minutes', 'ошибка подключения');

-- Новости
INSERT INTO news (source_id, canonical_url, title, content, published_at) VALUES
(1, 'https://бабушкины-рецепты.рф/новости/рассолы', 'Прорыв в сфере засолки огурцов', 'Опубликованы новые данные по бабушкиным рецептам...', NOW() - INTERVAL '3 hour'),
(1, 'https://бабушкины-рецепты.рф/новости/лайфхаки', '100 заговоров для домохозяек', 'Современные заговоры 2026...', NOW() - INTERVAL '2 hour'),
(2, 'https://sportexpress.example/news/champions-league', 'Обзор матча Лиги Чемпионов', 'Вчера состоялся яркий матч завершившегося тура...', NOW() - INTERVAL '1.5 hour'),
(3, 'https://globalnews.example/news/un-summit', 'Срочные новости с саммита ООН', 'Делегаты обсудили вопросы глобальной безопасности...', NOW() - INTERVAL '5 hour'),
(2, 'https://sportexpress.example/news/transfer-window', 'Итоги зимнего трансферного окна', 'Клубы завершили сделки на сумму...', NOW() - INTERVAL '30 minutes');

-- Привязка новостей к категориям
INSERT INTO news_category (news_id, category_id) VALUES
(1, 1), -- Новость 1 -> Домашний
(2, 1), -- Новость 2 -> Домашний
(3, 2), -- Новость 3 -> Спорт
(4, 3), -- Новость 4 -> Политика
(4, 4), -- Новость 4 -> Экономика
(5, 2); -- Новость 5 -> Спорт

-- 8. Результаты импорта
-- Успешные импорты, создавшие публикации
INSERT INTO import_result (scrape_run_id, news_id, status) VALUES
(1, 1, 'успех'),
(1, 2, 'успех'),
(2, 3, 'успех'),
(2, 4, 'успех'),
(2, 5, 'успех');

-- Симуляция обнаружения дубликата
INSERT INTO import_result (scrape_run_id, news_id, status) VALUES
(1, NULL, 'дубликат');

-- 9. Журнал ошибок сбора
INSERT INTO scrape_error_log (scrape_run_id, error_message, created_at) VALUES
(3, 'Connection timeout: https://globalnews.example/feed :(', NOW() - INTERVAL '30 minutes');

-- 10. Подписки пользователей
INSERT INTO subscription_category (user_id, category_id) VALUES
(1, 1), -- Иван подписан на «Домашний»
(1, 2), -- Иван подписан на «Спорт»
(2, 3); -- Елена подписана на «Политика»

INSERT INTO subscription_source (user_id, source_id) VALUES
(1, 1), -- Иван подписан на бабушкины рецепты RSS
(2, 2); -- Елена подписана на Sport Express API

-- 11. Избранное
INSERT INTO favorite (user_id, news_id) VALUES
(1, 1), -- Иван добавил новость про рассол в избранное
(1, 3), -- Иван добавил новость про футбол в избранное
(2, 4); -- Елена добавила новость с саммита в избранное


