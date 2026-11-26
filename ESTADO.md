# Estado del proyecto TV Box

Carpeta: `C:\Users\ChipeadorOnline\Documents\tvbox`
GitHub: https://github.com/ChipeadorOnline/tvbox

## Servicios activos

- API de licencias (URL fija): https://tvbox-license.onrender.com
- Panel para crear claves de clientes: https://tvbox-license.onrender.com/admin
- GitHub Actions genera el APK automáticamente al pushear un tag `v*`.

La PC **no tiene que estar encendida**: todo está en Render.

## APK

- Release publicado: https://github.com/ChipeadorOnline/tvbox/releases/latest
- Copia local: `apk\tvbox-updater-release.apk`
- Versión actual: v1.0.11 (sale en la pantalla de clave)
- Incluye: navegación con flechas del control, OK para ingresar, clave con
  mayúsculas y guiones automáticos, opción de launcher y un botón
  **Diagnóstico** que muestra la clave guardada, el estado del servidor y el
  código HTTP exacto de la validación.
- Espera de hasta 70 s para que Render despierte, con reintento automático.
- v1.0.9 corrigió un fallo crítico: el APK se guardaba siempre con el mismo
  nombre y se reutilizaba aunque el catálogo tuviera otra versión. Ahora el
  archivo incluye el `versionCode`, el botón dice `Instalar vX` y la tarjeta
  muestra `Versión disponible: vX`.
- v1.0.10 agrega que **Refrescar** ofrece directamente la versión nueva con un
  botón **Actualizar ahora**, que descarga y abre el instalador sin salir de la
  app.
- Si el TV quedó en v1.0.6 o anterior, hay que instalar **una sola vez** con el
  link corto para salir del bucle de caché. Después ya se actualiza desde la app.

## Clave de prueba

```
PN2B-9XBY-DJVR-KTSN
```
Vence el 26/12/2026. Se acepta con guiones, sin guiones y en minúsculas.

## Secretos (NOSUBIR a GitHub)

`C:\Users\ChipeadorOnline\Documents\tvbox-release-secrets.txt`

Contiene: keystore, contraseñas del keystore, `ADMIN_TOKEN` y `LICENSE_PEPPER`
de Render. Si se pierde el `LICENSE_PEPPER`, las claves emitidas dejan de funcionar.

## Tareas habituales

### Crear una clave para un cliente
Entrar a https://tvbox-license.onrender.com/admin, cargar la contraseña de
administrador (está en el archivo de secretos), el nombre del cliente y los días.

### Agregar o actualizar apps
Editar `catalog.json` y subirlo a `main`. Subir `versionCode` cuando cambie un
APK: la app avisa "Hay novedades". Solo apps con derecho a distribución.

### Instalar el APK en un TV Box
Con Downloader: https://is.gd/AvvtiL

### Clientes: clave individual y renovación
Cada amigo tiene su **propia clave** generada en el panel con su nombre y
días. No comparten clave. Cuando vence, generás una nueva clave desde
https://tvbox-license.onrender.com/admin y se la mandás; en el TV eligen
**Cambiar clave** y cargan la nueva. No hace falta reinstalar el APK.

### Apps instaladas
El catálogo muestra «Instalada vX» cuando la app está presente y la tarjeta
se pinta verde. Botones: **Actualizar**, **Abrir** y **Borrar**. En Android TV
el botón Borrar abre los **Ajustes de la app**; desde ahí se elige
**Desinstalar** con el control remoto. La propia app también avisa cuando hay
una versión nueva de sí misma.

Si una app instalada no aparece marcada, abrir **Diagnóstico** desde el
catálogo: muestra la versión instalada de esta app y el resultado de la
búsqueda de cada paquete del catálogo.

### No pedir la clave al reingresar
La clave queda guardada. En el catálogo, **Salir** cierra la app sin borrar
la clave; **Cambiar clave** sí la borra (es para reemplazarla).

### Si la clave dice "inválida o vencida"
Entrar con la clave, bajar a **Diagnóstico** con las flechas y apretar OK.
Copiar al chat lo que dice (muestra la clave guardada y el código HTTP).

### Dejarlo como launcher
En el TV Box: Inicio → configurar pantalla de inicio → elegir **Actualizador TV**.

### Recompilar con otra URL de API
```powershell
.\build-release.ps1 -ApiUrl "https://tvbox-license.onrender.com"
```
Para publicar: `git tag -a vX.Y.Z -m "Release"; git push origin vX.Y.Z`

## Próxima mejora: administración de clientes (pendiente)

Hoy la validación es **stateless** (HMAC con `LICENSE_PEPPER`): no guarda qué
claves se emitieron, así que no se puede listar usuarios ni desactivar una
clave. Para hacerlo hace falta una base de datos pequeña (recomendación:
Supabase free / Postgres).

Diseño previsto:

- Tabla `licenses`: hash de la clave (nunca la clave en texto), nombre,
  vencimiento, `enabled`, fecha de creación y último uso.
- API: crear clave, listar, renovar días, activar/desactivar y revocar.
- Panel web `/admin`: lista con días restantes, buscador, botones
  **Activar/Bloquear**, **Extender** y **Crear clave**.
- App del TV: entrada de **Modo administrador** protegida con contraseña de
  admin (nunca guardada en el APK). Consulta el estado y permite activar o
  bloquear con el control. Para tareas largas se sigue usando el panel web.
- Migración: cargar la clave actual `PN2B-...` en la base al activar el cambio.
  El `LICENSE_PEPPER` no se toca para no invalidar claves ya emitidas.

No se incluye en v1.0.8; se implementa en una versión siguiente.

## Limitación conocida

Android TV no permite instalar APKs en silencio sin root/device owner. La app
descarga el APK y abre el instalador de Android; el usuario confirma con OK.
