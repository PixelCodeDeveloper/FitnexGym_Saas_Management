-- Self-hosted PostgreSQL schema. Run as a dedicated migration role, not the API role.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email varchar(254) NOT NULL UNIQUE,
  password_hash text,
  google_subject text UNIQUE,
  disabled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_login_method CHECK (password_hash IS NOT NULL OR google_subject IS NOT NULL)
);
CREATE TABLE gyms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT,
  name varchar(120) NOT NULL,
  address varchar(500), phone varchar(30), currency char(3) NOT NULL DEFAULT 'INR',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT gyms_currency CHECK (currency = 'INR')
);
CREATE TABLE plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), gym_id uuid NOT NULL REFERENCES gyms(id) ON DELETE CASCADE,
  name varchar(120) NOT NULL, duration_days integer NOT NULL CHECK (duration_days BETWEEN 1 AND 3650),
  price numeric(12,2) NOT NULL CHECK (price >= 0), description varchar(1000), created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (gym_id, id)
);
CREATE TABLE members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), gym_id uuid NOT NULL REFERENCES gyms(id) ON DELETE CASCADE,
  name varchar(120) NOT NULL, phone varchar(30) NOT NULL, plan_id uuid,
  subscription_start timestamptz NOT NULL, subscription_end timestamptz NOT NULL,
  amount_paid numeric(12,2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT members_dates CHECK (subscription_end >= subscription_start),
  CONSTRAINT members_plan_same_gym FOREIGN KEY (gym_id, plan_id) REFERENCES plans(gym_id, id) ON DELETE RESTRICT,
  UNIQUE (gym_id, id)
);
CREATE TABLE leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), gym_id uuid NOT NULL REFERENCES gyms(id) ON DELETE CASCADE,
  name varchar(120) NOT NULL, phone varchar(30) NOT NULL, note varchar(2000),
  status varchar(10) NOT NULL CHECK (status IN ('hot','warm','cold')), follow_up_date timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE diet_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), gym_id uuid NOT NULL REFERENCES gyms(id) ON DELETE CASCADE,
  title varchar(160) NOT NULL, type varchar(10) NOT NULL CHECK (type IN ('veg','nonveg')),
  calories varchar(80) NOT NULL, items jsonb NOT NULL CHECK (jsonb_typeof(items) = 'array'), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), gym_id uuid NOT NULL REFERENCES gyms(id) ON DELETE CASCADE,
  member_id uuid NOT NULL, member_name varchar(120), amount numeric(12,2) NOT NULL CHECK (amount > 0),
  plan_name varchar(120), paid_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT payments_member_same_gym FOREIGN KEY (gym_id, member_id) REFERENCES members(gym_id, id) ON DELETE RESTRICT
);
CREATE TABLE gym_billing (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT,
  expires_at timestamptz NOT NULL, provider varchar(30), provider_payment_id varchar(255) UNIQUE, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE revoked_tokens (
  jti uuid PRIMARY KEY, expires_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE security_audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  event_type varchar(80) NOT NULL, target_type varchar(80), target_id uuid,
  request_id varchar(128), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX members_gym_created_idx ON members (gym_id, created_at DESC);
CREATE INDEX leads_gym_followup_idx ON leads (gym_id, follow_up_date);
CREATE INDEX payments_gym_paid_idx ON payments (gym_id, paid_at DESC);
CREATE INDEX revoked_tokens_expiry_idx ON revoked_tokens (expires_at);
CREATE INDEX security_audit_log_created_idx ON security_audit_log (created_at DESC);

-- Defense in depth: the API role has data access only, no schema or DDL privilege.
REVOKE ALL ON DATABASE gym_owner FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE gym_owner TO gym_api;
GRANT USAGE ON SCHEMA public TO gym_api;
GRANT SELECT, INSERT, UPDATE ON users TO gym_api;
GRANT SELECT, INSERT ON gyms, gym_billing TO gym_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON plans, members, leads, diet_plans, payments TO gym_api;
GRANT SELECT, INSERT, DELETE ON revoked_tokens TO gym_api;
GRANT INSERT ON security_audit_log TO gym_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO gym_api;
