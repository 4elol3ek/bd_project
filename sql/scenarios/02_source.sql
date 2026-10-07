-- SQL demonstration; connection results are simulated, no HTTP requests occur.
DO $$
DECLARE
  v_source_id integer;
  v_run_id bigint;
  v_failures integer;
  v_error_threshold integer := 3;
BEGIN
  INSERT INTO news_source (name, url, status)
    VALUES ('Example News', 'https://example.com/rss', 'активен')
    RETURNING id INTO v_source_id;

  -- Successful run belongs to the source just created.
  INSERT INTO scrape_run (source_id, status) VALUES (v_source_id, 'запущен')
    RETURNING id INTO v_run_id;
  UPDATE scrape_run SET status = 'завершен' WHERE id = v_run_id;

  -- Independent later attempts: an already completed run is never overwritten.
  FOR v_failures IN 1..v_error_threshold LOOP
    INSERT INTO scrape_run (source_id, status) VALUES (v_source_id, 'запущен')
      RETURNING id INTO v_run_id;
    INSERT INTO scrape_error_log (scrape_run_id, error_message)
      VALUES (v_run_id, 'Не удалось подключиться к источнику');
    UPDATE scrape_run SET status = 'ошибка' WHERE id = v_run_id;
    UPDATE news_source
      SET status = CASE WHEN v_failures >= v_error_threshold
                        THEN 'неактивен' ELSE 'ошибка подключения' END
      WHERE id = v_source_id;
  END LOOP;
  IF (SELECT status FROM news_source WHERE id = v_source_id) <> 'неактивен' THEN
    RAISE EXCEPTION 'Three consecutive connection failures must suspend the source';
  END IF;

  -- Administrator initiates a successful probe of the inactive source.
  INSERT INTO scrape_run (source_id, status) VALUES (v_source_id, 'запущен')
    RETURNING id INTO v_run_id;
  UPDATE scrape_run SET status = 'завершен' WHERE id = v_run_id;
  UPDATE news_source SET status = 'активен' WHERE id = v_source_id;

  -- Manual disabling preserves the source, subscriptions and publications.
  UPDATE news_source SET status = 'отключён вручную' WHERE id = v_source_id;
  -- A successful check alone must not automatically undo manual disabling.
  INSERT INTO scrape_run (source_id, status) VALUES (v_source_id, 'запущен')
    RETURNING id INTO v_run_id;
  UPDATE scrape_run SET status = 'завершен' WHERE id = v_run_id;
  -- Explicit administrator action enables the source after the successful probe.
  IF (SELECT status FROM news_source WHERE id = v_source_id) <> 'отключён вручную' THEN
    RAISE EXCEPTION 'A probe must not automatically enable a manually disabled source';
  END IF;
  UPDATE news_source SET status = 'активен' WHERE id = v_source_id;
END;
$$;

SELECT s.id, s.status, r.id AS run_id, r.status AS run_status
FROM news_source s JOIN scrape_run r ON r.source_id = s.id
WHERE s.url = 'https://example.com/rss' ORDER BY r.id;
