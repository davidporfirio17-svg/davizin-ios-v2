# Adaptación de SupportPatch al proyecto Davizin iOS V2

## Decisión de integración

El ZIP recibido contiene **SupportPatch / 3105**, una app de gestión de archivos y parches para contenedores iOS. Su flujo de conectividad usa **LocalDevVPN**, una VPN externa que sirve como transporte de emparejamiento y acceso a operaciones de dispositivo. El repositorio `davizin-ios-v2` es **Davizin / Nyxel External**, con otro producto, otro backend y una extensión de túnel propia (`ExternalTunnel.appex`).

Por tanto, la adaptación conserva V2 como fuente de verdad y traslada solo las convenciones de build que encajan. No se copia la app completa ni se sustituye su VPN por LocalDevVPN.

## Correspondencias

| Área | SupportPatch adjunto | Davizin iOS V2 (se conserva) |
| --- | --- | --- |
| VPN | Abre/usa LocalDevVPN externo para pairing y operaciones con contenedores | `NixelVPNManager` instala y controla `ExternalTunnel.appex`; `NixelHybridCoordinator` y pairing son parte del flujo V2 |
| Build | GitHub Actions compila Simulator y dispositivo, y publica IPA unsigned | `.github/workflows/build.yml` compila el target/scheme Davizin, reconstruye Airlift FFI, incorpora entitlements con `ldid` y publica `Nyxel_External_unsigned.ipa` |
| Identidad | Bundle ID de compatibilidad `com.apple.mobile.MobileHouseArrest` | Se preservan bundle IDs, Worker, versión/build y protocolo de sesión existentes en V2 |
| Funcionalidad | Navegador/limpiador de contenedores, parches `.3105`, fondos y soporte de dispositivo | Se preservan los modos, pairing, validación, sesión Worker y flujos propios de Davizin |

## Qué se adapta

- Se mantiene el esquema de distribución de V2: IPA **unsigned** como artefacto de GitHub Actions, con firma/responsabilidades de instalación fuera de este pipeline.
- CI comprueba ahora que la compilación contiene la extensión `ExternalTunnel.appex` y que su `CFBundleIdentifier` coincide con el que busca `NixelVPNManager` (`com.apple.mobile.MobileHouseArrest.ExternalTunnel`). Así un build sin la pieza VPN falla en vez de publicar una IPA incompleta.
- El ZIP se usa como referencia de producto y de su patrón CI; sus pasos genéricos de build Simulator/IPA no sustituyen los pasos Rust/Airlift, `ldid` ni la configuración Xcode de V2.

## Qué no se copia

- No se añade `LocalDevVPN` como dependencia obligatoria: no es el túnel que V2 instala y administra.
- No se reemplazan el `Info.plist`, entitlements, bundle IDs, target Xcode, Worker, versiones ni recursos del V2 por los de SupportPatch.
- No se incorporan el exploit de kernel, sus puentes FFI, el reemplazo de archivos de otras apps ni los módulos de patching de SupportPatch: son funciones ajenas a las intenciones VPN/build de V2 y requieren revisión independiente de compatibilidad y procedencia.

## Validación

La comprobación de estructura VPN se ejecuta en macOS dentro de GitHub Actions tras el build y antes de crear la IPA. La compilación/signatura final de iOS no puede validarse en este sandbox Linux; el resultado debe confirmarse en la ejecución del workflow.
