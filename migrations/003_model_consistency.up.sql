-- Category disabling preserves subscriptions and existing news assignments.
ALTER TABLE category
ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- A saved publication must contain the text or excerpt promised by BP-13.
-- Existing incomplete rows must be repaired before applying this migration.
ALTER TABLE news
ALTER COLUMN content SET NOT NULL;

ALTER TABLE news
ADD CONSTRAINT chk_news_title_not_blank CHECK (length(btrim(title)) > 0),
ADD CONSTRAINT chk_news_content_not_blank CHECK (length(btrim(content)) > 0),
ADD CONSTRAINT chk_news_url_not_blank CHECK (length(btrim(canonical_url)) > 0);
