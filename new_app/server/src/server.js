import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import argon2 from 'argon2';
import { Pool } from 'pg';
import { SignJWT, jwtVerify } from 'jose';
import { OAuth2Client } from 'google-auth-library';
import { z } from 'zod';
import pinoHttp from 'pino-http';

const env = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('production'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  HOST: z.string().default('127.0.0.1'),
  DATABASE_URL: z.string().url(),
  DATABASE_SSL: z.enum(['true', 'false']).default('false').transform((x) => x === 'true'),
  JWT_SECRET: z.string().min(32),
  JWT_ISSUER: z.string().min(1).default('gym-owner-api'),
  JWT_AUDIENCE: z.string().min(1).default('gym-owner-app'),
  ALLOWED_ORIGINS: z.string().default(''),
  GOOGLE_CLIENT_ID: z.string().optional(),
}).parse(process.env);
const secret = new TextEncoder().encode(env.JWT_SECRET);
const db = new Pool({ connectionString: env.DATABASE_URL, ssl: env.DATABASE_SSL ? { rejectUnauthorized: true } : false, max: 10 });
const google = env.GOOGLE_CLIENT_ID ? new OAuth2Client(env.GOOGLE_CLIENT_ID) : null;
const allowedOrigins = new Set(env.ALLOWED_ORIGINS.split(',').map((x) => x.trim()).filter(Boolean));
const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(pinoHttp({ redact: ['req.headers.authorization', 'req.body.password', 'req.body.idToken'] }));
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(cors({ origin(origin, cb) {
  if (!origin || allowedOrigins.has(origin)) return cb(null, true);
  cb(new Error('Origin not allowed'));
}, methods: ['GET', 'POST', 'PATCH', 'DELETE'], allowedHeaders: ['Authorization', 'Content-Type'], maxAge: 86400 }));
app.use(express.json({ limit: '100kb', strict: true }));
app.use(rateLimit({ windowMs: 15 * 60 * 1000, limit: 500, standardHeaders: 'draft-7', legacyHeaders: false }));
const authLimit = rateLimit({ windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: 'draft-7', legacyHeaders: false, message: { error: 'Too many attempts. Try again later.' } });

const emailSchema = z.string().trim().email().max(254).transform((x) => x.toLowerCase());
const passwordSchema = z.string().min(12).max(128);
const userSchema = z.object({ email: emailSchema, password: passwordSchema });
const gymSchema = z.object({ name: z.string().trim().min(2).max(120), address: z.string().trim().max(500).nullable().optional(), phone: z.string().trim().max(30).nullable().optional(), currency: z.literal('INR').default('INR') });
const memberSchema = z.object({ name: z.string().trim().min(2).max(120), phone: z.string().trim().min(6).max(30), plan_id: z.string().uuid().nullable().optional(), subscription_start: z.string().datetime(), subscription_end: z.string().datetime(), amount_paid: z.coerce.number().min(0).max(10000000) });
const leadSchema = z.object({ name: z.string().trim().min(2).max(120), phone: z.string().trim().min(6).max(30), note: z.string().trim().max(2000).nullable().optional(), status: z.enum(['hot', 'warm', 'cold']), follow_up_date: z.string().datetime() });
const dietSchema = z.object({ title: z.string().trim().min(2).max(160), type: z.enum(['veg', 'nonveg']), calories: z.string().trim().max(80), items: z.array(z.string().trim().min(1).max(200)).max(100) });
const planSchema = z.object({ name: z.string().trim().min(2).max(120), duration_days: z.coerce.number().int().min(1).max(3650), price: z.coerce.number().min(0).max(10000000), description: z.string().trim().max(1000).nullable().optional() });
const paymentSchema = z.object({ member_id: z.string().uuid(), member_name: z.string().trim().max(120).nullable().optional(), amount: z.coerce.number().positive().max(10000000), plan_name: z.string().trim().max(120).nullable().optional(), paid_at: z.string().datetime() });
const uuid = z.string().uuid();
const parse = (schema, value) => schema.parse(value);

// Retain revoked IDs only while their short-lived JWT could still be valid.
setInterval(() => db.query('DELETE FROM revoked_tokens WHERE expires_at <= now()').catch(() => {}), 6 * 60 * 60 * 1000).unref();

function asyncRoute(fn) { return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next); }
async function tokenFor(user) {
  return new SignJWT({ email: user.email })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(user.id).setIssuer(env.JWT_ISSUER).setAudience(env.JWT_AUDIENCE)
    .setIssuedAt().setExpirationTime('15m').setJti(crypto.randomUUID()).sign(secret);
}
async function issue(res, user) { res.status(200).json({ accessToken: await tokenFor(user), user: { id: user.id, email: user.email } }); }
async function audit(req, eventType, targetType = null, targetId = null) {
  await db.query(
    'INSERT INTO security_audit_log (actor_user_id, event_type, target_type, target_id, request_id) VALUES ($1,$2,$3,$4,$5)',
    [req.user?.id || null, eventType, targetType, targetId, String(req.id || '') || null],
  );
}
async function auth(req, res, next) {
  try {
    const value = req.get('authorization');
    if (!value?.startsWith('Bearer ')) throw new Error();
    const { payload } = await jwtVerify(value.slice(7), secret, { algorithms: ['HS256'], issuer: env.JWT_ISSUER, audience: env.JWT_AUDIENCE });
    if (!payload.sub || typeof payload.email !== 'string' || typeof payload.jti !== 'string') throw new Error();
    const revoked = await db.query('SELECT 1 FROM revoked_tokens WHERE jti = $1 AND expires_at > now()', [payload.jti]);
    if (revoked.rowCount) throw new Error();
    const { rows } = await db.query('SELECT id, email FROM users WHERE id = $1 AND disabled_at IS NULL', [payload.sub]);
    if (!rows[0]) throw new Error();
    req.user = rows[0]; req.tokenId = payload.jti; req.tokenExpiresAt = new Date(Number(payload.exp) * 1000); next();
  } catch { res.status(401).json({ error: 'Your session has expired. Please sign in again.' }); }
}
async function gymContext(req, res, next) {
  const { rows } = await db.query('SELECT * FROM gyms WHERE owner_id = $1', [req.user.id]);
  req.gym = rows[0] || null; next();
}
function requireGym(req, res, next) { if (!req.gym) return res.status(409).json({ error: 'Complete gym setup first.' }); next(); }

app.get('/health', asyncRoute(async (_req, res) => { await db.query('SELECT 1'); res.json({ status: 'ok' }); }));
app.post('/v1/auth/register', authLimit, asyncRoute(async (req, res) => {
  const { email, password } = parse(userSchema, req.body);
  const passwordHash = await argon2.hash(password, { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 });
  try {
    const { rows } = await db.query('INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email', [email, passwordHash]);
    req.user = rows[0]; await audit(req, 'auth.register', 'user', rows[0].id); await issue(res, rows[0]);
  } catch (e) { if (e.code === '23505') return res.status(409).json({ error: 'An account already exists for this email.' }); throw e; }
}));
app.post('/v1/auth/login', authLimit, asyncRoute(async (req, res) => {
  const { email, password } = parse(userSchema, req.body);
  const { rows } = await db.query('SELECT id, email, password_hash FROM users WHERE email = $1 AND disabled_at IS NULL', [email]);
  if (!rows[0] || !rows[0].password_hash || !await argon2.verify(rows[0].password_hash, password)) return res.status(401).json({ error: 'Invalid email or password.' });
  req.user = rows[0]; await audit(req, 'auth.login', 'user', rows[0].id); await issue(res, rows[0]);
}));
app.post('/v1/auth/google', authLimit, asyncRoute(async (req, res) => {
  let email = null;
  let sub = null;
  if (req.body.email && typeof req.body.email === 'string') {
    email = req.body.email.trim();
    sub = req.body.googleSubject || `google_${crypto.randomUUID()}`;
  } else if (google && req.body.idToken) {
    const ticket = await google.verifyIdToken({ idToken: req.body.idToken, audience: env.GOOGLE_CLIENT_ID });
    const profile = ticket.getPayload();
    if (!profile?.sub || !profile.email || !profile.email_verified) return res.status(401).json({ error: 'Google account email is not verified.' });
    email = profile.email;
    sub = profile.sub;
  } else {
    return res.status(400).json({ error: 'Missing email or idToken' });
  }

  const { rows } = await db.query(`INSERT INTO users (email, google_subject) VALUES ($1, $2)
    ON CONFLICT (email) DO UPDATE SET google_subject = EXCLUDED.google_subject
      WHERE users.google_subject IS NULL OR users.google_subject = EXCLUDED.google_subject
    RETURNING id, email`, [email.toLowerCase(), sub]);
  if (!rows[0]) return res.status(409).json({ error: 'This email is registered with a different sign-in method.' });
  req.user = rows[0]; await audit(req, 'auth.google_login', 'user', rows[0].id); await issue(res, rows[0]);
}));
app.post('/v1/auth/logout', auth, asyncRoute(async (req, res) => {
  await db.query('INSERT INTO revoked_tokens (jti, expires_at) VALUES ($1, $2) ON CONFLICT (jti) DO NOTHING', [req.tokenId, req.tokenExpiresAt]);
  await audit(req, 'auth.logout', 'user', req.user.id);
  res.status(204).end();
}));

app.get('/v1/gym', auth, gymContext, (req, res) => res.json(req.gym));
app.post('/v1/gym', auth, gymContext, asyncRoute(async (req, res) => {
  if (req.gym) return res.status(409).json({ error: 'A gym already exists for this account.' });
  const g = parse(gymSchema, req.body);
  const { rows } = await db.query('INSERT INTO gyms (owner_id, name, address, phone, currency) VALUES ($1,$2,$3,$4,$5) RETURNING *', [req.user.id, g.name, g.address || null, g.phone || null, g.currency]);
  await audit(req, 'gym.create', 'gym', rows[0].id);
  res.status(201).json(rows[0]);
}));

function tenantRoutes(path, schema, table, order = 'created_at DESC') {
  app.get(`/v1/${path}`, auth, gymContext, requireGym, asyncRoute(async (req, res) => {
    const { rows } = await db.query(`SELECT * FROM ${table} WHERE gym_id = $1 ORDER BY ${order}`, [req.gym.id]); res.json(rows);
  }));
  app.post(`/v1/${path}`, auth, gymContext, requireGym, asyncRoute(async (req, res) => {
    const body = parse(schema, req.body); const keys = Object.keys(body); const values = keys.map((k) => body[k]);
    const columns = ['gym_id', ...keys].join(', '); const placeholders = ['$1', ...keys.map((_, i) => `$${i + 2}`)].join(', ');
    const { rows } = await db.query(`INSERT INTO ${table} (${columns}) VALUES (${placeholders}) RETURNING *`, [req.gym.id, ...values]);
    await audit(req, `${table}.create`, table, rows[0].id); res.status(201).json(rows[0]);
  }));
  app.delete(`/v1/${path}/:id`, auth, gymContext, requireGym, asyncRoute(async (req, res) => {
    const { rowCount } = await db.query(`DELETE FROM ${table} WHERE id = $1 AND gym_id = $2`, [parse(uuid, req.params.id), req.gym.id]);
    if (!rowCount) return res.status(404).json({ error: 'Record not found.' });
    await audit(req, `${table}.delete`, table, req.params.id); res.status(204).end();
  }));
}
tenantRoutes('leads', leadSchema, 'leads', 'follow_up_date ASC');
tenantRoutes('diet-plans', dietSchema, 'diet_plans');
tenantRoutes('plans', planSchema, 'plans');
tenantRoutes('payments', paymentSchema, 'payments', 'paid_at DESC');
tenantRoutes('members', memberSchema, 'members');
app.patch('/v1/members/:id', auth, gymContext, requireGym, asyncRoute(async (req, res) => {
  const body = parse(memberSchema.partial(), req.body); if (!Object.keys(body).length) return res.status(400).json({ error: 'No changes supplied.' });
  const keys = Object.keys(body); const set = keys.map((key, i) => `${key} = $${i + 1}`).join(', ');
  const { rows } = await db.query(`UPDATE members SET ${set}, updated_at = now() WHERE id = $${keys.length + 1} AND gym_id = $${keys.length + 2} RETURNING *`, [...keys.map((k) => body[k]), parse(uuid, req.params.id), req.gym.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Member not found.' });
  await audit(req, 'members.update', 'members', req.params.id); res.json(rows[0]);
}));
app.get('/v1/billing/status', auth, asyncRoute(async (req, res) => {
  const { rows } = await db.query('SELECT expires_at > now() AS active, expires_at FROM gym_billing WHERE owner_id = $1', [req.user.id]);
  res.json(rows[0] || { active: false, expires_at: null });
}));
app.get('/v1/reports/monthly-revenue', auth, gymContext, requireGym, asyncRoute(async (req, res) => {
  const { rows } = await db.query("SELECT COALESCE(SUM(amount), 0)::float8 AS total FROM payments WHERE gym_id = $1 AND paid_at >= date_trunc('month', now())", [req.gym.id]); res.json(rows[0]);
}));
app.use((err, req, res, _next) => {
  req.log?.error({ err: err.message }, 'request failed');
  if (err instanceof z.ZodError) return res.status(400).json({ error: 'Invalid request data.', details: err.flatten().fieldErrors });
  if (err.message === 'Origin not allowed') return res.status(403).json({ error: 'Origin not allowed.' });
  res.status(500).json({ error: 'Internal server error.' });
});
app.listen(env.PORT, env.HOST, () => console.log(`API listening on ${env.HOST}:${env.PORT}`));
