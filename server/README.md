# API de licencias

Servidor mínimo con Express para usuarios, claves de acceso y abono mensual.

## Arrancar

```bash
cd server
npm install
cp .env.example .env   # editá los valores
npm start
```

Variables:

- `ADMIN_TOKEN`: token para crear/renovar/revocar licencias (obligatorio).
- `LICENSE_PEPPER`: secreto para hashear las claves. **No lo cambies después** o todas las claves dejarán de funcionar.
- `WEBHOOK_TOKEN`: secreto del webhook de pago.
- `DATA_FILE`: archivo JSON donde se guardan las licencias.

## Endpoints

### Verificar clave (usa la app)

`POST /api/license/validate`

```json
{ "key": "ABCD-EFGH-IJKL-MNOP" }
```

Respuesta:

```json
{ "active": true, "username": "juan", "expiresAt": "2026-12-26T00:00:00.000Z", "plan": "mensual" }
```

### Crear licencia (admin)

```bash
curl -X POST http://localhost:3000/api/admin/licenses \
  -H "Authorization: Bearer TU_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"juan","days":30}'
```

### Renovar / revocar

```bash
curl -X POST http://localhost:3000/api/admin/licenses/<ID>/renew \
  -H "Authorization: Bearer TU_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"days":30}'
```

### Webhook de pago

`POST /api/webhook/payment` con header `x-webhook-token` y body
`{"key":"ABCD-EFGH-IJKL-MNOP","days":30}`. Conectalo al webhook de tu
proveedor de pagos para renovar automáticamente.

## Producción

- Poné la API detrás de HTTPS (nginx + Let's Encrypt o Cloudflare Tunnel).
- Compilá la app con `--dart-define=API_URL=https://tu-dominio.com`.
- Hacé backup de `data/licenses.json` y guardá `LICENSE_PEPPER` de forma segura.
