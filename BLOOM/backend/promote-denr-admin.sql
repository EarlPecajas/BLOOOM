BEGIN;

UPDATE account
SET account_type_id = (
      SELECT account_type_id
      FROM account_type
      WHERE lower(account_desc) = 'admin'
      LIMIT 1
    ),
    username = CASE
      WHEN lower(coalesce(username, '')) = lower(email)
        THEN split_part(email, '@', 1)
      ELSE username
    END
WHERE lower(email) = lower('DENR@gmail.com')
   OR lower(coalesce(username, '')) = lower('DENR');

COMMIT;
