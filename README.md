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

Y compilar:

```bash
flutter build apk --release \
  --dart-define=API_URL=https://tu-dominio.com \
  --dart-define=CATALOG_URL=https://raw.githubusercontent.com/ChipeadorOnline/tvbox/main/catalog.json
```

El APK queda en `tvbox_app/build/app/outputs/flutter-apk/app-release.apk`.

En GitHub agregá los Secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
`KEY_PASSWORD` y la variable `API_URL`. Al pushear un tag `v1.0.0`, el workflow
compila y sube el APK al Release.

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

## Pagos

El endpoint `POST /api/webhook/payment` renueva la licencia por X días.
Conectalo al webhook de MercadoPago/Stripe/PayPal. No usamos Play Billing
porque la app se instala fuera de Play Store.
