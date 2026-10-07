-- Expected: SQLSTATE 23514, news_source_status_check.
INSERT INTO news_source (name, url, status)
VALUES ('Test Source', 'https://example.test/invalid-status', 'неизвестен');
