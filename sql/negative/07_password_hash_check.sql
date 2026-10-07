-- The former invalid seed INSERT belongs here.
-- Expected: SQLSTATE 23514, app_user_password_hash_check. Requires the seed.
INSERT INTO app_user (role_id, email, password_hash)
VALUES ((SELECT id FROM role WHERE name = 'Зарегистрированный пользователь'),
        'bigrussianboss@example.com', 'brbrbr');
