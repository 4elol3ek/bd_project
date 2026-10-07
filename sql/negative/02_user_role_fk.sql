-- Expected: SQLSTATE 23503, fk_user_role. Generated roles have positive IDs.
INSERT INTO app_user (role_id, email, password_hash)
VALUES (-1, 'missing.role@example.test', 'another_test_hash');
