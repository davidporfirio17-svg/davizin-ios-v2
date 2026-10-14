# Notas del proyecto — IPAs base y qué funciona

## IPAs activas (las que usan los clientes AHORA)

| IPA | Versión | Build GitHub Actions | Commit base | Estado |
|---|---|---|---|---|
| `NyxelExternal_27.ipa` (iOS 27) | 1.5 (5) | **#499** | `04b9eb5` | **Proyecto base de iOS 27** — todo funciona excepto datos celulares puros |
| `Nyxel_External.1.4.2.ipa` (iOS 26) | 1.4 (4) | **#252** | `b263bfb` | **Proyecto base de iOS 26** — funciona en WiFi y datos |

## Regla de oro

Si rompo WiFi en iOS 27, debo **volver a la build #499 (commit `04b9eb5`)**. Esa es la referencia de "todo funciona menos datos celulares puros".

```bash
git checkout 04b9eb5   # ver estado del proyecto iOS 27 que funciona
```

## Causa raíz confirmada (datos celulares iOS 27)

iOS 27 — y en el fondo todas las versiones modernas — **NO** permiten enrutar el VPN loopback por su /32 cuando datos celulares es la interfaz default:

- **NECP (Network Extension Control Policy)** fuerza la ruta default por la interfaz celular, ignorando bind(), IP_BOUND_IF y las rutas /32 del `NEPacketTunnelProvider` (confirmado por Apple DTS en los foros de Apple Developer).
- `remotepairingd` rechaza pair-verify desde source loopback (127.0.0.1).
- `bad_query` sin kexploit retorna handle=-3 (Apple patcheó esa ruta en iOS 27).

**Nadie en el ecosistema lo ha resuelto** (SideStore, StikJIT, StikDebug, LocalDevVPN, JitStreamer, pymobiledevice3 — todos tienen la misma limitación).

## Workaround oficial del ecosistema (lo que usa StikJIT, documentado en su `INTEGRATION.md`)

> Without Wi-Fi, enable cellular data, connect LocalDevVPN, and then **enable Airplane Mode** before returning to the app.

Secuencia:
1. Activar datos celulares (para completar el pairing si hace falta).
2. Conectar el VPN loopback.
3. **Activar Modo Avión**: baja la interfaz celular (deja de ser default route) pero el VPN loopback NO se cae porque es local. La `utun` queda como única interfaz → el kernel enruta `10.7.0.x` por utun → remotepairingd ve source correcto → pair-verify pasa.
4. Operar.
5. Al terminar, apagar Modo Avión y recuperar los datos.

## Implementación en Nyxel External

- `DavizinIOS/NyxelCellularPreflight.swift` detecta el estado de red con `NWPathMonitor` antes de operar.
- `DavizinBridge.performInjection` llama al preflight. Si estado = `.cellularOnly` muestra un `UIAlertController` explicando el procedimiento de Modo Avión.
- Si estado = `.ok` (WiFi activo **o** Airplane Mode + VPN) procede sin preguntar.

## Qué YA se intentó y NO funciona para iOS 27 celular puro (sin Airplane Mode)

Lecciones aprendidas — NO repetir, es imposible desde user-space sin apagar la interfaz celular:

1. `enforceRoutes = true` (#504) — no basta
2. Agregar `10.7.1.1` como RSD target directo (#505) — No route to host
3. Detectar IPs del dispositivo con `getifaddrs()` (#506) — remotepairingd no escucha en IP celular
4. `includeAllNetworks = true` desde el inicio (#507) — rompe TODO internet (kill-switch)
5. `includeAllNetworks` fase 2 al conectar VPN (#509) — Worker rechaza la key por kill-switch
6. `includeAllNetworks` solo durante AirLift (#510) — PASO 6 falla por download bloqueado
7. Pre-descargar recurso antes de activar `includeAllNetworks` (#511) — timeout 6s en RSD celular
8. Subnet mask /16 en el utun (#512) — iOS 27 ignora la máscara en celular
9. Bind socket a `10.7.1.1` desde Rust (#513) — rompe WiFi (No route to host)
10. Fallback `bad_query` + I/O directa en iOS 27 (#514) — handle=-3 sin kexploit
11. IP_BOUND_IF al utun desde Rust del main app (#518) — WiFi OK pero celular `Connection refused`
12. TCP relay en PacketTunnelProvider en 127.0.0.1:49153 (#519) — listener funciona pero remotepairingd rechaza por loopback
13. 5 estrategias multi-source en el relay (#520) — todas fallan silenciosamente
14. sendProviderMessage IPC + 6ta estrategia plain-connect (#521) — mismo resultado, `UnexpectedResponse HTTP/2 closed by peer`

## Confirmación empírica del límite

En #521 vimos `UnexpectedResponse("HTTP/2 connection closed by peer")` — el relay SÍ proxy'ó bytes y arrancó TLS/HTTP2, pero remotepairingd dropeó por source loopback. Darwin loopback optimization + NECP = pared infranqueable desde user-space.

## Reglas de trabajo

1. **WiFi iOS 27 YA FUNCIONA en #499.** Nunca romperlo.
2. Para datos celulares, única vía soportada: **Modo Avión + VPN**. La UI debe guiar al usuario.
3. Si algo se cae, resetear a `04b9eb5`.
4. **No tocar código Rust de `idevice`/`idevice-ffi` vendored** — es demasiado fácil romper WiFi.
5. **No usar `includeAllNetworks`** sin un plan claro — mata el internet si el VPN no está activo.

## Fuentes

- [StikJIT INTEGRATION.md](https://github.com/StikDebug/StikJIT/blob/main/INTEGRATION.md) — documentación del workaround de Airplane Mode
- [Apple DTS forum (NEPacketTunnelProvider routing)](https://developer.apple.com/forums/thread/706963) — "binding to cellular succeeds but traffic follows the default route anyway"
- [LocalDevVPN](https://apps.apple.com/vn/app/localdevvpn/id6755608044) — VPN loopback usado por el ecosistema
