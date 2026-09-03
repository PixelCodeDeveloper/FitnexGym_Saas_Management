CREATE TABLE IF NOT EXISTS email_otps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email varchar(254) NOT NULL,
  otp_code varchar(6) NOT NULL,
  purpose varchar(20) NOT NULL DEFAULT 'signup',
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_otps_email ON email_otps(email);
CREATE INDEX IF NOT EXISTS idx_email_otps_expiry ON email_otps(expires_at);

GRANT SELECT, INSERT, DELETE ON email_otps TO gym_api;
