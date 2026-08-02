# Self-hosted VPS deployment

This app no longer uses Supabase. The Flutter client talks only to the Node API, and only the API can reach PostgreSQL.

## Automated production installation (recommended)

Point `api.your-domain.com` to the VPS first. On a clean Ubuntu/Debian VPS, copy the `server` directory and run:

```bash
cd new_app/server
sudo bash deploy/install-vps.sh api.your-domain.com admin@your-domain.com
```

The script installs Docker, Nginx, Certbot and UFW; creates strong database/JWT secrets in `/opt/gym-owner/.env` (mode `600`); starts PostgreSQL and the API; exposes only HTTPS through Nginx; and obtains a TLS certificate. It does **not** expose PostgreSQL or Node ports publicly.

Before accepting customer data, configure encrypted, off-VPS backups and test restore regularly.

## Manual setup

## 1. VPS security baseline

- Use Ubuntu/Debian LTS, SSH keys only, disable password/root SSH login, and enable unattended security updates.
- Allow inbound ports **22** (restricted to your IP), **80**, and **443** only. Do not expose PostgreSQL (`5432`) or Node (`3000`) publicly.
- Point `api.your-domain.com` to the VPS, obtain a TLS certificate with Nginx/Certbot, and enable backups encrypted off the VPS.

## 2. Database

Install PostgreSQL on the VPS. Create a separate database and least-privileged API role; keep PostgreSQL bound to `127.0.0.1`. Apply [schema.sql](server/sql/schema.sql) using a migration/admin account. Do not use the API account for migrations.

## 3. API

```bash
cd new_app/server
cp .env.example .env
# edit .env: a local DATABASE_URL, a 48+ byte random JWT_SECRET, allowed HTTPS origin and Google client ID
npm ci --omit=dev
npm start
```

For Docker, copy `.env.example` to `.env`, set real values, then run `docker compose up -d --build`. The supplied compose file binds the app to localhost and runs it as a non-root, read-only container.

Put Nginx in front of it. Proxy only `https://api.your-domain.com` to `http://127.0.0.1:3000`; set HSTS after TLS is working, limit request body size to `100k`, and use Certbot. Never terminate TLS in the Flutter app or expose port 3000.

## 4. Flutter configuration

There are no backend secrets in Flutter. Build/run with only the public API address:

```bash
flutter run --dart-define=API_BASE_URL=https://api.your-domain.com
flutter build apk --release --dart-define=API_BASE_URL=https://api.your-domain.com
```

For an Android emulator against an HTTP API on your development machine only:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=ALLOW_INSECURE_LOCAL_API=true
```

`ALLOW_INSECURE_LOCAL_API` must never be supplied to a production build.

Email passwords must be at least 12 characters. Access tokens expire after 15 minutes; a future refresh-token endpoint should be added before deploying to production at scale. Google sign-in remains optional: if enabled, configure its OAuth client ID on the server and in the native apps.

## Operations checklist

- Run `pg_dump` daily, encrypt backup files, and regularly restore-test them.
- Monitor `/health`, disk space, failed auth attempts, API errors, PostgreSQL logs, and dependency security updates.
- Rotate `JWT_SECRET`, database password, and payment-provider secrets using a planned forced re-login procedure.
- Razorpay webhooks must verify the provider signature server-side before modifying `gym_billing`; never trust an amount or payment status sent by Flutter.
