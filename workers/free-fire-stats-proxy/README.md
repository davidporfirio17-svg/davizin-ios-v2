# Nyxel Free Fire Stats Proxy

Worker independiente de `dz`, usado por la sección «Free Fire · Estadísticas» del perfil de Nyxel External.

## Qué hace

- Acepta únicamente `POST /lookup` y valida UID numérico de 8–14 dígitos y región `sg`, `ind` o `br`.
- Revalida la key/HWID/build de Nyxel con el endpoint existente `/check`, sin cambiar el Worker `dz`.
- Consulta `/info` y `/stats` en la API comunitaria de Free Fire.
- Lee `FREE_FIRE_API_KEY` como secreto del entorno de Cloudflare; no va en la IPA ni en GitHub.
- Devuelve el perfil y las estadísticas como datos de solo lectura, con caché breve por UID/región.

## Configuración

1. Crear el Worker `nyxel-freefire-stats` y habilitar su subdominio `workers.dev`.
2. Añadir el secreto `FREE_FIRE_API_KEY` desde Cloudflare (no guardarlo en el repositorio).
3. Comprobar `GET /health`; `apiKeyConfigured` debe ser `true`.
4. Probar `POST /lookup` desde una IPA con una sesión Nyxel válida.

Worker desplegado: `https://nyxel-freefire-stats.davidporfirio17.workers.dev`; health: `https://nyxel-freefire-stats.davidporfirio17.workers.dev/health`.

Las pruebas simuladas se ejecutan con `npm test` desde esta carpeta; no llaman al proveedor real ni requieren secretos.

La OpenAPI enumera `sg`, `ind` y `br`. La indicación enviada por el proveedor amplía `br` a Brasil, Estados Unidos, Norteamérica y LATAM; la app muestra «BR / NA» pero envía el código `br`. No usar credenciales de Free Fire: sólo se envían UID/región a la API de estadísticas.

La app y el Worker aceptan UIDs de 8–14 dígitos porque su longitud puede variar. La OpenAPI publicada muestra un patrón más estrecho (9–10); el proveedor aún podría aplicar su propia validación al consultar.
