# Guía completa: qué estamos intentando hacer con Nixel, External/AirLift y Remote Pairing

**Fecha de corte:** 2026-10-03  
**Proyecto:** `davidporfirio17-svg/davizin-ios-v2`  
**Rama:** `feature/jailbreak-hybrid-foundation`  
**Último commit de código:** `cad5dac`  
**Último commit posterior de documentación:** `4dc5d39`

---

## 1. Instrucción principal para el siguiente chat

No empezar generando otra IPA ni cambiando nombres al azar.

Primero leer esta guía y revisar directamente:

```text
External-1.ipa
ExternalTunnel.appex
ExternalLogin.dylib
AirLiftPairingController
AirLiftPairingKeepAlive
ExtLocalDevVPNManager
NixelHybridCoordinator.swift
NixelAirLiftBridge.m
NixelVPNManager.swift
ExternalTunnel/PacketTunnelProvider.swift
Vendor/idevice/ffi/src/pairing_host.rs
```

El problema ya no es simplemente “publicar Bonjour” ni “poner el nombre 2424”. Hay que reproducir el flujo completo de External: **VPN/Network Extension + servicios AirLift + Remote Pairing + handshake + registro RPairing + túnel posterior**.

---

## 2. Qué queremos conseguir

La aplicación Nixel tiene una operación llamada **Hybrid**. Queremos que esa operación haga, de forma real y comprobable, lo siguiente:

1. Preparar el transporte AirLift.
2. Activar correctamente la extensión VPN de tipo `PacketTunnelProvider`.
3. Publicar el servicio de Remote Pairing que el iPad espera.
4. Hacer que el iPad muestre un host llamado **2424** dentro de Developer Mode.
5. Permitir que el usuario seleccione ese host en el iPad.
6. Recibir la conexión iniciada por el iPad.
7. Completar el protocolo Remote Pairing/RPairing.
8. Mostrar o solicitar el PIN cuando corresponda.
9. Guardar correctamente el registro RPairing.
10. Reutilizar ese registro para iniciar la siguiente fase del túnel/RSD.
11. Solo marcar la operación como lista cuando el túnel y el handshake estén confirmados.

La meta no es mostrar una pantalla simulada de “conectado”. La meta es que el comportamiento sea equivalente al de la IPA **External/3105** que el usuario proporcionó como referencia.

---

## 3. Qué significa `2424`

`2424` no es un puerto ni un número arbitrario.

En External se observó:

```text
CFBundleExecutable = 2424
```

Y el binario contiene:

```text
2424 AirLift Pairing
Open Settings > Developer Mode and pair with 2424.
Enter the pairing PIN in Settings.
```

Por lo tanto:

- **Nombre visible:** `2424`.
- **Identificador mDNS interno:** puede ser un UUID generado por el host.
- **`identifier` del TXT:** debe concordar con la identidad mDNS/protocolo.
- El UUID no debe mostrarse al usuario como si fuera el nombre humano.

La última corrección separó parcialmente estos conceptos, pero el iPad todavía no muestra `2424` en Developer Mode.

---

## 4. Archivos entregados por el usuario

### External

```text
/home/ubuntu/upload/External-1.ipa
```

Extraída en:

```text
/home/ubuntu/analysis_external1/Payload/3105.app/
```

Componentes importantes:

```text
2424
ExternalLogin.dylib
PlugIns/ExternalTunnel.appex/ExternalTunnel
Info.plist
```

### AltStore

```text
/home/ubuntu/upload/AltStore-marketplace.zip
```

Extraído en:

```text
/home/ubuntu/altstore-marketplace/AltStore-marketplace/
```

AltStore sirve como referencia para el patrón general de `NWListener`, `NWConnection` y servicios Bonjour, pero **no contiene el VPN ni el protocolo específico de External**.

### Código de Nixel

```text
/home/ubuntu/davizin-ios-v2/
```

Paquete fuente completo entregado:

```text
/home/ubuntu/davizin-ios-v2/Nyxel_External_source-cad5dac.zip
```

---

## 5. Qué se descubrió en External/3105

### 5.1. External tiene dos servicios Bonjour

Su `Info.plist` declara:

```text
_remotepairing-pairable-host._tcp
_3105airlift._tcp
```

El binario contiene además:

```text
2424AirLiftProbe
```

Interpretación actual:

- `_remotepairing-pairable-host._tcp` parece ser el servicio principal para Remote Pairing.
- `_3105airlift._tcp` parece ser un servicio de probe, keep-alive o transporte auxiliar de AirLift.
- Todavía no está demostrado qué protocolo exacto habla el segundo servicio.
- Publicar el nombre no basta: posiblemente hay que implementar la respuesta que espera External/iPadOS.

### 5.2. External tiene una VPN real

External contiene:

```text
PlugIns/ExternalTunnel.appex/ExternalTunnel
```

El binario contiene la clase:

```text
ExternalTunnelProvider
```

y hereda de:

```text
NEPacketTunnelProvider
```

Usa:

```text
startTunnelWithOptions:completionHandler:
stopTunnelWithReason:completionHandler:
setTunnelNetworkSettings:completionHandler:
packetFlow
readPacketsWithCompletionHandler:
writePackets:withProtocols:
```

Las direcciones encontradas son:

```text
TunnelIfaceIP = 10.7.1.1/32
TunnelPeerIP  = 10.7.0.1/32
```

La app principal también usa:

```text
NETunnelProviderManager
NETunnelProviderProtocol
providerBundleIdentifier
loadFromPreferences
saveToPreferences
startVPNTunnelWithOptions:andReturnError:
```

Esto es fundamental: **External no es solamente una aplicación que publica un servicio Bonjour**. Tiene una extensión VPN que configura una interfaz de túnel y mueve paquetes.

### 5.3. External contiene un controlador de pairing

El binario contiene símbolos y estados relacionados con:

```text
AirLiftPairingController
AirLiftPairingKeepAlive
```

También contiene textos como:

```text
prepare: name=%@ model=%@
prepared: service=%@ txtKeys=%@
bind listener failed: errno=%d
listening on port %d
Pairing failed
PIN issued (redacted)
host success: device=%@ model=%@ file=private
Pairing saved securely.
RPPairing record loaded
RSD tunnel established (adapter+handshake)
```

La secuencia observada sugiere que External mantiene una sesión de pairing y después usa el registro para crear el túnel/RSD.

### 5.4. External publica el texto que guía al usuario

Los literales más importantes son:

```text
2424 AirLift Pairing
Open Settings > Developer Mode and pair with 2424.
Enter the pairing PIN in Settings.
```

Nixel debe mostrar una instrucción equivalente, pero la instrucción visual no demuestra que el protocolo esté funcionando.

---

## 6. Qué hay actualmente en Nixel

### 6.1. PairableHost Rust/FFI

Nixel integra un backend basado en `idevice-rs`:

```text
Vendor/idevice/ffi/src/pairing_host.rs
```

La API relevante es:

```c
pairable_host_prepare(...)
pairable_host_accept_fd(...)
pairable_host_free(...)
```

`pairable_host_prepare` genera:

- una identidad de host;
- un `serviceID` generado;
- TXT records;
- una estructura de pairing que se conserva hasta aceptar la conexión.

Los TXT incluyen normalmente:

```text
name
identifier
authTag
model
flags
ver
minVer
```

El código Rust documenta que:

- `name` es el nombre humano que ve el dispositivo;
- `model` es el modelo de host, por ejemplo `Mac17,7`;
- `service_identifier` debe coincidir con la identidad mDNS y el identificador enviado durante pairing;
- `authTag` depende del `altIRK` y del identificador;
- el `altIRK`/identidad debe persistirse correctamente para sesiones posteriores.

### 6.2. Nombre y modelo que usa Nixel

Actualmente Nixel inicia el host con:

```swift
nyxel_pairable_host_start("2424", "Mac17,7")
```

Esto es razonable y coincide con lo observado en External.

### 6.3. Listener y proxy actuales

Nixel hace aproximadamente esto:

```text
pairable_host_prepare
        ↓
socket POSIX local
        ↓
NWListener _remotepairing-pairable-host._tcp
        ↓
NWConnection entrante
        ↓
proxy TCP
        ↓
socket local PairableHost
        ↓
pairable_host_accept_fd
```

Además, la última revisión añadió:

```text
NWListener _3105airlift._tcp
nombre 2424AirLiftProbe
```

El segundo listener actualmente registra el servicio y cierra la conexión entrante. Eso puede ser insuficiente si External espera un protocolo de probe/keep-alive real.

### 6.4. Diagnósticos añadidos

Nixel ahora distingue algunos estados:

```text
listener NWListener listo
Servicio mDNS registrado
Probe AirLift registrado
Conexión entrante AirLift lista
Proxy local conectado al socket PairableHost
PIN recibido
Pairing completado
```

Pero todavía falta separar completamente los estados VPN, proveedor, handshake, RSD y persistencia.

---

## 7. Historial de pruebas realizadas

### Prueba inicial de External

Se analizó la IPA y se identificaron:

- Remote Pairing.
- `_remotepairing-pairable-host._tcp`.
- `AirLiftPairingController`.
- `ExternalTunnel.appex`.
- VPN mediante `NEPacketTunnelProvider`.

### Pruebas de Nixel con pairing manual

Se intentó dirigir al usuario a Developer Mode, pero en el iPad no aparecía el menú/host esperado.

### Pruebas con NSNetService

Resultado reportado:

```text
Bonjour no pudo publicar el host PairableHost
DNS NetService error code -72000
```

Conclusión: `NSNetService` no era una base suficiente para esta implementación.

### Pruebas con `NWListener`

Se cambió la publicación hacia `NWListener` y `NWParameters`.

Se corrigió el orden para usar:

```swift
let parameters = NWParameters.tcp
parameters.includePeerToPeer = true
let listener = NWListener(using: parameters, on: .any)
```

Esto eliminó la dependencia de modificar parámetros después de crear el listener, pero no hizo que Developer Mode mostrara `2424`.

### Prueba con el segundo servicio

Se publicó también:

```text
_3105airlift._tcp
2424AirLiftProbe
```

Resultado del usuario:

```text
Host local publicado 2424
Probe AirLift registrado 2424 AirLift
Probe 3105 AirLift
TCP local
```

Después apareció:

```text
Host local publicado 2424
Provider AirLift no disponible
No se ha podido completar la operación
```

Y en Developer Mode siguió sin aparecer ningún host.

---

## 8. Último estado exacto

### Último commit de código probado

```text
cad5dac
```

### Último commit de documentación

```text
4dc5d39
```

### Último build verde

```text
Run: 37167845639
URL: https://github.com/davidporfirio17-svg/davizin-ios-v2/actions/runs/37167845639
```

### Último artefacto

```text
Nyxel_External_iOS_unsigned
```

### Última IPA probada

```text
Nyxel_External_unsigned.ipa
```

La IPA compiló correctamente, pero **no resolvió el problema funcional**.

---

## 9. Qué significa el error actual

El usuario reporta esencialmente:

```text
Host local publicado 2424
Probe AirLift registrado
Provider AirLift no disponible
No se ha podido completar la operación
```

Esto no significa necesariamente que el nombre esté mal.

Significa que probablemente ocurre una de estas situaciones:

### Hipótesis A — Falta una configuración válida del VPN

La app anuncia servicios, pero `NETunnelProviderManager` no tiene una configuración válida, no carga la extensión correcta o el túnel no llega a `.connected`.

### Hipótesis B — El segundo servicio no es solo un anuncio

Nixel publica `2424AirLiftProbe`, pero actualmente cierra la conexión. External puede esperar un handshake/protocolo de probe.

### Hipótesis C — TXT incorrecto

Puede que el iPad ignore el host porque uno de estos valores no coincide:

```text
name
identifier
authTag
model
flags
ver
minVer
```

También puede haber una diferencia entre:

- nombre de instancia mDNS;
- `identifier` del TXT;
- UUID generado;
- host visible `2424`.

### Hipótesis D — El proxy no conserva el transporte esperado

El FFI actual acepta un file descriptor. Nixel convierte la conexión `NWConnection` a un proxy TCP local. Aunque los bytes parezcan transparentes, puede haber diferencias de:

- ciclo de vida;
- cierre de conexión;
- IPv4/IPv6;
- interfaz de red;
- peer-to-peer;
- timing;
- framing;
- lectura parcial;
- backpressure.

### Hipótesis E — El orden VPN → AirLift → pairing es incorrecto

Todavía hay que verificar con más precisión si External:

1. configura la VPN;
2. espera que el proveedor llegue a `.connected`;
3. publica el servicio;
4. abre Developer Mode;
5. espera el pairing;
6. carga el RPairing;
7. crea el túnel RSD.

No se debe asumir el orden actual de Nixel sin confirmarlo.

---

## 10. Qué revisar primero en el siguiente chat

### Paso 1 — Revisar la configuración del Network Extension

Comparar External y Nixel en:

```text
Info.plist
entitlements
bundle identifiers
providerBundleIdentifier
NETunnelProviderProtocol
NEPacketTunnelNetworkSettings
```

Comprobar en Nixel:

- que el target de la extensión existe;
- que el bundle ID utilizado por la app coincide con el de la extensión;
- que la configuración VPN se guarda y carga;
- que `saveToPreferences` no falla;
- que `loadFromPreferences` recupera el perfil;
- que la extensión realmente arranca;
- que el proveedor llama a `setTunnelNetworkSettings`;
- que el callback de `startTunnel` se ejecuta con éxito.

No marcar “VPN conectada” solo porque `startVPNTunnel` no lanzó una excepción.

### Paso 2 — Añadir diagnóstico de VPN real

El diagnóstico debe distinguir:

```text
VPN_MANAGER_LOADED
VPN_PROFILE_CREATED
VPN_PROFILE_SAVED
VPN_START_REQUESTED
VPN_PROVIDER_STARTED
VPN_NETWORK_SETTINGS_APPLIED
VPN_CONNECTED
VPN_DISCONNECTED
VPN_PROVIDER_ERROR
```

El error `Provider AirLift no disponible` tiene que capturar el `NSError` completo:

- dominio;
- código;
- `localizedDescription`;
- `userInfo`;
- estado `NEVPNStatus`.

### Paso 3 — Extraer y comparar el TXT

En Nixel hay que registrar de forma segura, sin mostrar claves privadas:

```text
service instance
name
identifier
model
flags
ver
minVer
longitud de authTag
puerto publicado
interfaz
```

No registrar el `altIRK` ni material secreto.

Luego comparar esos campos con lo que se pueda reconstruir de External.

### Paso 4 — Analizar la clase `AirLiftPairingKeepAlive`

Hay que determinar si `_3105airlift._tcp`:

- solo mantiene un anuncio vivo;
- acepta un protocolo corto;
- comunica el estado del VPN;
- sirve para localizar la app;
- es un canal auxiliar para Developer Mode;
- necesita TXT records propios.

El listener actual que simplemente acepta y cierra conexiones es provisional y no debe considerarse equivalente a External.

### Paso 5 — Revisar el listener real de pairing

Determinar si External usa:

- `NWListener` directamente;
- `NSNetService` más socket POSIX;
- `NWConnection` directo hacia el protocolo;
- un listener creado dentro de la extensión VPN;
- un puerto anunciado diferente al puerto local del proxy.

La implementación actual de Nixel tiene dos puertos conceptuales:

1. socket local del PairableHost;
2. puerto del `NWListener` publicado por Bonjour.

Hay que confirmar que External funciona de la misma manera.

### Paso 6 — Revisar persistencia de identidad

`pairable_host_prepare` genera una identidad nueva en cada llamada.

Hay que verificar si External persiste:

- `altIRK`;
- `serviceID`/identifier;
- pairing file;
- datos de host;
- estado de keep-alive.

Si Nixel genera un UUID e identidad nueva cada vez, el iPad podría no reconocer la relación entre sesiones o rechazar el servicio.

---

## 11. Qué no hacer

No repetir estas acciones sin nueva evidencia:

- Cambiar solo `2424` por otro nombre.
- Cambiar el UUID manualmente.
- Añadir más nombres Bonjour sin conocer el protocolo.
- Añadir más modos de background como solución principal.
- Añadir un proxy TCP adicional sin instrumentarlo.
- Declarar “pairing completado” al recibir `.ready` del listener.
- Declarar “VPN conectada” solo porque se llamó a `startVPNTunnel`.
- Entregar otra IPA sin saber qué estado funcional se pretende validar.
- Copiar AltStore como si fuera External: AltStore no contiene este VPN ni este protocolo.
- Suponer que una cuenta Apple Developer desbloquea APIs privadas de Remote Pairing.

---

## 12. Criterio para producir la siguiente IPA

Antes de compilar una nueva IPA, el cambio debe responder claramente:

1. ¿Qué diferencia concreta de External se está implementando?
2. ¿Qué error o estado actual corrige?
3. ¿Qué evidencia se verá en pantalla si funciona?
4. ¿Qué evidencia demostrará que no funcionó?
5. ¿Cómo se diferenciará un fallo de VPN de un fallo de Bonjour?

La próxima IPA debería mostrar o registrar estados equivalentes a:

```text
AIRLIFT_PREPARE_STARTED
VPN_PROFILE_LOADED
VPN_PROVIDER_STARTED
VPN_NETWORK_SETTINGS_APPLIED
VPN_CONNECTED
PAIRABLE_HOST_PREPARED
PAIRING_SERVICE_REGISTERED
AIRLIFT_PROBE_REGISTERED
DEVELOPER_MODE_CONNECTION_RECEIVED
PAIRING_HANDSHAKE_STARTED
PIN_ISSUED
RPAIRING_SAVED
RSD_TUNNEL_READY
```

La operación Hybrid debe terminar en error si no se confirma el estado correspondiente.

---

## 13. Estado final honesto

Estamos cerca en el sentido de que ya conocemos varias piezas importantes de External:

- nombre visible `2424`;
- servicio principal Remote Pairing;
- segundo servicio AirLift;
- VPN `ExternalTunnel.appex`;
- direcciones del túnel;
- clases y mensajes de pairing;
- presencia de registro RPairing;
- secuencia posterior hacia RSD.

Pero todavía no estamos cerca de una réplica funcional completa. Lo que funciona actualmente es principalmente:

- compilación del proyecto;
- generación de la IPA;
- preparación del PairableHost FFI;
- creación local de listeners;
- publicación parcial de los servicios.

Lo que sigue fallando o no está demostrado:

- que Developer Mode muestre `2424`;
- que el Provider AirLift esté disponible;
- que la VPN sea funcional;
- que el segundo servicio responda al protocolo esperado;
- que el iPad inicie la conexión real;
- que se complete el handshake;
- que el registro RPairing se guarde;
- que RSD quede operativo.

El siguiente trabajo correcto es **auditar la Network Extension y el flujo real de External antes de volver a generar una IPA**.

---

## 14. Archivos útiles para continuar

Código principal:

```text
DavizinIOS/NixelHybridCoordinator.swift
DavizinIOS/NixelAirLiftBridge.m
DavizinIOS/NixelAirLiftBridge.h
DavizinIOS/NixelVPNManager.swift
DavizinIOS/DavizinBridge.swift
ExternalTunnel/PacketTunnelProvider.swift
```

Backend:

```text
Vendor/idevice/ffi/src/pairing_host.rs
Vendor/idevice/idevice/src/remote_pairing/responder.rs
```

Referencia:

```text
/home/ubuntu/analysis_external1/Payload/3105.app/2424
/home/ubuntu/analysis_external1/Payload/3105.app/ExternalLogin.dylib
/home/ubuntu/analysis_external1/Payload/3105.app/PlugIns/ExternalTunnel.appex/ExternalTunnel
```

Workflow:

```text
.github/workflows/build.yml
```

---

## 15. Paquete fuente

El paquete con el proyecto y el submódulo fuente completo es:

```text
Nyxel_External_source-cad5dac.zip
```

Incluye código, configuración, workflow y `Vendor/idevice`; no incluye IPAs ni artefactos de GitHub Actions.
