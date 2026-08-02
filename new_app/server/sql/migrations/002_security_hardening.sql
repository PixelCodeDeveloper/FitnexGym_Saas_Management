-- Apply once to an installation created with the earlier schema version.
-- Run as the PostgreSQL migration/admin role, never as gym_api.
BEGIN;

CREATE TABLE IF NOT EXISTS revoked_tokens (
  jti uuid PRIMARY KEY, expires_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS security_audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  event_type varchar(80) NOT NULL, target_type varchar(80), target_id uuid,
  request_id varchar(128), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS revoked_tokens_expiry_idx ON revoked_tokens (expires_at);
CREATE INDEX IF NOT EXISTS security_audit_log_created_idx ON security_audit_log (created_at DESC);

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM gym_api;
GRANT SELECT, INSERT, UPDATE ON users TO gym_api;
GRANT SELECT, INSERT ON gyms, gym_billing TO gym_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON plans, members, leads, diet_plans, payments TO gym_api;
GRANT SELECT, INSERT, DELETE ON revoked_tokens TO gym_api;
GRANT INSERT ON security_audit_log TO gym_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO gym_api;
COMMIT;
