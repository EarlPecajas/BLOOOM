BEGIN;

ALTER TABLE biogeography
ADD COLUMN IF NOT EXISTS submission_status VARCHAR(30) NOT NULL DEFAULT 'pending';

ALTER TABLE biogeography
DROP CONSTRAINT IF EXISTS biogeography_submission_status_check;

ALTER TABLE biogeography
ADD CONSTRAINT biogeography_submission_status_check
CHECK (lower(submission_status) IN ('approved', 'rejected', 'revision', 'pending'));

COMMIT;
