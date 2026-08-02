# Security Architecture and OWASP Top 10

This document covers the self-hosted Flutter, Node.js and PostgreSQL replacement for Supabase. It is both an implementation record and an operator runbook. Security is not a one-time feature: the application controls below must be combined with the VPS controls in [DEPLOYMENT.md](DEPLOYMENT.md).

## Change inventory

| Area | Change |
|---|---|
| Flutter | Removed Supabase and client `.env` usage. Added `ApiClient`, secure token storage, self-hosted email/Google authentication, and API-backed database service. |
| API | Added Node/Express API with `/v1/auth`, `/v1/gym`, members, leads, diet plans, plans, payments, billing and report endpoints. |
| Database | Added self-hosted PostgreSQL schema, tenant foreign keys, least-privilege role grants, token-revocation table and audit log. |
| Deployment | Added hardened Docker services, Nginx reverse-proxy template, TLS/firewall installer and VPS runbook. |
| Local development | Added `server/.env` with non-production local-only credentials and debug-only Android HTTP support. Production Android builds remain HTTPS-only. |

### Key files

- `lib/config/api_config.dart`, `lib/services/api_client.dart`, `lib/services/auth_service.dart`, `lib/services/db_service.dart`
- `server/src/server.js`, `server/sql/schema.sql`, `server/sql/migrations/002_security_hardening.sql`
- `server/docker-compose.yml`, `server/deploy/install-vps.sh`, `server/deploy/nginx-api.conf.template`

## Architecture and trust boundaries

```text
Flutter app ── HTTPS + short-lived Bearer JWT ──> Nginx ── localhost ──> Node API
                                                                    │
                                                                    └── private Docker network ──> PostgreSQL
```

- Flutter contains only the public API URL. It never contains a database password, JWT signing secret, Razorpay secret or PostgreSQL connection string.
- Nginx is the only public service. The API is bound to `127.0.0.1:3000`; PostgreSQL has no host port mapping.
- The API derives `owner_id` and `gym_id` from a verified JWT. It does not trust a `gym_id` sent by Flutter.
- PostgreSQL uses an application role (`gym_api`) with only the table permissions the API requires. Schema changes are executed with a separate admin/migration role.

## OWASP Top 10 (2021) implementation

| OWASP risk | Implemented control | Evidence |
|---|---|---|
| A01 Broken Access Control | Every protected route verifies JWT, loads the owner’s gym server-side, and scopes reads, writes, updates and deletes by `gym_id`. Cross-gym member/payment references are blocked by composite foreign keys. | `server/src/server.js`, `server/sql/schema.sql` |
| A02 Cryptographic Failures | TLS is terminated by Nginx/Certbot; production Flutter rejects non-HTTPS APIs; passwords use Argon2id; JWTs are HS256-signed with a 64-byte generated secret; secrets live in a mode-600 VPS `.env`. | `api_config.dart`, installer, server source |
| A03 Injection | All request bodies use allow-list Zod schemas with length/type/range limits. SQL values are parameterized. Dynamic SQL identifiers are application constants, never user input. | `server/src/server.js` |
| A04 Insecure Design | Tenant isolation is enforced in the API and database, billing is server-controlled, payment amount limits exist, default-deny database privileges are used, and critical flows are documented before deployment. | server source and schema |
| A05 Security Misconfiguration | Helmet headers, strict CORS allow-list, 100 KB JSON limit, disabled `X-Powered-By`, production TLS reverse proxy, non-root/read-only API container, dropped capabilities and firewall rules are configured. | `server/src/server.js`, `docker-compose.yml`, installer |
| A06 Vulnerable and Outdated Components | Node 20 runtime is pinned; dependency audit command is provided; image and OS updates are an operational requirement. Deploy only after the audit has no high/moderate findings. | `server/package.json`, deployment runbook |
| A07 Identification and Authentication Failures | Minimum 12-character passwords, Argon2id, login rate limiting, Google ID-token audience verification, short (15 min) JWT lifetime, issuer/audience validation, disabled-user check and server-side logout revocation. Mobile tokens use platform secure storage. | `auth_service.dart`, `server/src/server.js` |
| A08 Software and Data Integrity Failures | Request schemas prevent mass assignment, payment webhooks must be signature-verified server-side, Docker runs a fixed Node base tag, and production environment variables are generated on the VPS rather than supplied in the APK. | schema, server source, deployment guide |
| A09 Security Logging and Monitoring Failures | Structured request logging redacts passwords/tokens. Persistent audit records cover authentication and data mutation events without storing request payloads or credentials. Health checks are available for monitoring. | `server/src/server.js`, schema |
| A10 Server-Side Request Forgery | No endpoint accepts a URL to fetch. OAuth verification only contacts Google’s provider through a fixed library flow; user-controlled callback/fetch URLs are not implemented. | `server/src/server.js` |

## Security-critical configuration

Production requires these values in `/opt/gym-owner/.env`; the installer generates the secrets automatically.

| Variable | Rule |
|---|---|
| `JWT_SECRET` | 64+ random bytes; rotate after a planned forced re-login. Never commit it. |
| `DATABASE_URL` | Docker hostname `db`; never expose it to Flutter. |
| `POSTGRES_*_PASSWORD` | Independent high-entropy passwords; do not reuse them. |
| `ALLOWED_ORIGINS` | Exact comma-separated HTTPS browser origins only. Leave no wildcard. |
| `GOOGLE_CLIENT_ID` | Set only when Google sign-in is configured; leave blank otherwise. |
| `DATABASE_SSL` | `false` only for the private local Docker database. Use `true` for a remote database with a trusted CA. |

## Deployment and operations requirements

1. Run [install-vps.sh](server/deploy/install-vps.sh) only on a freshly patched Ubuntu/Debian VPS after DNS for the API domain is working.
2. Allow only ports 22, 80 and 443. Restrict SSH to known IPs where possible. Do not open 3000 or 5432.
3. Enable automatic OS security updates. Update the Node image and dependencies on a scheduled change window; run `npm run audit:dependencies` before each release.
4. Configure encrypted **off-VPS** PostgreSQL backups and restore-test them at least monthly. A backup stored only on the same VPS is not a disaster-recovery backup.
5. Monitor Nginx, Docker, PostgreSQL disk space, `/health`, repeated `401/429` responses and audit-log anomalies. Send logs to a protected central service for a production business.
6. Set a retention policy for `security_audit_log` based on your legal/privacy needs. Revoked JWT IDs are automatically pruned after expiry.
7. If Razorpay billing is enabled later, create the order and verify the webhook signature on the Node API. Never activate billing from a Flutter-provided payment result.

## Existing database upgrade

For a database created before audit logging/JWT revocation was added, apply [002_security_hardening.sql](server/sql/migrations/002_security_hardening.sql) once as the migration/admin role. Do not run it using `gym_api`.

## Security test checklist before go-live

- Confirm `https://api.your-domain.com/health` works and `http://` redirects to HTTPS.
- Confirm ports 3000 and 5432 are unreachable externally.
- Create two gym owners and verify each cannot read, update or delete the other owner’s UUIDs.
- Confirm a logged-out access token gets `401` immediately.
- Send malformed, oversized and SQL-like JSON values; API must return `400` without SQL errors.
- Confirm logs contain no password, JWT, payment secret or full request body.
- Run `npm run audit:dependencies`, verify backups restore, and test a JWT-secret rotation procedure.

## Important limits

No document or codebase can honestly guarantee “complete security” by itself. Email verification/password reset, MFA, centralized log retention, vulnerability scanning, encrypted offsite backups and payment webhooks require infrastructure/provider choices and must be enabled before a high-risk or regulated launch. The current implementation does not pretend those external services already exist.
