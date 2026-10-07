
-- Регистрация нового пользователя
INSERT INTO app_user (role_id, email, password_hash)
VALUES (
    2,
    'new.user@example.com',
    'secure_password_123'
)
RETURNING id; 

-- Изменение данных пользователя
UPDATE app_user
SET email = 'updated.user@example.com'
WHERE id = 4;
