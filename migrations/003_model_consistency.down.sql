ALTER TABLE news
DROP CONSTRAINT chk_news_url_not_blank,
DROP CONSTRAINT chk_news_content_not_blank,
DROP CONSTRAINT chk_news_title_not_blank,
ALTER COLUMN content DROP NOT NULL;

ALTER TABLE category DROP COLUMN is_active;
