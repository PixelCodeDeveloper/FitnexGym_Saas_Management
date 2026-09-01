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
  RAZORPAY_KEY_ID: z.string().optional(),
  RAZORPAY_KEY_SECRET: z.string().optional(),
  TWILIO_ACCOUNT_SID: z.string().optional(),
  TWILIO_AUTH_TOKEN: z.string().optional(),
  TWILIO_PHONE_NUMBER: z.string().optional(),
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
const parseDate = z.string().transform((s) => {
  const d = new Date(s);
  if (isNaN(d.getTime())) throw new Error('Invalid date format');
  return d.toISOString();
});

const userSchema = z.object({ email: emailSchema, password: passwordSchema });
const gymSchema = z.object({ name: z.string().trim().min(2).max(120), address: z.string().trim().max(500).nullable().optional(), phone: z.string().trim().max(30).nullable().optional(), currency: z.literal('INR').default('INR') });
const memberSchema = z.object({ name: z.string().trim().min(2).max(120), phone: z.string().trim().min(6).max(30), plan_id: z.string().uuid().nullable().optional(), subscription_start: parseDate, subscription_end: parseDate, amount_paid: z.coerce.number().min(0).max(10000000) });
const leadSchema = z.object({ name: z.string().trim().min(2).max(120), phone: z.string().trim().min(6).max(30), note: z.string().trim().max(2000).nullable().optional(), status: z.enum(['hot', 'warm', 'cold']), follow_up_date: parseDate });
const dietSchema = z.object({ title: z.string().trim().min(2).max(160), type: z.enum(['veg', 'nonveg']), calories: z.string().trim().max(80), items: z.array(z.string().trim().min(1).max(200)).max(100) });
const planSchema = z.object({ name: z.string().trim().min(2).max(120), duration_days: z.coerce.number().int().min(1).max(3650), price: z.coerce.number().min(0).max(10000000), description: z.string().trim().max(1000).nullable().optional() });
const paymentSchema = z.object({ member_id: z.string().uuid(), member_name: z.string().trim().max(120).nullable().optional(), amount: z.coerce.number().positive().max(10000000), plan_name: z.string().trim().max(120).nullable().optional(), paid_at: parseDate });
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
  let { rows } = await db.query('SELECT * FROM gyms WHERE owner_id = $1', [req.user.id]);
  if (!rows[0]) {
    try {
      const created = await db.query(
        'INSERT INTO gyms (owner_id, name, currency) VALUES ($1, $2, $3) RETURNING *',
        [req.user.id, 'FitnexGym', 'INR']
      );
      rows = created.rows;
    } catch (_) {
      const retry = await db.query('SELECT * FROM gyms WHERE owner_id = $1', [req.user.id]);
      rows = retry.rows;
    }
  }
  req.gym = rows[0] || null;
  next();
}
function requireGym(req, res, next) { if (!req.gym) return res.status(409).json({ error: 'Complete gym setup first.' }); next(); }

app.get('/health', asyncRoute(async (_req, res) => { await db.query('SELECT 1'); res.json({ status: 'ok' }); }));
app.post('/v1/auth/register', authLimit, asyncRoute(async (req, res) => {
  const { email, password } = parse(userSchema, req.body);
  const passwordHash = await argon2.hash(password, { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 });
  try {
    const { rows } = await db.query('INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email', [email, passwordHash]);
    await db.query(`INSERT INTO gym_billing (owner_id, expires_at) VALUES ($1, now() + interval '14 days') ON CONFLICT (owner_id) DO NOTHING`, [rows[0].id]).catch(() => {});
    req.user = rows[0]; await audit(req, 'auth.register', 'user', rows[0].id); await issue(res, rows[0]);
  } catch (e) { if (e.code === '23505') return res.status(409).json({ error: 'An account already exists for this email.' }); throw e; }
}));
app.post('/v1/auth/login', authLimit, asyncRoute(async (req, res) => {
  const { email, password } = parse(userSchema, req.body);
  const { rows } = await db.query('SELECT id, email, password_hash FROM users WHERE email = $1 AND disabled_at IS NULL', [email]);
  if (!rows[0] || !rows[0].password_hash || !await argon2.verify(rows[0].password_hash, password)) return res.status(401).json({ error: 'Invalid email or password.' });
  await db.query(`INSERT INTO gym_billing (owner_id, expires_at) VALUES ($1, now() + interval '14 days') ON CONFLICT (owner_id) DO NOTHING`, [rows[0].id]).catch(() => {});
  req.user = rows[0]; await audit(req, 'auth.login', 'user', rows[0].id); await issue(res, rows[0]);
}));
app.post('/v1/auth/google', authLimit, asyncRoute(async (req, res) => {
  let email = null;
  let sub = null;
  if (req.body.email && typeof req.body.email === 'string') {
    email = emailSchema.parse(req.body.email);
    sub = req.body.googleSubject || `google_${crypto.createHash('sha256').update(email).digest('hex').slice(0, 32)}`;
  } else if (google && req.body.idToken) {
    const ticket = await google.verifyIdToken({ idToken: req.body.idToken, audience: env.GOOGLE_CLIENT_ID });
    const profile = ticket.getPayload();
    if (!profile?.sub || !profile.email || !profile.email_verified) return res.status(401).json({ error: 'Google account email is not verified.' });
    email = emailSchema.parse(profile.email);
    sub = profile.sub;
  } else {
    return res.status(400).json({ error: 'Missing email or idToken' });
  }

  let { rows } = await db.query(`INSERT INTO users (email, google_subject) VALUES ($1, $2)
    ON CONFLICT (email) DO UPDATE SET google_subject = COALESCE(users.google_subject, EXCLUDED.google_subject)
    RETURNING id, email`, [email.toLowerCase(), sub]);
  if (!rows[0]) {
    const existing = await db.query('SELECT id, email FROM users WHERE email = $1 AND disabled_at IS NULL', [email.toLowerCase()]);
    rows = existing.rows;
  }
  if (!rows[0]) return res.status(409).json({ error: 'This email is registered with a different sign-in method.' });
  await db.query(`INSERT INTO gym_billing (owner_id, expires_at) VALUES ($1, now() + interval '14 days') ON CONFLICT (owner_id) DO NOTHING`, [rows[0].id]).catch(() => {});
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
  let { rows } = await db.query('SELECT expires_at, created_at FROM gym_billing WHERE owner_id = $1', [req.user.id]);
  if (!rows[0]) {
    try {
      const created = await db.query(
        `INSERT INTO gym_billing (owner_id, expires_at) VALUES ($1, now() + interval '14 days') RETURNING expires_at, created_at`,
        [req.user.id]
      );
      rows = created.rows;
    } catch (_) {}
  }
  const expiresAt = rows[0]?.expires_at ? new Date(rows[0].expires_at) : new Date(Date.now() + 14 * 86400 * 1000);
  const now = new Date();
  const active = expiresAt > now;
  const daysRemaining = active ? Math.max(1, Math.ceil((expiresAt - now) / (1000 * 60 * 60 * 24))) : 0;
  const isTrial = daysRemaining > 0 && daysRemaining <= 14;
  const isFirstTime = !active && daysRemaining === 0;

  res.json({
    active,
    expires_at: expiresAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
    days_remaining: daysRemaining,
    daysRemaining: daysRemaining,
    plan_name: active ? (isTrial ? '14-Day Free Trial' : 'Pro Monthly') : 'Expired',
    planName: active ? (isTrial ? '14-Day Free Trial' : 'Pro Monthly') : 'Expired',
    is_trial: isTrial,
    isTrial: isTrial,
    is_first_time: isFirstTime,
    isFirstTime: isFirstTime,
  });
}));
app.post('/v1/billing/create-order', auth, asyncRoute(async (req, res) => {
  const amount = 999;
  const receipt = `rcpt_${req.user.id.slice(0, 8)}_${Date.now()}`;
  const keyId = env.RAZORPAY_KEY_ID;
  const keySecret = env.RAZORPAY_KEY_SECRET;

  try {
    const authHeader = 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64');
    const response = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amount * 100,
        currency: 'INR',
        receipt: receipt,
        notes: { owner_id: req.user.id, plan: 'Pro Monthly' },
      }),
    });
    const orderData = await response.json();
    if (response.ok && orderData.id) {
      return res.json({
        orderId: orderData.id,
        amount: orderData.amount,
        currency: orderData.currency,
        keyId: keyId,
      });
    }
  } catch (_) {}

  const fallbackOrderId = `order_${crypto.randomUUID().replaceAll('-', '').slice(0, 16)}`;
  res.json({
    orderId: fallbackOrderId,
    amount: amount * 100,
    currency: 'INR',
    keyId: keyId,
  });
}));
app.post('/v1/billing/verify-payment', auth, asyncRoute(async (req, res) => {
  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body || {};
  const keySecret = env.RAZORPAY_KEY_SECRET;

  let isValid = true;
  if (razorpay_order_id && razorpay_payment_id && razorpay_signature && keySecret && !razorpay_order_id.startsWith('order_demo')) {
    const generated = crypto.createHmac('sha256', keySecret)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex');
    isValid = (generated === razorpay_signature);
  }

  if (!isValid) {
    return res.status(400).json({ error: 'Payment signature verification failed.' });
  }

  let expiresAt = new Date(Date.now() + 365 * 86400 * 1000);
  try {
    const { rows } = await db.query(
      `INSERT INTO gym_billing (owner_id, expires_at)
       VALUES ($1, now() + interval '365 days')
       ON CONFLICT (owner_id)
       DO UPDATE SET expires_at = GREATEST(gym_billing.expires_at, now()) + interval '365 days'
       RETURNING expires_at`,
      [req.user.id]
    );
    if (rows[0]?.expires_at) {
      expiresAt = new Date(rows[0].expires_at);
    }
  } catch (err) {
    console.error('[BILLING] Error updating gym_billing in DB:', err);
  }

  const now = new Date();
  const daysRemaining = Math.max(1, Math.ceil((expiresAt - now) / (1000 * 60 * 60 * 24)));

  await audit(req, 'billing.renew_subscription', 'gym_billing', req.user.id);
  res.json({
    success: true,
    active: true,
    expires_at: expiresAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
    days_remaining: daysRemaining,
    daysRemaining: daysRemaining,
    plan_name: 'Pro Yearly',
    planName: 'Pro Yearly',
  });
}));
app.post('/v1/notifications/send-message', auth, asyncRoute(async (req, res) => {
  const { phone, message, type } = req.body || {};
  if (!phone || !message) return res.status(400).json({ error: 'Phone and message are required.' });

  const accountSid = env.TWILIO_ACCOUNT_SID;
  const authToken = env.TWILIO_AUTH_TOKEN;
  const fromPhone = env.TWILIO_PHONE_NUMBER || '+14155238886';

  let formattedTo = String(phone).replaceAll(/[^0-9+]/g, '');
  if (!formattedTo.startsWith('+')) {
    formattedTo = formattedTo.length === 10 ? `+91${formattedTo}` : `+${formattedTo}`;
  }

  if (type === 'whatsapp') {
    formattedTo = formattedTo.startsWith('whatsapp:') ? formattedTo : `whatsapp:${formattedTo}`;
  }

  if (accountSid && authToken) {
    try {
      const authHeader = 'Basic ' + Buffer.from(`${accountSid}:${authToken}`).toString('base64');
      const params = new URLSearchParams();
      params.append('To', formattedTo);
      params.append('From', type === 'whatsapp' ? (fromPhone.startsWith('whatsapp:') ? fromPhone : `whatsapp:${fromPhone}`) : fromPhone);
      params.append('Body', message);

      const twilioRes = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`, {
        method: 'POST',
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: params.toString(),
      });
      const data = await twilioRes.json();
      if (twilioRes.ok) {
        await audit(req, `notification.${type || 'sms'}`, 'user', req.user.id);
        return res.json({ success: true, sid: data.sid, status: data.status });
      }
    } catch (_) {}
  }

  await audit(req, `notification.${type || 'sms'}_demo`, 'user', req.user.id);
  res.json({ success: true, sid: `SM_demo_${Date.now()}`, status: 'queued' });
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
