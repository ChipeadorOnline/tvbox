# APK con suscripción para TV Box — Manual operativo

Este documento guarda todo lo que armamos: cómo funciona, cómo se usa en el
panel, cómo se agregan apps y cómo se publica una versión nueva.

## 1. Qué es

Es un actualizador para Android TV / Google TV que:

- Pide una clave de abono (`XXXX-XXXX-XXXX-XXXX`).
- Muestra un catálogo de apps y permite descargarlas y abrir el instalador de
  Android.
- Avisa cuando hay versiones nuevas, incluso del propio Actualizador TV.
- Se navega solo con flechas y OK del control remoto.

No instala ni borra apps en silencio: siempre abre el instalador o los Ajustes
de Android. Eso es una limitación del sistema, no de la app.

## 2. Estado actual

- Versión vigente: **v1.0.18** (`versionCode 18`, aparece en la pantalla de clave y en Diagnóstico).
- Link corto para instalar en la TV: **https://is.gd/wl2tE7**
- Release: https://github.com/ChipeadorOnline/tvbox/releases/download/v1.0.18/app-release.apk
- API de licencias: https://tvbox-license.onrender.com (`/api/health` debe responder `ok`).
- Panel de administración: https://tvbox-license.onrender.com/admin
- Catálogo público: 19 apps.
- Firma de todos los APK del 1.0.5 al 1.0.16: misma huella, actualizar no
  borra los datos (la clave queda guardada al actualizar, pero sí se pierde al
  desinstalar).

## 3. La clave

- Formato: `XXXX-XXXX-XXXX-XXXX`.
- Se acepta con o sin guiones y en cualquier caso.
- La valida la API con HMAC: el servidor no guarda el estado de cada clave, por
  eso se llama *stateless*.
- Las claves ya emitidas no se pueden invalidar desde el panel (ver más abajo).
- Clave de prueba vigente al momento de escribir esto: `PN2B-9XBY-DJVR-KTSN`,
  vence el 26/12/2026.
- Si el cliente desinstala la app, la clave se pierde: la vuelve a cargar desde
  la pantalla de clave o con **Cambiar clave**.

### Renovar

No se "renueva" la misma clave: se genera una nueva con más días y el cliente
aprieta **Cambiar clave** en la TV.

## 4. Panel de administración

URL: https://tvbox-license.onrender.com/admin

La contraseña del panel es `RENDER_ADMIN_TOKEN` (está en
`C:\Users\ChipeadorOnline\Downloads\tvbox-release-secrets.txt`). **No es la
clave del cliente y no hay que subirla a GitHub.**

### Generar una clave

1. Poner la contraseña de administrador.
2. **Cliente**: nombre del cliente (solo para el registro).
3. **Días de abono**: los días que quieras.
   - `2` = prueba de 2 días.
   - `30` = abono mensual.
   - Se acepta de 1 a 3650 días.
4. **Minutos de prueba (opcional)**: si ponés `5` o `10`, ese valor manda y la
   clave vence en minutos. Dejar vacío para usar Días.
5. **Generar clave**.
6. **Copiar clave** y mandársela al cliente.

No hay un botón separado de "prueba": basta con poner `2` en Días, o `5`/`10`
en Minutos para una prueba corta. La TV va a mostrar **"Vence hoy"** o
**"Vence en 2 días"**. Al vencimiento, la clave deja de servir aunque el TV no
tenga internet.

### Probar un bloqueo por vencimiento en 5 o 10 minutos

1. En el panel generá una clave con **Minutos = 5** (o 10) y un nombre de prueba.
2. En la TV apretá **Cambiar clave** y poné esa clave.
3. Esperá a que pasen los minutos.
4. Cerrá y volvé a abrir la app (o apretá **Reintentar**). Debe aparecer la
   pantalla de clave con el error **"Clave inválida o vencida (código 403)"**.
5. Para volver a la normalidad, apretá **Cambiar clave** y poné la clave real.

Esto no afecta a los clientes: las claves ya emitidas siguen igual y
`LICENSE_PEPPER` no se toca.

Prueba realizada el 27/11/2026 con una clave de 10 minutos: al vencimiento el
servidor devolvió **403**. La app bloquea al cerrar/abrir o al apretar
**Reintentar**; no expulsa en el mismo segundo del vencimiento.

**Refrescar no revalida la clave**: solo baja el catálogo. Si la clave venció
mientras la app estaba abierta, apretar Refrescar no muestra el error; hay que
cerrar y abrir, o usar **Diagnóstico → Reintentar**.

### Registro local de clientes

Botones:

- **Guardar en GitHub**: sube la lista completa al gist privado. Reemplaza todo
  lo anterior, así que conviene **Cargar de GitHub** primero.
- **Cargar de GitHub**: baja la lista guardada. También se dispara solo al
  escribir la contraseña.
- **Exportar JSON**: descarga `tvbox-clientes.json` como copia.
- **Vaciar registro**: borra la lista del navegador (y puede subirla vacía a
  GitHub). Usar con cuidado.

Columnas:

- **Cliente** y **Nota**: editables; se confirman con **Guardar** en esa fila.
- **Clave**, **Días** y **Vencimiento**: solo lectura. Para cambiarlos hay que
  generar una clave nueva.
- **Estado**: `Activa` / `Bloqueada`. ⚠️ Es solo para control visual: poner
  `Bloqueada` **no desactiva la clave** en el servidor. Para bloquear de verdad
  haría falta una base de datos (mejora futura).
- **Borrar**: quita el registro del panel, pero la clave sigue válida hasta
  vencer.

Hoy, para cortar el acceso de un cliente, hay que esperar a que venza o darle
una clave nueva.

## 5. Catálogo de apps

Archivo: `catalog.json` en la raíz del repo.

Tiene 19 entradas:

- Actualizador TV `1.0.16`
- SmartTube oficial `32.80` (paquete `org.smarttube.stable`)
- 17 APKs del release `v1` del repo (Magma, Xuper VPN, Urban VPN, Xuper Hydra,
  MagLink TV, Downloader, TeleApp, GeeSports, Disney+, Saltamontes Lite, Xuper
  SBC Proxy, Xuper Tv NF, Send Files To TV, Xuper, XuperAmigOnlyTV, CricZ TV y
  PlayTV).

Se dejaron afuera a propósito:

- `001.-.FCTV33_p_v3.0.318.apk` (versión Premium renombrada).
- `Net.Flix.M+_1.4.4.apk` (Mod renombrado).
- `008.-.X-plore.Pro...` / `008.-.X-plore.P...` (viene de sitio de cracks).
- `007.-.smarttube_stable.apk` (copia vieja v29.83; se usa la oficial v32.80).

**Regla:** solo apps legítimas con derecho a distribución. Renombrar un archivo
no cambia lo que es.

### Cómo agregar una APK

1. Subir el APK a un release del repo (Releases → Editar → arrastrar archivo).
2. Copiar la URL HTTPS que queda, tipo
   `https://github.com/ChipeadorOnline/tvbox/releases/download/v1/MiApp.apk`.
3. Agregar una entrada en `catalog.json`:

```json
{
  "id": "mi-app",
  "name": "Nombre lindo para la TV",
  "fileName": "MiApp.apk",
  "packageName": "com.ejemplo.app",
  "url": "https://github.com/.../releases/download/v1/MiApp.apk",
  "version": "1.2.3",
  "versionCode": 12,
  "size": 12345678,
  "sha256": "...",
  "notes": "..."
}
```

`packageName`, `version`, `versionCode`, tamaño y SHA-256 se sacan con `aapt2`
(`aapt2 dump badging archivo.apk` y `Get-FileHash`).

4. Hacer commit en `main`.
5. En la TV apretar **Refrescar**. No hace falta recompilar ni reinstalar el
   Actualizador TV.

También hay una copia del catálogo dentro del APK:
`tvbox_app/assets/catalog.json`. Se usa si GitHub no responde. Cuando cambie
`catalog.json`, copiarlo también ahí antes de compilar una versión nueva.

### Cómo actualizar una app del catálogo

Subir el APK nuevo al release, cambiar `version` y `versionCode` en
`catalog.json`, hacer commit. El cliente ve el aviso de novedades o aprieta
**Actualizar**.

Cuando la app ya está al día, la tarjeta dice **"Instalada vX"** en verde; solo
aparece **"Actualizar"** si hay versión nueva.

## 6. Publicar una versión nueva del Actualizador

Checklist:

1. Subir el número en:
   - `build-release.ps1` (`$BuildName` y `$BuildNumber`).
   - `.github/workflows/build-apk.yml` (`--build-name`, fallback de
     `APP_BUILD_NUMBER`).
   - Variable de GitHub `APP_BUILD_NUMBER`.
   - `tvbox_app/lib/screens/license_screen.dart` (`_version`).
   - `tvbox_app/lib/screens/catalog_screen.dart` (versión del Diagnóstico).
   - `catalog.json` y `tvbox_app/assets/catalog.json` (entrada `tvbox-updater`).
   - `README.md` y `ESTADO.md` (link corto y URL del release).
2. Generar link corto nuevo en https://is.gd/create.php.
3. `flutter analyze` y `flutter test`.
4. `.\build-release.ps1 -ApiUrl "https://tvbox-license.onrender.com"`.
5. `git commit` + `git push origin main` + tag `vX.Y.Z` + `git push origin vX.Y.Z`.
6. GitHub Actions genera el release con `app-release.apk`.
7. Verificar `/api/health`, el catálogo en `main` y la redirección del link corto.

## 7. Variables de Render (importante)

El servicio es `srv-dc495d6q1p3s73d9qr9g`.

Variables obligatorias: `ADMIN_TOKEN`, `LICENSE_PEPPER`, `GIST_ID` y
`GIST_TOKEN`.

⚠️ El endpoint `PUT /env-vars` de Render **reemplaza la lista completa**: si se
envía una sola variable, se borran las demás. Siempre enviar las cuatro juntas.

⚠️ **Nunca cambiar `LICENSE_PEPPER`**: invalidaría todas las claves emitidas.

Gist privado: `c3836d1a33e0aad1304e4090292b55ab`, archivo `clientes.json`.
El token de GitHub con scopes `gist, repo, workflow` está solo en Render, nunca
en el repo ni en el APK.

Los secretos del keystore y de Render están en
`C:\Users\ChipeadorOnline\Downloads\tvbox-release-secrets.txt`, **fuera del repo**.

## 8. Resistencia a fallas de red

- La app reintenta la licencia 3 veces (20 s, 45 s y 60 s) y el catálogo 2 veces
  (20 s y 45 s), porque Render en plan gratuito se duerme.
- Desde v1.0.15, el catálogo va **dentro del APK**: aunque GitHub falle, la app
  abre con la última lista conocida.
- Si falla la validación online, se usa la última licencia guardada, siempre que
  no esté vencida y la clave sea la misma.
- El vencimiento manda: aunque haya tolerancia offline de 7 días, una clave de
  2 días deja de servir a los 2 días, y una de 5 minutos a los 5 minutos.
  Desde v1.0.17 la caché de 24 h también revisa el vencimiento (antes no).
- Desde v1.0.18, al volver del instalador de Android la app recarga sin mostrar
  diálogos, para evitar el error **"Null check operator used on a null value"**
  en algunos TV Box.
- En la app hay botón **Diagnóstico**: muestra versión, API, hora del equipo,
  clave guardada, resultado de `/api/health` y de la validación. Es lo primero
  que hay que mirar si algo falla.

## 9. Instalación en la TV

1. Instalar Downloader en la TV.
2. Abrir Downloader y cargar el link corto: **https://is.gd/wl2tE7**
3. Dar permiso de instalación de apps desconocidas a Downloader/Actualizador.
4. Instalar y abrir.
5. Poner la clave.

Si el TV quedó en v1.0.6 o anterior, instalar **una sola vez** con el link
corto para salir del bucle de caché. Después ya se actualiza desde la app.

En la TV: **Refrescar** → si hay versión nueva, **Actualizar ahora**. Eso
descarga el APK y abre el instalador de Android; el cliente confirma con el
control remoto.
