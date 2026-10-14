# Notas del proyecto — IPAs base y qué funciona

## IPAs activas (las que usan los clientes AHORA)

| IPA | Versión | Build GitHub Actions | Commit base | Estado |
|---|---|---|---|---|
| `NyxelExternal_27.ipa` (iOS 27) | 1.5 (5) | **#499** | `04b9eb5` | **Proyecto base de iOS 27** — todo funciona excepto datos celulares |
| `Nyxel_External.1.4.2.ipa` (iOS 26) | 1.4 (4) | **#252** | `b263bfb` | **Proyecto base de iOS 26** — funciona en WiFi y datos |

## Regla de oro

Si rompo WiFi en iOS 27, debo **volver a la build #499 (commit `04b9eb5`)**. Esa es la referencia de "todo funciona menos datos".

```bash
git checkout 04b9eb5   # ver estado del proyecto iOS 27 que funciona
```

Para iOS 26, la referencia es build #252 (commit `b263bfb`).

## Objetivo actual

**iOS 27 datos celulares (data)**. WiFi ya funciona en #499. No tocar nada que afecte WiFi.

## Qué YA se intentó y NO funciona para iOS 27 celular

Lecciones aprendidas (NO repetir):

1. **`enforceRoutes = true`** solo (build #504) — no basta en celular iOS 27
2. **Agregar `10.7.1.1` como RSD target directo** (#505) — "No route to host" en celular
3. **Detectar IPs del dispositivo con `getifaddrs()`** (#506) — remotepairingd no escucha en IP celular (10.X.X.X)
4. **`includeAllNetworks = true` desde el inicio** (#507) — rompe TODO el internet (kill-switch), incluso WiFi
5. **`includeAllNetworks` fase 2 (al conectar VPN)** (#509) — Worker rechaza la key porque el kill-switch se activa 50s antes de la inyección
6. **`includeAllNetworks` solo durante AirLift** (#510) — PASO 6 falla porque descarga del recurso del Worker está bloqueada
7. **Pre-descargar recurso antes de activar `includeAllNetworks`** (#511) — AirLift sigue sin alcanzar RSD en celular (10.7.0.1 timeout 6s)
8. **Subnet mask /16 en el utun** (#512) — iOS 27 ignora la máscara en celular, kernel sigue escogiendo IP celular como source
9. **Bind socket a `10.7.1.1` desde Rust** (#513) — rompe WiFi también ("No route to host" por bind al utun desde el app)
10. **Fallback `bad_query` + I/O directa en iOS 27** (#514) — `bad_query` retorna handle=-3 sin kexploit (Apple patcheó la ruta sin exploit)
11. **IP_BOUND_IF al utun desde Rust del main app** (#518) — WiFi sigue funcionando (confirmado inyección completa), celular ahora falla con `Connection refused` (os error 61) inmediato en vez de timeout 6s. Progreso diagnóstico (el paquete llega al kernel) pero sigue sin alcanzar remotepairingd con source correcto.

## Observación clave del usuario (iOS 27 celular)

- En **WiFi** aparece el icono de VPN en la barra de status cuando el app está en operación
- En **celular** NO aparece ese icono, aunque `NEVPNStatus` reporte `.connected`
- Diagnóstico: iOS 27 trata el VPN de manera distinta en celular — no lo activa realmente del lado del PacketTunnelProvider para procesamiento de paquetes

## Siguiente paso aprobado por usuario

Hacer un **botón separado "Datos (experimental)"** con ruta de inyección completamente aparte, que NO toque el camino de WiFi.  Plan técnico: TCP relay dentro del PacketTunnelProvider (la extension) escuchando en 127.0.0.1:49153 que a su vez conecta a 127.0.0.1:49152 (remotepairingd) usando IP_BOUND_IF al utun desde el proceso de la extension (que tiene privilegios de VPN distintos al main app).

## Causa raíz confirmada

iOS 27 en datos celulares:
- Kernel **ignora rutas /32 del VPN** y escoge siempre la IP celular como source IP para destinos 10.7.0.x
- El swap del PacketTunnelProvider produce paquetes a destinos inexistentes (la propia IP celular del dispositivo en puerto 49152, donde nadie escucha)
- `remotepairingd` sí responde en 127.0.0.1 pero **rechaza pairing desde loopback**
- `bad_query` sin kexploit → handle=-3 (Apple patcheó esa ruta en iOS 27)

## Reglas de trabajo

1. **WiFi iOS 27 YA FUNCIONA en #499.** Nunca romperlo.
2. Cualquier intento de datos debe **preservar WiFi** (fallback: AirLift sigue siendo el camino principal; nuevo mecanismo solo activa en celular detectado).
3. Si algo se cae, **resetear a `04b9eb5`** (`git reset --hard 04b9eb5`) y empezar de nuevo.
4. **No tocar código Rust de `idevice`/`idevice-ffi` vendored** — es demasiado fácil romper WiFi ahí.
5. **No usar `includeAllNetworks`** sin un plan claro — mata el internet si el VPN no está activo.
