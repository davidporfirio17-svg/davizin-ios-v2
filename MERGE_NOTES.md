# Nyxel External 1.3 Fixed

## Cambio aplicado

Se tomó el repositorio V2 como base porque contiene la política de compatibilidad usada por la IPA y el flujo de validación de build que espera el Worker `dz`.

La política de inyección ahora acepta iOS/iPadOS 26.6.2 mediante `NyxelSupportPolicy.swift`. Se conserva el `CFBundleVersion` en `2`, porque el Worker desplegado utiliza el build `2` como build autorizado. La versión visible (`CFBundleShortVersionString`) se actualizó a `1.3`.

No fue necesario modificar el Worker: el cliente V2 ya envía `app_version` y `app_build`, y el Worker autoriza el build `2`.

## Verificación

- `git diff --check`: correcto.
- `NyxelSupportPolicy.swift` está incluido en la fase de compilación de Xcode.
- `MinimumOSVersion`: 16.0.
- Rango de política iOS 26: 26.0–26.6.2.
- Build de app conservado: 2.

## Nota sobre la IPA

Este entorno no incluye Xcode ni el SDK de iOS, por lo que aquí no se puede producir una IPA firmada. El ZIP contiene el proyecto fuente listo para abrirse en Xcode, compilarse y firmarse con el mismo entorno que produjo la IPA original.
