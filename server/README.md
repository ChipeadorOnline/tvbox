# API de licencias (sin base de datos)

La clave contiene la fecha de vencimiento y una firma HMAC. El servidor no
guarda nada: por eso funciona en hosting gratuito aunque se reinicie.

## Arrancar

```bash
cd server
npm install
cp .env.example .env
# editá ADMIN_TOKEN y LICENSE_PEPPER
npm start
```

Variables:

- `ADMIN_TOKEN`: token para emitir claves (obligatorio).
- `LICENSE_PEPPER`: secreto con el que se firman las claves. **No lo cambies nunca** o todas las claves emitidas dejarán de funcionar.
- `PORT`: por defecto 3000.

## Endpoints

### Verificar clave (la usa la app)

`POST /api/license/validate`

```json
{ "key": "ABCD-EFGH-IJKL-MNOP" }
```

Respuesta:

```json
{ "active": true, "expiresAt": "2026-12-26T00:00:00.000Z", "plan": "mensual" }
```

La clave se acepta en mayúsculas/minúsculas y con o sin guiones.

### Emitir clave (admin)

```bash
curl -X POST https://TU_API/api/admin/licenses \
  -H "Authorization: Bearer TU_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"juan","days":30}'
```

Devuelve `username`, `key`, `expiresAt` y `plan`. Para renovar un abono,
emití una clave nueva con 30 días más y entregala al usuario.

No hay base de datos, por lo que no hay endpoints de revocar/listar. Si
necesitás revocar claves, cambiá `LICENSE_PEPPER` (invalida todas) o pasá a
una versión con base de datos persistente.
