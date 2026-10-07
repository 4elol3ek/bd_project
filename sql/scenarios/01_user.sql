-- Run after the seed, inside the transaction started by run_demo.sql.
DO $$
DECLARE
  v_user_id bigint;
  v_role_id integer;
BEGIN
  SELECT id INTO STRICT v_role_id FROM role WHERE name = 'Зарегистрированный пользователь';

  INSERT INTO app_user (role_id, email, password_hash)
    VALUES (v_role_id, 'new.user@example.com', 'scrypt$16384$8$1$6c61622d6e65775f75736572$e9810b49f77d778c80e9dd9ed37a9fff8c64898a321b058b877b034b579dceaf')
    RETURNING id INTO v_user_id;

  -- Update the account actually created above, regardless of sequence gaps.
  UPDATE app_user SET email = 'updated.user@example.com' WHERE id = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Created user was not updated';
  END IF;
END;
$$;

SELECT id, email, role_id FROM app_user WHERE email = 'updated.user@example.com';
