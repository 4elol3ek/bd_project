-- Run through run_checks.sql: fixtures and helpers belong to its transaction.
CREATE TEMP TABLE check_results (name text PRIMARY KEY) ON COMMIT DROP;

CREATE FUNCTION check_that(label text, condition boolean) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL: %', label;
  END IF;
  INSERT INTO pg_temp.check_results VALUES (label);
  RAISE NOTICE 'PASS: %', label;
END;
$$;

CREATE FUNCTION expect_error(
  label text,
  statement text,
  expected_state text,
  expected_constraint text DEFAULT NULL,
  expected_column text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  actual_state text;
  actual_constraint text;
  actual_column text;
BEGIN
  -- The exception block rolls back the attempted statement.
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      actual_state = RETURNED_SQLSTATE,
      actual_constraint = CONSTRAINT_NAME,
      actual_column = COLUMN_NAME;
  END;

  IF actual_state IS DISTINCT FROM expected_state
     OR (expected_constraint IS NOT NULL
         AND actual_constraint IS DISTINCT FROM expected_constraint)
     OR (expected_column IS NOT NULL
         AND actual_column IS DISTINCT FROM expected_column) THEN
    RAISE EXCEPTION 'FAIL: %; expected SQLSTATE %, constraint %, column %; got %, %, %',
      label, expected_state, expected_constraint, expected_column,
      coalesce(actual_state, 'no error'), actual_constraint, actual_column;
  END IF;
  PERFORM check_that(label, true);
END;
$$;
