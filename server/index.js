'use strict';

require('dotenv').config();

const express = require('express');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT || 3000);
const ADMIN_TOKEN = process.env.ADMIN_TOKEN;
const SECRET = process.env.LICENSE_PEPPER || 'CAMBIAR_PEPPER';

if (!ADMIN_TOKEN) {
  console.error('ERROR: configurá ADMIN_TOKEN antes de iniciar el servidor.');
  process.exit(1);
}

// Base32 sin caracteres confusos. 10 bytes => 16 caracteres => XXXX-XXXX-XXXX-XXXX
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function encodeKey(bytes) {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out += ALPHABET[(value >> bits) & 31];
    }
  }
  if (bits > 0) out += ALPHABET[(value << (5 - bits)) & 31];
  return out.match(/.{1,4}/g).join('-');
}

function decodeKey(key) {
  const clean = String(key).toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (clean.length !== 16) return null;
  let bits = 0;
  let value = 0;
  const bytes = [];
  for (const char of clean) {
    const index = ALPHABET.indexOf(char);
    if (index < 0) return null;
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((value >> bits) & 255);
    }
  }
  return bytes.length === 10 ? Buffer.from(bytes) : null;
}

function sign(payload) {
  return crypto.createHmac('sha256', SECRET).update(payload).digest();
}

function createKey(username, days) {
  const expiresSeconds =
    Math.floor(Date.now() / 1000) + Math.min(Number(days) || 30, 3650) * 86400;
  const userId = crypto.randomBytes(2).readUInt16BE(0);
  const bytes = Buffer.alloc(10);
  bytes.writeUInt32BE(expiresSeconds, 0);
  bytes.writeUInt16BE(userId, 4);
  sign(bytes.subarray(0, 6)).copy(bytes, 6, 0, 4);
  return {
    username: String(username || '').trim() || null,
    key: encodeKey(bytes),
    expiresAt: new Date(expiresSeconds * 1000).toISOString(),
    plan: 'mensual',
  };
}

function checkKey(key) {
  const bytes = decodeKey(key);
  if (!bytes) return null;
  const expected = sign(bytes.subarray(0, 6));
  if (!crypto.timingSafeEqual(bytes.subarray(6, 10), expected.subarray(0, 4))) {
    return null;
  }
  const expiresAt = bytes.readUInt32BE(0) * 1000;
  if (expiresAt <= Date.now()) return null;
  return { active: true, expiresAt: new Date(expiresAt).toISOString(), plan: 'mensual' };
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

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '16kb' }));
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, now: new Date().toISOString() });
});

// Panel para generar claves de clientes sin exponer el token administrativo.
app.get('/admin', (_req, res) => {
  res.type('html').send(
    fs.readFileSync(path.join(__dirname, 'admin.html'), 'utf8'),
  );
});

app.post('/api/admin/ui-create', (req, res) => {
  const body = req.body || {};
  if (!safeEqual(String(body.password || ''), ADMIN_TOKEN)) {
    return res.status(401).json({ error: 'Contraseña incorrecta' });
  }
  res.status(201).json(createKey(body.username, body.days || 30));
});

app.post('/api/license/validate', (req, res) => {
  const key = req.body && req.body.key;
  if (typeof key !== 'string') {
    return res.status(400).json({ error: 'Clave inválida' });
  }
  const result = checkKey(key);
  if (!result) {
    return res.status(403).json({ error: 'Clave inválida o vencida' });
  }
  res.json(result);
});

// Emite una clave nueva. Para renovar, generá otra con más días.
app.post('/api/admin/licenses', requireAdmin, (req, res) => {
  const body = req.body || {};
  const license = createKey(body.username, body.days || 30);
  res.status(201).json(license);
});

app.listen(PORT, () => {
  console.log(`API de licencias escuchando en 0.0.0.0:${PORT}`);
});
