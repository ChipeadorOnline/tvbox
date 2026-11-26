'use strict';

require('dotenv').config();

const express = require('express');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT || 3000);
const ADMIN_TOKEN = process.env.ADMIN_TOKEN;
const PEPPER = process.env.LICENSE_PEPPER || 'CAMBIAR_VALOR_DEV';
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname, 'data', 'licenses.json');

if (!ADMIN_TOKEN) {
  console.error('ERROR: configurá ADMIN_TOKEN antes de iniciar el servidor.');
  process.exit(1);
}

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '32kb' }));
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

function readDb() {
  try {
    return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  } catch {
    return { licenses: [] };
  }
}

function writeDb(db) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  const tmp = `${DATA_FILE}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(db, null, 2));
  fs.renameSync(tmp, DATA_FILE);
}

function hashKey(key) {
  const normalized = String(key)
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');
  return crypto
    .createHash('sha256')
    .update(`${PEPPER}|${normalized}`)
    .digest('hex');
}

function generateKey() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.randomBytes(16);
  const chars = [...bytes].map((b) => alphabet[b % alphabet.length]);
  return [
    chars.slice(0, 4).join(''),
    chars.slice(4, 8).join(''),
    chars.slice(8, 12).join(''),
    chars.slice(12, 16).join(''),
  ].join('-');
}

function safeEqual(a, b) {
  const aa = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  return aa.length === bb.length && crypto.timingSafeEqual(aa, bb);
}

function requireAdmin(req, res, next) {
  const header = req.get('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!safeEqual(token, ADMIN_TOKEN)) {
    return res.status(401).json({ error: 'No autorizado' });
  }
  next();
}

const attempts = new Map();
function rateLimited(ip) {
  const now = Date.now();
  const entry = attempts.get(ip) || { count: 0, resetAt: now + 10 * 60 * 1000 };
  if (now > entry.resetAt) {
    entry.count = 0;
    entry.resetAt = now + 10 * 60 * 1000;
  }
  entry.count += 1;
  attempts.set(ip, entry);
  return entry.count > 10;
}

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, now: new Date().toISOString() });
});

app.post('/api/license/validate', (req, res) => {
  const ip = req.ip || 'unknown';
  if (rateLimited(ip)) {
    return res.status(429).json({ error: 'Demasiados intentos, esperá unos minutos' });
  }

  const key = req.body && req.body.key;
  if (typeof key !== 'string' || key.trim().length < 8) {
    return res.status(400).json({ error: 'Clave inválida' });
  }

  const db = readDb();
  const license = db.licenses.find((l) => l.keyHash === hashKey(key));
  if (!license) {
    return res.status(401).json({ error: 'Clave no encontrada' });
  }
  if (!license.active) {
    return res.status(403).json({ error: 'Licencia inactiva' });
  }
  if (new Date(license.expiresAt).getTime() <= Date.now()) {
    return res.status(403).json({
      error: 'Suscripción vencida',
      expiresAt: license.expiresAt,
    });
  }

  attempts.delete(ip);
  res.json({
    active: true,
    username: license.username || null,
    expiresAt: license.expiresAt,
    plan: license.plan || 'mensual',
  });
});

app.get('/api/admin/licenses', requireAdmin, (_req, res) => {
  const db = readDb();
  res.json({
    licenses: db.licenses.map(({ keyHash, ...rest }) => rest),
  });
});

app.post('/api/admin/licenses', requireAdmin, (req, res) => {
  const username = String((req.body && req.body.username) || '').trim();
  const days = Math.min(Number((req.body && req.body.days) || 30), 3650);
  if (!username) return res.status(400).json({ error: 'Falta username' });

  const key = generateKey();
  const license = {
    id: crypto.randomUUID(),
    username,
    key,
    keyHash: hashKey(key),
    active: true,
    plan: (req.body && req.body.plan) || 'mensual',
    createdAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + days * 86400000).toISOString(),
    note: (req.body && req.body.note) || '',
  };

  const db = readDb();
  db.licenses.push(license);
  writeDb(db);

  const { keyHash, ...publicLicense } = license;
  res.status(201).json(publicLicense);
});

app.post('/api/admin/licenses/:id/renew', requireAdmin, (req, res) => {
  const days = Math.min(Number((req.body && req.body.days) || 30), 3650);
  const db = readDb();
  const license = db.licenses.find((l) => l.id === req.params.id);
  if (!license) return res.status(404).json({ error: 'Licencia no encontrada' });

  const base = Math.max(Date.now(), new Date(license.expiresAt).getTime());
  license.expiresAt = new Date(base + days * 86400000).toISOString();
  license.active = true;
  writeDb(db);

  const { keyHash, ...publicLicense } = license;
  res.json(publicLicense);
});

app.post('/api/admin/licenses/:id/revoke', requireAdmin, (req, res) => {
  const db = readDb();
  const license = db.licenses.find((l) => l.id === req.params.id);
  if (!license) return res.status(404).json({ error: 'Licencia no encontrada' });
  license.active = false;
  writeDb(db);
  const { keyHash, ...publicLicense } = license;
  res.json(publicLicense);
});

// Ejemplo de webhook de pago: conectalo a MercadoPago/Stripe y pasá la clave.
app.post('/api/webhook/payment', (req, res) => {
  const token = req.get('x-webhook-token') || '';
  if (!process.env.WEBHOOK_TOKEN || !safeEqual(token, process.env.WEBHOOK_TOKEN)) {
    return res.status(401).json({ error: 'Webhook no autorizado' });
  }
  const key = req.body && req.body.key;
  const days = Number((req.body && req.body.days) || 30);
  if (typeof key !== 'string') return res.status(400).json({ error: 'Falta key' });

  const db = readDb();
  const license = db.licenses.find((l) => l.keyHash === hashKey(key));
  if (!license) return res.status(404).json({ error: 'Licencia no encontrada' });

  const base = Math.max(Date.now(), new Date(license.expiresAt).getTime());
  license.expiresAt = new Date(base + days * 86400000).toISOString();
  license.active = true;
  writeDb(db);
  res.json({ ok: true, expiresAt: license.expiresAt });
});

app.listen(PORT, () => {
  console.log(`API de licencias escuchando en http://localhost:${PORT}`);
});
