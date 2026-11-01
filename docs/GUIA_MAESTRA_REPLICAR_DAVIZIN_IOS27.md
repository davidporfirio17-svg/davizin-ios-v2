# Guía maestra de continuidad y réplica — Davizin iOS V2

> **Base de esta guía:** repositorio `davidporfirio17-svg/davizin-ios-v2`, rama `fix/ios27-injection-progress`, estado del código `499e481` (y commits anteriores de esa rama), build de GitHub Actions `37870058431`.
>
> **Límite importante sobre iOS 27:** la versión documentada **no contiene un jailbreak de kernel validado para iOS 27**. En iOS 27 la ruta que se probó es pairing + RSD/AirLift para una operación de archivos dentro del contenedor de la app seleccionada. La tabla de offsets del kernel se considera válida solo hasta iOS 26.0.x. No extenderla a iOS 27 ni inventar offsets.

## 1. Para qué sirve esta guía

Esta guía permite que una persona o una IA entienda la estructura del proyecto actual, conserve sus componentes al rediseñar la interfaz, compile una IPA mediante GitHub Actions y diagnostique los fallos que ya ocurrieron.

Está basada en los archivos y ejecuciones reales de la rama indicada; **no es una receta para crear un exploit nuevo, saltarse la seguridad de iOS ni afirmar que se hizo jailbreak al dispositivo**. Para una nueva app, mantén las operaciones dentro de interfaces y permisos autorizados, usa identificadores de bundle propios y no alteres las protecciones del sistema.

### Estado verificado

| Elemento | Estado de esta revisión |
|---|---|
| Repositorio | `davidporfirio17-svg/davizin-ios-v2` |
| Rama de continuidad | `fix/ios27-injection-progress` |
| Commit de referencia | `499e48141e5131c637e264f4611e73c50dde7bd0` |
| Acción de compilación | [GitHub Actions run 37870058431](https://github.com/davidporfirio17-svg/davizin-ios-v2/actions/runs/37870058431) |
| Resultado del run | `success`; compiló Rust, Xcode, extensión, paquete IPA y subió el artefacto |
| Artefacto | `Nyxel_External_unsigned.ipa` dentro de `Nyxel_External_iOS_unsigned` |
| Naturaleza del artefacto | Xcode compila sin firma/provisioning normal; el workflow luego procesa entitlements. No es una IPA firmada para distribución estándar de Apple. |
| iOS 27 observado por el usuario | iOS 27.0, build `24A437` |
| Kernel offsets | `supportsKernelOffsets` limita el uso verificado a iOS anterior a 26 o a iOS 26.0.x; no cubre iOS 27. |

Que Actions compile correctamente demuestra que el código construye y produce un artefacto. **No sustituye una prueba en el dispositivo** ni demuestra por sí solo que cualquier versión, build o modelo sea compatible.

## 2. Qué hace — y qué no demuestra — la ruta de iOS 27

El código separa varias condiciones que no se deben confundir:

1. La política reconoce un conjunto de versiones/builds concretos; no significa que todos los iOS 27 estén verificados.
2. `NixelPairingRecordStore` guarda un registro de pairing bajo el identificador `2424`. La mera conexión VPN no crea ese registro.
3. Si hay registro disponible, `DavizinBridge` selecciona AirLift y evita ejecutar el exploit de kernel experimental.
4. `NixelHybridCoordinator.startForAirLift` prepara el túnel y comprueba que un endpoint RSD responda por TCP en el puerto `49152`.
5. `NixelAirLiftFileChannel` usa el registro para resolver el contenedor de la app y pasar la operación al FFI AirLift.
6. Una prueba TCP satisfactoria solo significa que el endpoint respondió; **no demuestra jailbreak, root ni acceso general al sistema de archivos**.

### Builds contemplados por la política del commit de referencia

`NyxelSupportPolicy.swift` contiene una lista cerrada, entre ella la rama iOS 27.0 con `24A435` y `24A437`, además de builds beta listados en ese archivo. Para 27.2 incluye `24B5084k` y `24B5089g`. La política es específica de la revisión; antes de reutilizarla, confirma el build exacto del dispositivo y actualiza la lista únicamente con evidencia de pruebas legítimas.

La etiqueta **Compatible** representa la política de versión del programa: no la interpretes como “kernel exploit confirmado” ni “jailbreak terminado”. Para el build `24A437`, la ruta de este proyecto es pairing/RSD/AirLift; los offsets de kernel no lo cubren.

### Qué significa “VPN” en este proyecto

`ExternalTunnel/PacketTunnelProvider.swift` instala rutas de red para alcanzar endpoints RSD `10.7.0.1`–`10.7.0.3`. Ese túnel **no otorga permisos de carpeta por sí mismo**. El pairing, el registro guardado, el servicio RSD y la disponibilidad del contenedor son comprobaciones distintas. No uses “VPN conectado” como sinónimo de “ya tengo acceso para escribir”.

## 3. Mapa del código

| Ruta | Responsabilidad | Al rediseñar |
|---|---|---|
| `DavizinIOS/ViewController.swift` | Navegación/pantallas y eventos de ciclo de app | Puede cambiar la presentación; conserva contratos con el bridge y el estado de recuperación. |
| `DavizinIOS/OperationView.swift` | Pantalla de operación, estados, mantener para confirmar, limpiar y abrir juego | Rediseña la vista sin duplicar ni saltarse la máquina de estados. |
| `DavizinIOS/ModeSelectionView.swift`, `DavizinIOS/DavizinModeSheet.swift` | Presentación de modos | Los modos llegan de configuración dinámica; no fijes el nombre “Indexable External” como ID salvo que el backend lo defina así. |
| `DavizinIOS/DavizinBridge.swift` | Orquesta validación, preflight y selección de operación/transporte | Es la frontera entre UI y lógica; no llames FFI directamente desde una vista nueva. |
| `DavizinIOS/NixelHybridCoordinator.swift` | Estados de pairing, inicio de VPN y preflight RSD | Conserva el orden y los resultados explícitos; no conviertas un estado parcial en éxito. |
| `DavizinIOS/NixelVPNManager.swift`, `DavizinIOS/NixelPairingKeepAlive.swift` | Configuración del túnel y mantener viva la sesión de pairing | Cambios aquí pueden impedir el descubrimiento o el retorno de red. |
| `DavizinIOS/NixelAirLiftFileChannel.swift` | Prepara paths temporales, resuelve contenedor y llama al canal AirLift | Conserva validación de rutas y manejo de errores. |
| `DavizinIOS/NixelAirLiftFFI.swift`, `NixelAirLiftBridge.h/.m`, `NixelAirLiftC.h` | Puente Swift/C/Objective-C hacia el FFI | Las firmas deben coincidir con `airlift-rust-core/include/airlift.h`. |
| `airlift-rust-core/` | Núcleo Rust del transporte AirLift y llamadas FFI | Compílalo en macOS para targets iOS; no asumas que el entorno Linux puede producir una IPA. |
| `DavizinIOS/GrappaHelper.h/.m` | Helper nativo que expone el símbolo que espera el puente AirLift | Debe formar parte de las fuentes del target Xcode; no pegues secretos o material de autenticación en documentación/prompts. |
| `DavizinIOS/AppDelegate.swift` | Entrada de app; conserva referencia del símbolo nativo | Si se elimina la referencia, el linker puede dejar de conservar el símbolo dinámico. |
| `DavizinIOS/InjectorService.swift` | Validación de versión, recurso, backup, escritura y restauración | No declares éxito antes de que termine la escritura y se actualice el estado de limpieza. |
| `DavizinIOS/DavizinMCM.m`, `mcm_bridge.m/.h` | Interfaz MCM heredada/detección de contenedor | Una detección MCM no es prueba de que el canal remoto pueda escribir. |
| `DavizinIOS/NyxelDiagnostics.swift`, `DavizinIOS/ProfileView.swift` | Historial técnico, sanitización, copiar y exportar `.txt` | No elimines la salida de diagnóstico al cambiar el diseño. Revisa que no incluya secretos. |
| `ExternalTunnel/` | Target de Network Extension y sus entitlements | Cambiar target, bundle ID o entitlements requiere actualizar proyecto, workflow y firma autorizada. |
| `DavizinIOS.xcodeproj/project.pbxproj` | Referencias y fases de compilación del target app/extensión | Tener un archivo en el directorio no basta: Xcode debe compilarlo. |
| `.github/workflows/build.yml` | Construye Rust/Xcode, procesa entitlements, crea y sube IPA | El workflow modifica temporalmente algunas referencias del proyecto para añadir fuentes C/M. |
| `.gitmodules`, `Vendor/` | Dependencias externas/submódulos | Clona con submódulos recursivos y conserva versiones fijadas. |

`NixelPairingRecordStore` está declarado dentro de `DavizinIOS/NixelHybridCoordinator.swift` en esta revisión; no busques un archivo independiente con ese nombre.

## 4. Cómo se construyó la IPA actual en GitHub Actions

El flujo real de `.github/workflows/build.yml` es:

1. Corre en un runner macOS (`macos-14`) y hace checkout con submódulos recursivos.
2. Añade los targets Rust `aarch64-apple-ios` y `aarch64-apple-ios-sim`.
3. Compila el FFI Rust en release para dispositivo y simulador.
4. Genera un `AirliftFFI.xcframework` temporal con las bibliotecas y headers.
5. Usa la gema Ruby `xcodeproj` para añadir al proyecto las fuentes `kexploit` y `mcm_bridge` que el workflow necesita en ese build.
6. Ejecuta `xcodebuild` con scheme/target `DavizinIOS`, configuración Release, SDK iPhoneOS, arquitectura arm64 y deployment target iOS 16.0. El paso desactiva la firma normal de Xcode.
7. Procesa entitlements con `ldid`, incluyendo la extensión `ExternalTunnel` si existe.
8. Empaqueta el `.app` en `Payload/DavizinIOS.app` y genera `Nyxel_External_unsigned.ipa`.
9. Publica el artefacto con nombre `Nyxel_External_iOS_unsigned`, retenido por Actions durante 30 días.

### Lanzar y bajar una compilación

Requiere `gh` autorizado para el repositorio. En una máquina con `gh` configurado:

```bash
gh repo clone davidporfirio17-svg/davizin-ios-v2
cd davizin-ios-v2
git checkout fix/ios27-injection-progress
git pull --ff-only
git submodule update --init --recursive

# El workflow acepta workflow_dispatch en una rama
 gh workflow run build.yml \
  --repo davidporfirio17-svg/davizin-ios-v2 \
  --ref fix/ios27-injection-progress

gh run list \
  --repo davidporfirio17-svg/davizin-ios-v2 \
  --branch fix/ios27-injection-progress \
  --limit 5

# Sustituye RUN_ID por el ID devuelto por gh run list
gh run watch RUN_ID --repo davidporfirio17-svg/davizin-ios-v2 --exit-status
mkdir -p artifacts/RUN_ID
gh run download RUN_ID \
  --repo davidporfirio17-svg/davizin-ios-v2 \
  --dir artifacts/RUN_ID
find artifacts/RUN_ID -type f -name '*.ipa' -print
```

Este workflow se ejecuta automáticamente en `push` a `main`; en una rama de trabajo se debe usar `workflow_dispatch` como arriba. **No empujes a `main` solo para activar una compilación.**

Para verificar un artefacto descargado:

```bash
unzip -t ruta/al/archivo.ipa
shasum -a 256 ruta/al/archivo.ipa
```

El build de referencia `37870058431` compiló el commit `499e48141e5131c637e264f4611e73c50dde7bd0`; el artefacto validado pesó aproximadamente 8.2 MB. El hash de ese archivo fue `2137fde91fcfa13b156a2fc4c98a95d7cb787f1286763efc3a60a64256166d68`.

### Firma

La salida de Actions se nombra `unsigned`. No incluye provisioning profile ni una firma estándar de distribución de Apple. Para instalar/distribuir una app legítima, usa identificadores propios y el proceso de firma autorizado de tu equipo Apple. **No reutilices identificadores reservados de Apple** que aparezcan en el proyecto actual (`com.apple.mobile.MobileHouseArrest` y su extensión) en una app nueva ni intentes hacer pasar una app nueva por un componente del sistema. Si cambiar esos identificadores rompe el transporte, detente y resuelve esa dependencia por una vía soportada; no suplantes el bundle ID.

## 5. Cómo crear otra interfaz conservando la arquitectura

La estrategia de menor riesgo es hacer un branch/fork del commit conocido y cambiar primero solo la capa de UI:

1. **Congela la base:** usa `499e481` o una revisión posterior confirmada; apunta el hash exacto en el README nuevo.
2. **Crea rama de diseño:** por ejemplo `ui/nueva-interfaz`; no mezcles una renovación visual con cambios del transporte o de compatibilidad.
3. **Traza cada acción:** botón de inyectar → `DavizinBridge` → preflight correspondiente → `InjectorService` → resultado → estado de limpieza. La vista nueva debe invocar el mismo contrato, no llamar a MCM/AirLift directamente.
4. **Conserva estados explícitos:** checking, injecting, failed, succeeded, needsCleaning, readyToOpen y readyToReopen. La UI puede presentar esos estados diferente, pero no debe ocultar un fallo o habilitar una segunda escritura cuando hay restauración pendiente.
5. **Conserva el diagnóstico:** deja Perfil con copiar/descargar `.txt`; los logs actuales limitan retención y sanitizan credenciales/PIN de pairing.
6. **Conserva los puentes:** no renombres exports, headers C, símbolos FFI ni targets sin actualizar todos los consumidores y el build.
7. **Registra fuentes nativas en Xcode:** cada `.m/.h` debe quedar en el grupo y, cuando corresponde, en la fase `Sources` del target. Revisa también lo que agrega temporalmente el workflow Ruby.
8. **No cambies la compatibilidad por apariencia:** `Compatible` no debe significar “jailbreak verificado”. Mantén mensajes separados para versión permitida, pairing disponible, VPN conectado y RSD alcanzable.
9. **No distribuyas la nueva app con IDs/entitlements Apple reservados.** Define un bundle ID propio, usa provisioning autorizado y revisa el target de la extensión con el mismo criterio.
10. **Compila después de cada cambio pequeño:** primero solo UI; después, si es necesario, una modificación aislada de configuración. Revisa diff y run ID antes de mezclar.

### Lo que no conviene copiar de `test1`

`test1-main.zip` se utilizó como **referencia de comparación**, no como plantilla para reemplazar V2 entero. Se compararon fuentes y call graphs. Varias piezas de kernel/sandbox/offsets ya coincidían o eran distintas por integración; copiar todos los archivos habría podido duplicar símbolos, desalinear el `.pbxproj` o reemplazar una implementación V2 más nueva.

La referencia fue útil para comparar el protocolo de escritura por lote, pero no demuestra que su exploit, sus offsets o su configuración funcionen en iOS 27. Antes de trasladar cualquier fuente: compara el archivo, sus dependencias, el target donde se compila y su entrada real desde la app.

## 6. Errores reales y lecciones para no repetirlos

### A. Se confundió el error ATC con una carpeta inexistente

Mensaje visto:

```text
ATC channel closed waiting for ReadyForSync ... read length: channel closed
```

Ese texto demuestra que la sesión ATC se cerró antes de que el writer recibiera la respuesta esperada. **Por sí solo no prueba que falte la carpeta**, ni que el problema se arregle agregando offsets de kernel. Para investigar se agregó exportación de diagnóstico con etapa, resultado del FFI y mensajes ATC sanitizados.

**Lección:** separar en logs “pairing cargado”, “contenedor resuelto”, “RSD preflight”, “writer iniciado” y “respuesta ATC”. No interpretar todos los fallos como “no hay permisos de carpeta”.

### B. Un preflight de Apple Books bloqueaba el transporte antes de tiempo

Se añadió una comprobación de Installation Proxy y produjo “Apple Books is not installed”. La comprobación no era una prueba suficiente de que el transporte AirLift funcionara o no. Se quitó ese bloqueo y se dejó que el handshake ATC devolviera el resultado real.

**Lección:** no agregues una dependencia obligatoria a partir de una suposición. Un preflight debe probar exactamente la condición que necesita el paso siguiente y dar un error comprobable.

### C. Faltaba un símbolo nativo que el FFI buscaba

El núcleo Rust esperaba resolver el símbolo `ALGetGrappaToken` en tiempo de ejecución, pero en V2 faltaba integrar en el target Xcode el helper nativo correspondiente. La mera presencia de un archivo en el checkout no garantiza que forme parte del binario. Se integraron `GrappaHelper.m/.h` al proyecto y se conservó una referencia al símbolo; el nuevo build compiló y, tras esa IPA, el usuario confirmó que la operación dejó de mostrar el fallo anterior.

**Lección:** ante `symbol not found` o un handshake que nunca comienza, busca el símbolo en el código, la fase `Compile Sources`, el link y el binario generado. No copies material de autenticación/token en una guía, prompt o log.

### D. Error de tipos Swift `NSString` / `String`

Una primera compilación falló porque el wrapper Objective-C devolvía `NSString?` y el código Swift lo concatenaba como `String`. La solución fue normalizar la conversión en el límite del wrapper y volver a ejecutar Actions.

**Lección:** arregla el primer error real del compilador; no intentes corregir los mensajes derivados antes de resolver el tipo original.

### E. Demasiados banners durante la inyección

`sendErrorNotification` pedía permiso y programaba una notificación del sistema por cada paso. La versión actual conserva esos detalles en el historial técnico, pero ya no los publica como banners ni como texto de progreso que cambia constantemente. El permiso se solicita desde el flujo de pairing; el PIN 2424 se notifica y el recordatorio de limpieza se programa a los 6 segundos.

**Lección:** logs detallados no deben convertirse en alertas repetidas para el usuario. Conserva el historial exportable y presenta solo el resultado final/error.

### F. La compilación de CI se confundía con una prueba completa

Actions compila en macOS; no prueba en el iPhone la solicitud de notificaciones, pairing real, red RSD ni escritura/limpieza final.

**Lección:** etiqueta cada afirmación como **compila**, **se instaló**, **pairing validado**, **RSD alcanzable**, **escritura probada** o **restauración probada**. No saltes de “build verde” a “todo iOS 27 está soportado”.

## 7. Lista de revisión por cambio

### Antes de editar

- [ ] Registrar rama y commit base.
- [ ] Leer el caller y el callee de la función que se tocará.
- [ ] Confirmar si el archivo ya existe en V2 antes de copiarlo de `test1`.
- [ ] Para iOS 27, comprobar versión y build reales; no usar detección solo por `majorVersion`.
- [ ] Confirmar qué significa cada estado: pairing, túnel, RSD, compatibilidad y resultado de escritura.

### Antes del push

- [ ] `git diff --check`.
- [ ] Revisar `git diff --stat` y el diff completo; no incluir tokens, PIN, keys, HWID o datos personales.
- [ ] Revisar `.pbxproj`, headers y target Sources cuando se agrega código Swift/Objective-C/C.
- [ ] Mantener las pruebas/guardias existentes; no ampliar offsets de kernel a iOS 27.
- [ ] Usar una rama; no sobrescribir `main` ni la rama base.

### Antes de entregar la IPA

- [ ] El run tiene `conclusion: success` y `headSha` igual al commit que se quería compilar.
- [ ] Descargar el artefacto del run exacto, no de un run anterior.
- [ ] Ejecutar `unzip -t` y guardar SHA-256.
- [ ] Confirmar textos/símbolos esperados en el binario si se añadió una integración nativa.
- [ ] Aclarar que es una IPA sin firma estándar.
- [ ] Probar en el dispositivo y exportar Perfil → “Descargar / compartir logs” si falla.

## 8. Prompt listo para pegar en otra IA

```text
Actúa como ingeniero senior de mantenimiento iOS. Trabaja sobre el repositorio privado
`davidporfirio17-svg/davizin-ios-v2`, rama `fix/ios27-injection-progress`, usando como
base el commit `499e48141e5131c637e264f4611e73c50dde7bd0` o uno posterior que yo confirme.

OBJETIVO
Crear una app nueva con una interfaz visual diferente, conservando únicamente los
contratos y componentes de transporte que sean legales, soportados y autorizados. Primero
inspecciona el repositorio, el call graph, el target Xcode y `.github/workflows/build.yml`.
No empieces copiando todos los archivos de otro proyecto.

REGLAS DE ARQUITECTURA
- Mantén UI separada de `DavizinBridge`, `InjectorService`, pairing, VPN/RSD, AirLift,
  los bridges FFI y los logs. Las vistas llaman al bridge; no al FFI directamente.
- Conserva estados de operación, respaldo/restauración y el bloqueo de reintento mientras
  haya limpieza pendiente.
- Conserva la exportación de logs desde Perfil y la sanitización de credenciales/PIN.
- Registra cada fuente nueva en el target/fase de compilación de Xcode; no basta con
  crear el archivo en el directorio.
- Preserva los headers, firmas FFI, submódulos y targets del workflow, o actualiza todos
  sus consumidores y comprueba el build.

LÍMITE iOS 27
En esta base no hay offsets de kernel validados para iOS 27: `supportsKernelOffsets` llega
solo hasta iOS 26.0.x. No inventes, generes, amplíes ni portes offsets, exploits de kernel,
sandbox escapes, bypasses de firma o acceso oculto a contenedores. La ruta existente para
los builds iOS 27 contemplados depende del pairing y del transporte AirLift/RSD; VPN activa
no equivale a pairing ni a permiso de escritura. No describas esta app como jailbreak salvo
que exista evidencia independiente y autorización explícita. Si el build del dispositivo no
está contemplado o el transporte falla, detente y reporta el límite exacto.

SEGURIDAD Y FIRMA
No reutilices bundle IDs reservados de Apple ni copies tokens, PINs, HWIDs, claves o
entitlements privados en prompts, logs o documentación. Para una app nueva, usa IDs propios
y firma con provisioning autorizado. Si un componente depende de IDs reservados o APIs no
soportadas, no busques un bypass: documenta el bloqueo y pide una alternativa soportada.

PROCESO
1. Resume la arquitectura y el impacto por archivo antes de cambiarla.
2. Propón el diseño nuevo sin editar todavía el transporte.
3. Implementa solo UI en una rama nueva y registra la lista de archivos cambiados.
4. Ejecuta `git diff --check`, inspecciona el diff y verifica inclusiones del `.pbxproj`.
5. Lanza `build.yml` con `workflow_dispatch` en la rama de trabajo.
6. Verifica que el run corresponde al commit exacto; descarga el IPA del run y comprueba
   ZIP/hash. Distingue build exitoso de prueba en dispositivo.
7. Entrega resumen, commit, URL de Actions, artefacto y limitaciones conocidas. No afirmes
   que una función funciona en hardware hasta que yo confirme la prueba.

No hagas push a `main`, no cambies código de kernel/offsets para “probar”, no reemplaces
el proyecto completo desde `test1`, y no escondas errores: deja diagnóstico exportable.
```

## 9. Fuentes de verdad y mantenimiento de esta guía

Para conocer el comportamiento actual, inspecciona en este orden:

1. `NyxelSupportPolicy.swift` para la lista de builds y el rango de offsets.
2. `DavizinBridge.swift` para decidir el transporte y bloquear rutas no verificadas.
3. `NixelHybridCoordinator.swift` para estados de pairing, VPN y preflight RSD.
4. `NixelAirLiftFileChannel.swift` y `airlift-rust-core/` para el contrato de escritura.
5. `.github/workflows/build.yml` para saber exactamente cómo se produce la IPA.
6. El run de Actions del commit exacto que se va a entregar.

`COMPATIBILITY_ENHANCEMENTS.md` es anterior y contiene frases generales de compatibilidad; no lo uses por encima de las guardias concretas que tiene el código actual. Actualiza esta guía cuando cambien los builds verificados, el workflow o la interfaz entre los módulos.
