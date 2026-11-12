# Nyxel Free Fire Stats Proxy

Worker independiente de `dz`, usado por la sección «Free Fire · Estadísticas» del perfil de Nyxel External.

## Qué hace

- Acepta únicamente `POST /lookup` y valida UID numérico de 5–15 dígitos y región `sg`, `ind` o `br`.
- Revalida la key/HWID/build de Nyxel con el endpoint existente `/check` mediante el Service Binding `DZ_WORKER`, sin cambiar el Worker `dz`.
- Consulta `/info` y `/stats` en la API comunitaria de Free Fire.
- Lee `FREE_FIRE_API_KEY` como secreto del entorno de Cloudflare; no va en la IPA ni en GitHub.
- Envía un `User-Agent` propio, requerido por el firewall del proveedor, sin nombres de librerías o bots.
- Devuelve el perfil y las estadísticas como datos de solo lectura, con caché breve por UID/región.
- Maneja timeouts, respuestas no JSON y HTTP 429; si llega `Retry-After`, el mensaje indica cuándo volver a intentar.

## Configuración

1. Crear el Worker `nyxel-freefire-stats` y habilitar su subdominio `workers.dev`.
2. Configurar el service binding `DZ_WORKER` para apuntar al Worker `dz`; esto evita una llamada pública interna a `workers.dev`.
3. Añadir el secreto `FREE_FIRE_API_KEY` desde Cloudflare (no guardarlo en el repositorio).
4. Comprobar `GET /health`; `apiKeyConfigured` debe ser `true`.
5. Probar `POST /lookup` desde una IPA con una sesión Nyxel válida.

Worker desplegado: `https://nyxel-freefire-stats.davidporfirio17.workers.dev`; health: `https://nyxel-freefire-stats.davidporfirio17.workers.dev/health`.

Las pruebas simuladas se ejecutan con `npm test` desde esta carpeta; no llaman al proveedor real ni requieren secretos.

La OpenAPI enumera `sg`, `ind` y `br`. La indicación enviada por el proveedor amplía `br` a Brasil, Estados Unidos, Norteamérica y LATAM; la app muestra «BR / NA» pero envía el código `br`. No usar credenciales de Free Fire: sólo se envían UID/región a la API de estadísticas.

El portal de desarrolladores vigente documenta UIDs de 5–15 dígitos, por lo que el UID de 8 dígitos también es válido para la validación local. Algunos materiales anteriores del kit muestran un patrón más estrecho; se sigue la documentación vigente.

El plan Trial Pass publica límites de 300 solicitudes por 24 horas, 20 por minuto y 100 por hora. Cada consulta nueva pide `/info` y `/stats` (dos solicitudes); el Worker conserva la respuesta en caché durante cinco minutos.
