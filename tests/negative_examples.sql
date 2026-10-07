-- Each example must fail for its declared reason; its changes are rolled back.
SAVEPOINT negative_example;
\set ON_ERROR_STOP off
\ir ../sql/negative/01_email_unique.sql
\set negative_state :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT negative_example;
RELEASE SAVEPOINT negative_example;
SELECT check_that('Report negative example: email UNIQUE', :'negative_state' = '23505');

SAVEPOINT negative_example;
\set ON_ERROR_STOP off
\ir ../sql/negative/02_user_role_fk.sql
\set negative_state :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT negative_example;
RELEASE SAVEPOINT negative_example;
SELECT check_that('Report negative example: user role FK', :'negative_state' = '23503');

SAVEPOINT negative_example;
\set ON_ERROR_STOP off
\ir ../sql/negative/03_source_status_check.sql
\set negative_state :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT negative_example;
RELEASE SAVEPOINT negative_example;
SELECT check_that('Report negative example: source status CHECK', :'negative_state' = '23514');

SAVEPOINT negative_example;
\set ON_ERROR_STOP off
\ir ../sql/negative/04_news_title_not_null.sql
\set negative_state :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT negative_example;
RELEASE SAVEPOINT negative_example;
SELECT check_that('Report negative example: news title NOT NULL', :'negative_state' = '23502');

SAVEPOINT negative_example;
\set ON_ERROR_STOP off
\ir ../sql/negative/05_news_source_fk.sql
\set negative_state :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT negative_example;
RELEASE SAVEPOINT negative_example;
SELECT check_that('Report negative example: news source FK', :'negative_state' = '23503');

SAVEPOINT negative_example;
\set ON_ERROR_STOP off
\ir ../sql/negative/06_news_url_unique.sql
\set negative_state :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT negative_example;
RELEASE SAVEPOINT negative_example;
SELECT check_that('Report negative example: news URL UNIQUE', :'negative_state' = '23505');

SAVEPOINT negative_example;
\set ON_ERROR_STOP off
\ir ../sql/negative/07_password_hash_check.sql
\set negative_state :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT negative_example;
RELEASE SAVEPOINT negative_example;
SELECT check_that('Report negative example: password hash CHECK', :'negative_state' = '23514');
