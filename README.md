# Actualizador para TV Box

Proyecto para instalar en Android TV / Google TV. La app:

1. Pide **usuario/clave** y valida el **abono mensual** contra tu API.
2. Lee `catalog.json` desde GitHub y detecta apps nuevas o cambios de `versionCode`.
3. Descarga el APK y **abre el instalador de Android** automáticamente.
4. Chequea novedades cada 6 h en segundo plano y al abrir la app.

> Limitación de Android: no se puede instalar un APK sin que el usuario confirme,
> salvo que el equipo sea root, esté firmado con la clave del sistema o sea
> *device owner*. Lo que sí se automatiza es la descarga y la apertura del
> instalador.

> Solo incluí la infraestructura. **No agregué los APKs modificados** del
> release `v1` (NetFlix Mod+, "Premium", "Sin VPN", etc.) ni mecanismos para
> saltar suscripciones de terceros. Agregá al catálogo únicamente apps que
> tengas derecho a distribuir.

## Estructura

```
index.html                 web actual (catálogo en GitHub Pages)
catalog.json               catálogo que consume la app (editable sin recompilar)
catalog.example.json       ejemplo de entrada
tvbox_app/                 proyecto Flutter (Android)
server/                    API de licencias (Node + Express)
.github/workflows/         compilación y Release del APK
```

## 1. Probar la API

```bash
cd server
npm install
cp .env.example .env
# editá ADMIN_TOKEN y LICENSE_PEPPER
npm start
```

La clave se escribe en mayúsculas y con guiones (`XXXX-XXXX-XXXX-XXXX`). La app
la formatea sola y el servidor la acepta con o sin guiones.

Clave de prueba vigente hasta el 2026-12-26: `PN2B-9XBY-DJVR-KTSN`
Link corto del APK para el TV Box: `https://is.gd/LwXmUp`

Crear una clave de prueba:

```bash
curl -X POST http://localhost:3000/api/admin/licenses ^
  -H "Authorization: Bearer TU_ADMIN_TOKEN" ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"prueba\",\"days\":30}"
```

## 2. Probar la app en Windows / emulador

```bash
cd tvbox_app
flutter pub get
flutter run \
  --dart-define=API_URL=http://10.0.2.2:3000
```

`10.0.2.2` es el host desde el emulador de Android. En un TV Box real usá la
IP o dominio de tu servidor.

## 3. Generar el APK firmado

Crear keystore **una sola vez** y guardarlo bien (si lo perdés, tus usuarios no
podrán actualizar):

```bash
keytool -genkey -v -keystore tvbox-release.jks -alias tvbox ^
  -keyalg RSA -keysize 2048 -validity 10000
```

Localmente podés poner en `tvbox_app/android/local.properties`:

```properties
KEYSTORE_FILE=C:/ruta/a/tvbox-release.jks
KEYSTORE_PASSWORD=...
KEY_ALIAS=tvbox
KEY_PASSWORD=...
```

Y compilar con el script incluido (firma release incluida):

```powershell
.\build-release.ps1 -ApiUrl "https://tu-dominio.com"
```

O directamente:

```bash
flutter build apk --release \
  --dart-define=API_URL=https://tu-dominio.com \
  --dart-define=CATALOG_URL=https://raw.githubusercontent.com/ChipeadorOnline/tvbox/main/catalog.json
```

El APK queda en `tvbox_app/build/app/outputs/flutter-apk/app-release.apk` y una
copia en `apk/tvbox-updater-release.apk`.

> En esta PC el keystore está en `keystore/tvbox-release.jks` y las claves en
> `C:\Users\ChipeadorOnline\Documents\tvbox-release-secrets.txt` (fuera del repo).
> **No subas ese archivo a GitHub.** La huella del certificado es
> `2C:BC:D5:E2:EB:1B:14:08:83:34:D3:B9:D0:2D:71:B9:F2:E7:73:8D:4A:CF:0B:18:11:9A:48:0E:E9:F7:12:69:A`.
> APK publicado por GitHub Actions:
> https://github.com/ChipeadorOnline/tvbox/releases/download/v1.0.9/app-release.apk
>
> Está compilado apuntando a la API fija de Render
> `https://tvbox-license.onrender.com`, así que **no depende de que esta PC esté
> encendida**. Para cambiarla, actualizá la variable `API_URL` en GitHub y
> pusheá un tag nuevo.

En GitHub agregá los Secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
`KEY_PASSWORD` y la variable `API_URL`. Al pushear un tag `v*`, el workflow
compila y sube el APK al Release. El workflow `keep-alive.yml` hace un ping cada
10 minutos para que el plan gratuito de Render no se duerma.

Para generar el base64 del keystore en PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("tvbox-release.jks"))
```

## 4. Cargar apps al catálogo

Editá `catalog.json` y subilo a `main`. Cada entrada:

```json
{
  "id": "identificador-unico",
  "name": "Nombre visible",
  "fileName": "nombre-del-archivo.apk",
  "url": "https://.../nombre-del-archivo.apk",
  "version": "2.0",
  "versionCode": 2,
  "size": 12345678,
  "sha256": "hash opcional",
  "notes": "Novedades"
}
```

Subí `versionCode` cuando cambie el APK: la appdetecta el cambio y muestra el
aviso "Hay novedades". Si `sha256` está completo, se verifica la descarga.

## 5. Instalar en el TV Box

1. Copiá el APK (USB, SendFiles, Downloader, etc.).
2. Instalalo y activá en **Ajustes → Seguridad → Instalar apps desconocidas**
   la primera vez; la app abre esa pantalla cuando hace falta.
3. Ingresá la clave del abono.
4. Para usarlo como **launcher**: en el box, poné *Inicio → configurar pantalla de inicio*
   y elegí **Actualizador TV**. Desde entonces, al encender o apretar Home se abre
   directamente la app con el catálogo de los clientes.

## Administrar clientes

Panel web: **https://tvbox-license.onrender.com/admin**

Ahí cargás la contraseña de administrador (el `ADMIN_TOKEN` de Render), el nombre
del cliente y los días de abono. El panel genera una clave `XXXX-XXXX-XXXX-XXXX`
y la podés copiar para mandarla al cliente por WhatsApp/email. La clave vence
sola en la fecha indicada y la app deja de entrar automáticamente.

También se puede generar por API:

```bash
curl -X POST https://tvbox-license.onrender.com/api/admin/licenses \
  -H "Authorization: Bearer TU_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"cliente","days":30}'
```

## Entregar apps a los clientes

Cargá cada APK en `catalog.json` con su URL HTTPS y su `versionCode`. Cuando
subás el `versionCode`, la app muestra aviso de novedades y el cliente descarga
e instala desde ahí. Solo incluí apps que tengas derecho a distribuir.

## Pagos / renovación

La API es *stateless*: la clave lleva la fecha de vencimiento y una firma HMAC.
Para renovar, generá una clave nueva con `POST /api/admin/licenses` y entregala
al usuario (no hay base de datos que migrate ni disco que se pierda).

```bash
curl -X POST https://tvbox-license.onrender.com/api/admin/licenses ^
  -H "Authorization: Bearer TU_ADMIN_TOKEN" ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"juan\",\"days\":30}"
```

Guardá `LICENSE_PEPPER` en un lugar seguro: si lo cambiás, **todas** las claves
emitidas dejan de funcionar. Los valores de producción están en
`C:\Users\ChipeadorOnline\Documents\tvbox-release-secrets.txt`.

## 6. Publicar la API con HTTPS

### Producción: Render (activo)

Servicio: `https://tvbox-license.onrender.com` (plan gratuito, deploy automático
desde `main`). Variables de entorno: `ADMIN_TOKEN` y `LICENSE_PEPPER`.

### Opción A: túnel Cloudflare (solo para pruebas locales)

Con la API corriendo en `localhost:3000`:

```powershell
.\cloudflared-tunnel.ps1
```

Imprime una URL `https://xxxx.trycloudflare.com` y la guarda en
`tools\tunnel-url.txt`. Para detenerlo:

```powershell
.\cloudflared-tunnel.ps1 -Stop
```

El binario se descarga automáticamente a `tools\cloudflared.exe`.

### Opción B: Docker + nginx + Let's Encrypt (dominio propio)

Necesitás un dominio apuntando a la IP del servidor y Docker instalado.

```bash
cd deploy
cp .env.example .env
# editá API_DOMAIN y ACME_EMAIL
docker compose up -d --build
```

El proxy emite el certificado automáticamente y expone la API en
`https://API_DOMAIN`. Después recompilá la app:

```powershell
.\build-release.ps1 -ApiUrl "https://API_DOMAIN"
```

El estado de las licencias se guarda en `server/data/licenses.json`;
hacé backup de ese archivo y de `server/.env`.
