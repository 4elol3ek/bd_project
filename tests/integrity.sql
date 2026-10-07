-- Run through run_checks.sql: fixtures and helpers belong to its transaction.
CREATE TEMP TABLE check_results (name text PRIMARY KEY) ON COMMIT DROP;

CREATE FUNCTION check_that(label text, condition boolean) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL: %', label;
  END IF;
  INSERT INTO pg_temp.check_results VALUES (label);
  RAISE NOTICE 'PASS: %', label;
END;
$$;

CREATE FUNCTION expect_error(
  label text,
  statement text,
  expected_state text,
  expected_constraint text DEFAULT NULL,
  expected_column text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  actual_state text;
  actual_constraint text;
  actual_column text;
BEGIN
  -- The exception block rolls back the attempted statement.
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      actual_state = RETURNED_SQLSTATE,
      actual_constraint = CONSTRAINT_NAME,
      actual_column = COLUMN_NAME;
  END;

  IF actual_state IS DISTINCT FROM expected_state
     OR (expected_constraint IS NOT NULL
         AND actual_constraint IS DISTINCT FROM expected_constraint)
     OR (expected_column IS NOT NULL
         AND actual_column IS DISTINCT FROM expected_column) THEN
    RAISE EXCEPTION 'FAIL: %; expected SQLSTATE %, constraint %, column %; got %, %, %',
      label, expected_state, expected_constraint, expected_column,
      coalesce(actual_state, 'no error'), actual_constraint, actual_column;
  END IF;
  PERFORM check_that(label, true);
END;
$$;

SELECT check_that('12 tables have primary keys; 14 foreign keys are validated',
  (SELECT count(*) = 12 FROM pg_class
   WHERE relnamespace = current_schema()::regnamespace AND relkind = 'r')
  AND (SELECT count(*) = 12 FROM pg_constraint
       WHERE connamespace = current_schema()::regnamespace AND contype = 'p')
  AND (SELECT count(*) = 14 AND bool_and(convalidated) FROM pg_constraint
       WHERE connamespace = current_schema()::regnamespace AND contype = 'f')
);

DO $$
DECLARE
  v_role_id integer;
  v_user_id bigint;
  v_category_id integer;
  v_source_id integer;
  v_news_id bigint;
  v_other_news_id bigint;
  v_run_id bigint;
  v_failed_run_id bigint;
  v_result_id bigint;
BEGIN
  INSERT INTO role (name) VALUES ('пользователь') RETURNING id INTO v_role_id;
  INSERT INTO app_user (role_id, email, password_hash)
    VALUES (v_role_id, 'checks@example.test', 'test_hash_123') RETURNING id INTO v_user_id;
  INSERT INTO category (name) VALUES ('Технологии') RETURNING id INTO v_category_id;
  INSERT INTO news_source (name, url)
    VALUES ('Тестовый источник', 'https://example.test') RETURNING id INTO v_source_id;
  INSERT INTO news (source_id, canonical_url, title, published_at)
    VALUES (v_source_id, 'https://example.test/news/1', 'Новость 1', now())
    RETURNING id INTO v_news_id;
  INSERT INTO news (source_id, canonical_url, title, published_at)
    VALUES (v_source_id, 'https://example.test/news/2', 'Новость 2', now())
    RETURNING id INTO v_other_news_id;
  INSERT INTO news_category VALUES (v_news_id, v_category_id), (v_other_news_id, v_category_id);
  INSERT INTO subscription_category VALUES (v_user_id, v_category_id);
  INSERT INTO subscription_source VALUES (v_user_id, v_source_id);
  INSERT INTO favorite VALUES (v_user_id, v_news_id), (v_user_id, v_other_news_id);
  INSERT INTO scrape_run (source_id, status)
    VALUES (v_source_id, 'завершен') RETURNING id INTO v_run_id;
  INSERT INTO scrape_run (source_id, status)
    VALUES (v_source_id, 'ошибка') RETURNING id INTO v_failed_run_id;
  INSERT INTO import_result (scrape_run_id, news_id, status)
    VALUES (v_run_id, v_news_id, 'успех') RETURNING id INTO v_result_id;
  INSERT INTO import_result (scrape_run_id, news_id, status)
    VALUES (v_run_id, v_other_news_id, 'успех');
  INSERT INTO scrape_error_log (scrape_run_id, error_message)
    VALUES (v_failed_run_id, 'Тестовая ошибка подключения');

  PERFORM check_that('Consistent fixtures insert into all 12 tables; defaults work',
    (SELECT status = 'активен' FROM news_source WHERE id = v_source_id)
    AND (SELECT started_at IS NOT NULL FROM scrape_run WHERE id = v_run_id)
    AND (SELECT created_at IS NOT NULL FROM scrape_error_log WHERE scrape_run_id = v_failed_run_id)
  );

  PERFORM expect_error('Duplicate email is rejected',
    format('INSERT INTO app_user (role_id, email, password_hash) VALUES (%s, %L, %L)',
      v_role_id, 'checks@example.test', 'test_hash_456'), '23505', 'app_user_email_key');

  PERFORM expect_error('Duplicate source URL is rejected',
    format('INSERT INTO news_source (name, url) VALUES (%L, %L)',
      'Другой источник', 'https://example.test'), '23505', 'news_source_url_key');

  PERFORM expect_error('Duplicate canonical news URL is rejected',
    format('INSERT INTO news (source_id, canonical_url, title, published_at) VALUES (%s, %L, %L, now())',
      v_source_id, 'https://example.test/news/1', 'Дубликат'), '23505', 'news_canonical_url_key');

  PERFORM expect_error('Duplicate favorite is rejected by its composite key',
    format('INSERT INTO favorite VALUES (%s, %s)', v_user_id, v_news_id), '23505', 'favorite_pkey');

  PERFORM expect_error('User cannot refer to a missing role',
    format('UPDATE app_user SET role_id = -1 WHERE id = %s', v_user_id), '23503', 'fk_user_role');

  PERFORM expect_error('News cannot refer to a missing source',
    format('UPDATE news SET source_id = -1 WHERE id = %s', v_news_id), '23503', 'fk_news_source');

  PERFORM expect_error('Import cannot refer to a missing scrape run',
    format('UPDATE import_result SET scrape_run_id = -1 WHERE id = %s', v_result_id), '23503', 'fk_import_run');

  PERFORM expect_error('News title cannot be NULL',
    format('UPDATE news SET title = NULL WHERE id = %s', v_news_id), '23502', NULL, 'title');

  PERFORM expect_error('Password hash shorter than 8 characters is rejected',
    format('UPDATE app_user SET password_hash = %L WHERE id = %s', 'short', v_user_id),
    '23514', 'app_user_password_hash_check');

  PERFORM expect_error('Unknown source status is rejected',
    format('UPDATE news_source SET status = %L WHERE id = %s', 'unknown', v_source_id),
    '23514', 'news_source_status_check');

  PERFORM expect_error('Unknown scrape status is rejected by migration 002',
    format('UPDATE scrape_run SET status = %L WHERE id = %s', 'успешно завершен', v_run_id),
    '23514', 'chk_scrape_run_status');

  PERFORM expect_error('Unknown import status is rejected',
    format('UPDATE import_result SET status = %L WHERE id = %s', 'unknown', v_result_id),
    '23514', 'import_result_status_check');

  PERFORM expect_error('Role with a user cannot be deleted',
    format('DELETE FROM role WHERE id = %s', v_role_id), '23001', 'fk_user_role');

  DELETE FROM news WHERE id = v_news_id;
  PERFORM check_that('Deleting news removes links and preserves import with NULL news_id',
    NOT EXISTS (SELECT 1 FROM favorite WHERE favorite.news_id = v_news_id)
    AND NOT EXISTS (SELECT 1 FROM news_category WHERE news_category.news_id = v_news_id)
    AND (SELECT import_result.news_id IS NULL FROM import_result WHERE id = v_result_id)
    AND EXISTS (SELECT 1 FROM news WHERE id = v_other_news_id)
  );

  DELETE FROM app_user WHERE id = v_user_id;
  PERFORM check_that('Deleting user removes subscriptions and favorites, keeps news',
    NOT EXISTS (SELECT 1 FROM subscription_category WHERE subscription_category.user_id = v_user_id)
    AND NOT EXISTS (SELECT 1 FROM subscription_source WHERE subscription_source.user_id = v_user_id)
    AND NOT EXISTS (SELECT 1 FROM favorite WHERE favorite.user_id = v_user_id)
    AND EXISTS (SELECT 1 FROM news WHERE id = v_other_news_id)
  );

  DELETE FROM news_source WHERE id = v_source_id;
  PERFORM check_that('Deleting source removes news, runs, imports and error logs',
    NOT EXISTS (SELECT 1 FROM news)
    AND NOT EXISTS (SELECT 1 FROM news_category)
    AND NOT EXISTS (SELECT 1 FROM scrape_run)
    AND NOT EXISTS (SELECT 1 FROM import_result)
    AND NOT EXISTS (SELECT 1 FROM scrape_error_log)
    AND EXISTS (SELECT 1 FROM category WHERE id = v_category_id)
  );
END;
$$;
