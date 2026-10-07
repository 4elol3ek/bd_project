ALTER TABLE scrape_run
ADD CONSTRAINT chk_scrape_run_status CHECK (status IN ('запущен', 'завершен', 'ошибка'));
