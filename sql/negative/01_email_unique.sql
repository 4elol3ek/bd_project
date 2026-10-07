-- Expected: SQLSTATE 23505, app_user_email_key. Requires the seed.
INSERT INTO app_user (role_id, email, password_hash)
VALUES ((SELECT role_id FROM app_user WHERE email = 'ivan.petrov@example.com'),
        'ivan.petrov@example.com', 'another_test_hash');
