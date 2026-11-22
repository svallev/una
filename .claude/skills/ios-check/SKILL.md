---
name: ios-check
description: Verificación común de iOS (spec 028, plan §1.2) - compila para el simulador, pasa XCTest, los tests de integración que se le pidan, tools/check-ios-parity.sh y analyze+test de Dart, y resume el resultado en una tabla. Úsala al terminar cualquier tarea de la 028 (y de iOS en general). Nunca firma ni hace push.
argument-hint: "[todos | <archivo_it>...] [--device <id>]"
---

# /ios-check

Receta fija, **desde `app/`** (sin FVM: `flutter`/`dart` del sistema). No se deriva ningún comando por tarea: si falta algo, se arregla aquí.

Argumentos: sin ellos, ningún test de integración; `todos` = los 20 de `app/integration_test/` (los `*_perf_test` llevan su `skip:` en el simulador, `plan.md` §1.3); una lista de archivos (`settings_flow_test.dart …`) = solo esos. `--device <id>` elige otro simulador.

## 0. El simulador

- El primero que salga de `xcrun simctl list devices available` con «iPhone» (hoy iPhone 18 Pro, iOS 27.2):
  `SIM=$(xcrun simctl list devices available | grep -m1 'iPhone' | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')`
- Arrancarlo si está apagado: `xcrun simctl boot "$SIM"` (si ya está arrancado, el error «current state: Booted» es inofensivo) y `xcrun simctl bootstatus "$SIM" -b`.
- **El certificado de pruebas NO debe ser de confianza en el simulador** (T-028-17): `web_flow_test` comprueba que el certificado autofirmado de `integration_test/fixtures/selfsigned_tls.dart` **se rechaza** (CA-009-10), y los IT de redirecciones (`web_redirect_test`) van en http y no lo necesitan. Si alguna vez se añadió con `simctl keychain add-root-cert` (esta receta lo pedía hasta T-028-17), `simctl keychain reset` **no** lo quita: se borra del almacén de confianza con el simulador apagado:
  ```
  xcrun simctl shutdown "$SIM"
  sqlite3 ~/Library/Developer/CoreSimulator/Devices/$SIM/data/private/var/protected/trustd/private/TrustStore.sqlite3 \
    "delete from tsettings where hex(sha256)='5E2C9482F58A903160334493E92D79F96F8BA34070A05F45E4F26C7E79C11746';"
  xcrun simctl boot "$SIM"
  ```
  (la suma es la del certificado de pruebas en DER: `openssl x509 -outform DER | shasum -a 256`).

## 1. Pasos

| # | Paso | Comando (desde `app/`) |
|---|---|---|
| 1 | Compilar para el simulador | `flutter build ios --simulator --debug` |
| 2 | XCTest | `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination "platform=iOS Simulator,id=$SIM"` |
| 3 | Integración (solo si se pidieron) | `flutter test integration_test/<archivo> -d "$SIM"` (uno por llamada; `todos` = los 20) |
| 4 | Paridad | `bash ../tools/check-ios-parity.sh` |
| 5 | Dart | `dart format lib test integration_test --set-exit-if-changed`, `flutter analyze --fatal-infos` y `flutter test` |

- El paso 2 usa el esquema `Runner` (lleva `RunnerTests`, `Runner.xcscheme`). Si falla por «no signing»/firma, el destino es el simulador: no se toca la firma; se mira que `-destination` apunte a un simulador.
- El paso 4 corre las secciones **activas** de `tools/ios-parity.sections` y lista las demás como `PENDIENTE`; una tarea que activa una sección la comprueba también con `--section <nombre>`.
- Se sigue aunque un paso falle (se ve todo de una vez), pero **el resultado global es rojo** si falla cualquiera.
- `flutter test integration_test/x.dart -d "$SIM"` deja la app de pruebas instalada en el simulador; es de usar y tirar.

## 2. Resultado

Una tabla `paso · verde/rojo · tiempo` (y, si es rojo, las primeras líneas del error del paso, no el registro entero). Termina diciendo qué secciones del script están activas y cuáles `PENDIENTE`.

## Nunca

- `git push`, firmar, tocar `Runner.xcodeproj` para quitar la firma, ni usar un iPad o iPhone **físico** (el iPad es de la sesión coordinadora, con el propietario; `plan-f-ios.md`).
- Instalar nada de fuera: ni *pods* nuevos ni herramientas (P11).
- Dar un verde con un paso saltado: si el paso 1 o 2 no se pudo ejecutar (sin Xcode, sin simulador), el resultado es **no verificado**, con el motivo.
