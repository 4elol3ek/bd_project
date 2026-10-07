CREATE TABLE
  ROLE (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    NAME VARCHAR(50) UNIQUE NOT NULL
  );


-- Пользователи
CREATE TABLE
  app_user (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_id INT NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL CHECK (LENGTH(password_hash) >= 8),
    CONSTRAINT fk_user_role FOREIGN KEY (role_id) REFERENCES ROLE (id) ON DELETE RESTRICT
  );


-- Категории
CREATE TABLE
  category (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    NAME VARCHAR(100) UNIQUE NOT NULL
  );


-- Источники новостей
CREATE TABLE
  news_source (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    NAME VARCHAR(255) NOT NULL,
    url VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'активен' CHECK (
      status IN (
        'активен',
        'неактивен',
        'отключён вручную',
        'ошибка подключения'
      )
    )
  );


-- Новости
CREATE TABLE
  news (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_id INT NOT NULL,
    canonical_url VARCHAR(500) UNIQUE NOT NULL,
    title TEXT NOT NULL,
    CONTENT TEXT,
    published_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_news_source FOREIGN KEY (source_id) REFERENCES news_source (id) ON DELETE CASCADE
  );


-- Связь новостей и категорий
CREATE TABLE
  news_category (
    news_id BIGINT NOT NULL,
    category_id INT NOT NULL,
    PRIMARY KEY (news_id, category_id),
    CONSTRAINT fk_nc_news FOREIGN KEY (news_id) REFERENCES news (id) ON DELETE CASCADE,
    CONSTRAINT fk_nc_category FOREIGN KEY (category_id) REFERENCES category (id) ON DELETE CASCADE
  );


-- Подписки на категории
CREATE TABLE
  subscription_category (
    user_id BIGINT NOT NULL,
    category_id INT NOT NULL,
    PRIMARY KEY (user_id, category_id),
    CONSTRAINT fk_sc_user FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE CASCADE,
    CONSTRAINT fk_sc_category FOREIGN KEY (category_id) REFERENCES category (id) ON DELETE CASCADE
  );


-- Подписки на источники
CREATE TABLE
  subscription_source (
    user_id BIGINT NOT NULL,
    source_id INT NOT NULL,
    PRIMARY KEY (user_id, source_id),
    CONSTRAINT fk_ss_user FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE CASCADE,
    CONSTRAINT fk_ss_source FOREIGN KEY (source_id) REFERENCES news_source (id) ON DELETE CASCADE
  );


-- Избранное
CREATE TABLE
  favorite (
    user_id BIGINT NOT NULL,
    news_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, news_id),
    CONSTRAINT fk_fav_user FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE CASCADE,
    CONSTRAINT fk_fav_news FOREIGN KEY (news_id) REFERENCES news (id) ON DELETE CASCADE
  );


-- Запуски сбора
CREATE TABLE
  scrape_run (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_id INT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(50) NOT NULL,
    CONSTRAINT fk_scrape_source FOREIGN KEY (source_id) REFERENCES news_source (id) ON DELETE CASCADE
  );


-- Результаты импорта
CREATE TABLE
  import_result (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scrape_run_id BIGINT NOT NULL,
    news_id BIGINT UNIQUE,
    status VARCHAR(50) NOT NULL CHECK (status IN ('успех', 'дубликат', 'ошибка')),
    CONSTRAINT fk_import_run FOREIGN KEY (scrape_run_id) REFERENCES scrape_run (id) ON DELETE CASCADE,
    CONSTRAINT fk_import_news FOREIGN KEY (news_id) REFERENCES news (id) ON DELETE SET NULL
  );


-- Журнал ошибок
CREATE TABLE
  scrape_error_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scrape_run_id BIGINT NOT NULL,
    error_message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_error_run FOREIGN KEY (scrape_run_id) REFERENCES scrape_run (id) ON DELETE CASCADE
  );
