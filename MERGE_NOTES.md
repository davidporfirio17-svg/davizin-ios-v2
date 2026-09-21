# Nyxel External 1.3 Fixed

## Cambio aplicado

Se tomó el repositorio V2 como base porque contiene la política de compatibilidad usada por la IPA y el flujo de validación de build que espera el Worker `dz`.

La política de inyección ahora acepta iOS/iPadOS 26.6.2 mediante `NyxelSupportPolicy.swift`. La nueva IPA usa `CFBundleVersion` `3` y versión visible `1.4`; el Worker mantendrá el build anterior autorizado durante la transición y podrá revocarlo después de instalar la nueva IPA.

El cliente V2 ahora obtiene una sesión efímera del Worker y la envía en configuración, recursos y consumo. Los recursos nuevos se cifran con una clave derivada de esa sesión; se conserva temporalmente una ruta de compatibilidad para la IPA anterior mientras termina la migración.

## Verificación

- `git diff --check`: correcto.
- `NyxelSupportPolicy.swift` está incluido en la fase de compilación de Xcode.
- `MinimumOSVersion`: 16.0.
- Rango de política iOS 26: 26.0–26.6.2.
- Build de app nuevo: 3.
- El nombre del proyecto fue renombrado consistentemente a `Davizin` en archivos y símbolos.
- No se pudo compilar una IPA firmada en este entorno; GitHub Actions genera una IPA unsigned para firmar externamente.

## Nota sobre la IPA

Este entorno no incluye Xcode ni el SDK de iOS, por lo que aquí no se puede producir una IPA firmada. El ZIP contiene el proyecto fuente listo para abrirse en Xcode, compilarse y firmarse con el mismo entorno que produjo la IPA original.
