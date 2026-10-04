# Nyxel / External — Guía de continuidad

**Fecha:** 2026-10-03  
**Repositorio:** `davidporfirio17-svg/davizin-ios-v2`  
**Rama de trabajo:** `feature/jailbreak-hybrid-foundation`  
**Idioma de trabajo:** español

## 1. Objetivo

Conseguir que Nixel replique el flujo de Remote Pairing/AirLift de la IPA de referencia **External/3105**, de modo que en el iPad aparezca el host `2424` dentro de:

```text
Ajustes > Privacidad y seguridad > Modo desarrollador
```

y pueda completarse el pairing iniciado por el iPad.

La IPA de prueba debe compilarse mediante GitHub Actions y solo entregarse si el workflow termina en verde.

## 2. Archivos de referencia

- IPA de External: `/home/ubuntu/upload/External-1.ipa`
- IPA extraída y analizada: `/home/ubuntu/analysis_external1/Payload/3105.app/`
- Código fuente de AltStore: `/home/ubuntu/altstore-marketplace/AltStore-marketplace/`
- ZIP recibido de AltStore: `/home/ubuntu/upload/AltStore-marketplace.zip`
- Repositorio local: `/home/ubuntu/davizin-ios-v2/`

## 3. Hallazgos confirmados de External/3105

### 3.1. `2424` sí es significativo

En External:

- `CFBundleExecutable` es `2424`.
- `CFBundleDisplayName` es `External`.
- El binario contiene estos textos:

```text
2424 AirLift Pairing
Open Settings > Developer Mode and pair with 2424.
Enter the pairing PIN in Settings.
```

Por tanto, `2424` es el **nombre visible del host** que External presenta al usuario. No es un puerto y no es un código arbitrario.

### 3.2. External declara dos servicios Bonjour

El `Info.plist` de External contiene:

```text
_remotepairing-pairable-host._tcp
_3105airlift._tcp
```

También aparecen en el binario:

```text
2424AirLiftProbe
```

El primer servicio es el servicio real de Remote Pairing. El segundo parece ser un probe/keep-alive de AirLift. No está demostrado todavía que el segundo servicio por sí solo sea suficiente para que Developer Mode muestre el host.

### 3.3. External usa una extensión VPN real

External contiene:

```text
PlugIns/ExternalTunnel.appex/ExternalTunnel
```

La extensión es una `NEPacketTunnelProvider` y utiliza:

```text
TunnelIfaceIP = 10.7.1.1/32
TunnelPeerIP  = 10.7.0.1/32
```

También contiene `readPacketsWithCompletionHandler` y `writePackets:withProtocols:`. Por tanto, el VPN de External no es un simple listener Bonjour: configura una interfaz de túnel y procesa paquetes.

La app principal también usa:

```text
NETunnelProviderManager
providerBundleIdentifier
startVPNTunnelWithOptions:andReturnError:
```

### 3.4. Flujo textual observado en External

El binario contiene mensajes que indican esta secuencia aproximada:

```text
prepare: name=%@ model=%@
prepared: service=%@ txtKeys=%@
bind listener
listening on port %d
Open Settings > Developer Mode and pair with 2424.
PIN issued (redacted)
host success: device=%@ model=%@ file=private
RPPairing record loaded
RSD tunnel established (adapter+handshake)
```

La secuencia exacta todavía debe confirmarse dinámicamente, pero hay evidencia de que External mantiene estado de pairing, listener y VPN/transportes, no solo un anuncio mDNS aislado.

## 4. Qué contiene actualmente Nixel

### 4.1. PairableHost FFI

El repositorio incluye un FFI Rust basado en `idevice-rs`:

```text
Vendor/idevice/ffi/src/pairing_host.rs
```

La API expuesta es:

```c
pairable_host_prepare(...)
pairable_host_accept_fd(...)
pairable_host_free(...)
```

`pairable_host_prepare` genera:

- identidad del host;
- `serviceID` UUID;
- TXT con `name`, `identifier`, `authTag`, `model`, `flags`, `ver`, `minVer`.

La documentación del propio FFI confirma que `name` y `model` son los valores que el dispositivo muestra, mientras que `serviceID` es el identificador estable mDNS/interno.

### 4.2. Nombre y modelo usados por Nixel

Nixel llama actualmente:

```swift
nyxel_pairable_host_start("2424", "Mac17,7")
```

Esto es coherente con el modelo de External: `2424` como nombre humano y `Mac17,7` como modelo de host tipo Mac.

### 4.3. Transporte actual de Nixel

Nixel crea:

1. Un socket POSIX local para `PairableHost`.
2. Un `NWListener` para `_remotepairing-pairable-host._tcp`.
3. Un segundo `NWListener` para `_3105airlift._tcp` con nombre `2424AirLiftProbe`.
4. Un proxy que copia bytes entre el `NWConnection` de Network.framework y el socket local del FFI.

Esto es una aproximación, no una réplica demostrada del transporte de External.

## 5. Último resultado probado

El usuario probó la IPA del build `37167845639` y reportó:

```text
Host local publicado 2424
Probe AirLift registrado 2424 AirLift
Probe 3105 AirLift
TCP local
```

Después, al entrar de nuevo, apareció:

```text
Host local publicado 2424
Provider AirLift no disponible
No se ha podido completar la operación
```

En Developer Mode sigue sin aparecer ningún host.

### Interpretación

Esto demuestra únicamente que el proceso local consigue crear/publicar parte del listener. **No demuestra** que:

- iPadOS vea el servicio desde Developer Mode;
- el servicio tenga exactamente el TXT que espera Apple;
- el probe responda con el protocolo que espera External;
- la VPN esté activa y correctamente configurada;
- el handshake RPairing haya comenzado.

El mensaje `Provider AirLift no disponible` tampoco debe interpretarse como “el servicio mDNS está bien y solo falta un detalle”; indica que la capa del proveedor/túnel de AirLift no está disponible o se perdió durante el flujo.

## 6. Cambios recientes en GitHub

### Build anterior de diagnóstico mDNS

- Commit: `398d5e1`
- Run: `37166836220`
- IPA:
  `/home/ubuntu/davizin-ios-v2/build-artifact-37166836220/Nyxel_External_unsigned.ipa`

### Último build probado

- Commit: `cad5dac`
- Run: `37167845639`
- URL:
  `https://github.com/davidporfirio17-svg/davizin-ios-v2/actions/runs/37167845639`
- IPA:
  `/home/ubuntu/davizin-ios-v2/build-artifact-37167845639/Nyxel_External_unsigned.ipa`
- SHA-256:

```text
4b589a17854071a214a8ee2c1672912000968351449591fc890880a61a53fd9c
```

El build terminó en verde y la IPA fue comprobada con `unzip -t`.

## 7. Qué NO hacer al retomar

No hacer otra IPA cambiando solamente:

- el texto visible `2424`;
- el UUID del servicio;
- `NSNetService` por `NWListener` sin verificar el protocolo;
- el orden visual de mensajes;
- otro puerto arbitrario;
- otro nombre Bonjour sin comparar TXT;
- `UIBackgroundModes` como solución principal;
- un proxy TCP adicional sin demostrar que conserva exactamente el framing y semántica del protocolo.

No asumir que AltStore contiene el VPN de External. El código de AltStore contiene un listener AltServer (`_altserver._tcp`) y conexiones `NWConnection`, pero **no contiene** el `PacketTunnelProvider` ni el protocolo específico de Remote Pairing de External.

No asumir que “listener listo” equivale a “Developer Mode puede usarlo”. Son estados distintos.

## 8. Qué investigar a continuación, en orden

### Paso A — Congelar el diagnóstico actual

Antes de cambiar código, instalar la última IPA y capturar exactamente todos los estados de Nixel:

1. listener TCP creado;
2. servicio `_remotepairing-pairable-host._tcp` registrado;
3. probe `_3105airlift._tcp` registrado;
4. interfaz de red reportada;
5. si llega una conexión entrante real;
6. si el proxy local conecta al socket PairableHost;
7. si se emite un PIN;
8. si el handshake falla y con qué error.

Si nunca llega una conexión entrante, el problema está antes del protocolo: identidad/TXT/servicio/interfaz/Developer Mode/VPN.

Si llega conexión entrante pero nunca se emite PIN, el problema está en framing o en el socket que se entrega al FFI.

Si se emite PIN pero no se guarda RPairing, el problema está en el handshake criptográfico o en la serialización.

### Paso B — Comparar el TXT real

No basta con saber los nombres de las claves. Hay que imprimir en Nixel y reconstruir desde External, si es posible:

```text
name
identifier
authTag
model
flags
ver
minVer
```

Validar especialmente:

- si `identifier` coincide byte a byte con el nombre de instancia mDNS;
- si `authTag` se deriva del mismo `altIRK` e identificador;
- si los valores están codificados como TXT DNS-SD válido;
- si External publica `name=2424` y no solo una instancia UUID.

### Paso C — Analizar la implementación de AirLift de External

La prioridad debe ser la clase/símbolos:

```text
AirLiftPairingController
AirLiftPairingKeepAlive
ExtLocalDevVPNManager
```

Hay que averiguar:

- cuándo arranca el `NETunnelProviderManager` respecto al pairing;
- qué opciones se pasan a `startVPNTunnelWithOptions`;
- si el proveedor VPN crea la ruta hacia el host o solo mantiene la interfaz;
- si `_3105airlift._tcp` sirve para descubrir, mantener vivo o transportar datos;
- si el segundo servicio acepta conexiones o solo anuncia estado;
- cómo se persiste el `altIRK` y el registro RPairing entre ejecuciones.

### Paso D — Revisar el túnel, no solo Bonjour

El error actual `Provider AirLift no disponible` hace necesario comparar:

- bundle identifier de la extensión;
- `NETunnelProviderProtocol.providerBundleIdentifier`;
- configuración persistida con `saveToPreferences`;
- `loadFromPreferences`;
- direcciones `10.7.1.1/32` y `10.7.0.1/32`;
- `NEPacketTunnelNetworkSettings`;
- rutas incluidas/excluidas;
- lectura y escritura de paquetes;
- ciclo de vida al volver de Ajustes/Developer Mode.

El proveedor actual de Nixel no debe darse por equivalente a External solo porque la IPA compile.

## 9. Criterio para la próxima IPA

No entregar una nueva IPA hasta que el cambio tenga una justificación concreta y se pueda responder:

1. ¿Qué diferencia observada en External corrige?
2. ¿Qué estado observable debería cambiar en el iPad?
3. ¿Cómo se sabrá si el cambio funcionó?
4. ¿Qué evidencia distingue fallo de Bonjour, VPN o handshake?

La próxima IPA debería ser una **IPA de diagnóstico**, con un registro claramente separado para:

```text
MDNS_REGISTERED
PROBE_REGISTERED
VPN_CONFIG_LOADED
VPN_CONNECTED
INCOMING_CONNECTION
PAIRING_HANDSHAKE_STARTED
PIN_ISSUED
PAIRING_RECORD_SAVED
RSD_TUNNEL_READY
```

No se debe mostrar “conectado” o “pairing completado” a partir de un simple callback `.ready` de `NWListener`.

## 10. Conclusión actual

Estamos más cerca de identificar el problema, pero todavía **no hay base para afirmar que Nixel replica External**. El último resultado prueba que se registran servicios locales, pero el iPad no muestra `2424` en Developer Mode y después reporta que el Provider AirLift no está disponible.

La hipótesis prioritaria ya no es “falta cambiar el nombre 2424”. El nombre ya está identificado correctamente. Las hipótesis principales son:

1. falta o está mal implementada la extensión/proveedor VPN de AirLift;
2. el segundo servicio `_3105airlift._tcp` necesita un protocolo real y no solo un listener que acepta/cierra;
3. el TXT/`authTag`/identidad mDNS no coincide con lo que iPadOS espera;
4. el proxy `NWConnection` → socket POSIX no reproduce el transporte de External;
5. el servicio se publica en una interfaz o ciclo de vida distinto al de External.

El siguiente chat debe comenzar leyendo este documento y revisando primero `ExternalTunnel.appex`, `ExtLocalDevVPNManager` y el formato TXT, antes de generar otra IPA.
