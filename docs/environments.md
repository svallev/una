# Entornos de desarrollo, pruebas y publicación

## 1. Preparar el Mac (F0)

**[Hecho, 2026-09-24]** macOS 26.6 en Apple Silicon; Xcode **no** instalado (solo las Command Line Tools); sin Homebrew, `gh` ni Flutter; Node 24 (nvm); **30 GB libres**.

**Estado actualizado (2026-09-24, D17 Android primero):** 72 GB libres ✅ · Android Studio 2026.1 (JDK integrado OpenJDK 25) ✅ · SDK Platform 37, Build-Tools 36, Platform-Tools, Emulator y Command-line Tools ✅ · emulador `Pixel_6a` (Android 37.2, Google APIs Play Store, arm64-v8a, **páginas de 16 KB**) ✅ · **Xcode aplazado** hasta F-iOS (los pasos 2–3 de abajo se harán entonces).

1. **Liberar espacio:** objetivo ≥ 60 GB libres.
2. **Xcode, desde la Mac App Store** (oficial, firmado por Apple, no necesita el espacio extra de descomprimir un `.xip`). Basta un Apple ID gratuito. Desactiva **App Store → Ajustes → Actualizaciones automáticas** para que no cambie de versión a mitad del trabajo; actualiza cuando Flutter confirme la compatibilidad.
   - Alternativa para fijar una versión: el `.xip` oficial en developer.apple.com/download/all. No se usan herramientas de terceros (`xcodes`).
3. Tras instalarlo (lo ejecutas tú; piden contraseña):
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   xcodebuild -runFirstLaunch
   xcodebuild -downloadPlatform iOS
   ```
4. **Android Studio** (developer.android.com): SDK Platform 35+, Build-Tools, un emulador (p. ej. Pixel 6a, API 35) y **otro de API 26** para probar el mínimo.
5. **Homebrew** (opcional, oficial: brew.sh) para instalar `gh` y `fvm`. Alternativa sin Homebrew: los binarios oficiales de GitHub CLI.
6. **Flutter:** la versión la fija `.fvmrc` (3.47.5). Instalación sin herramientas de terceros, con el mismo script que CI y Vercel:
   ```bash
   FLUTTER_HOME="$HOME/development/flutter" bash tools/install-flutter.sh
   ```
   y añadir `$HOME/development/flutter/bin` al `PATH` (en `~/.zshrc`). Después: `flutter doctor` y `flutter doctor --android-licenses`. FVM es **opcional** (útil si algún día conviven varias versiones); los comandos de `CLAUDE.md` funcionan igual quitando el prefijo `fvm`.
   - **Java:** Android Studio trae OpenJDK 25. Si Gradle o algún plugin fallan con él, usar un JDK 21 solo para Flutter (`flutter config --jdk-dir <ruta>`).
   - **Emulador con GPU del Mac:** lanzarlo con `emulator -avd Pixel_6a -gpu host` (o en Android Studio: Device Manager → Edit → Graphics: Hardware). Con el modo automático puede acabar renderizando por software (lavapipe/SwANGLE) y cualquier animación va a 2–10 fps (ver `docs/spikes/F1-S1-S2-resultados.md`).
   - **Páginas de 16 KB:** el emulador usa páginas de 16 KB (obligatorio en Google Play para apps con `targetSdk` ≥ 35). Sirve para verificar que las librerías nativas (SQLite, PDFium, WebView) están alineadas.
7. **CocoaPods / Swift Package Manager:** según lo que exijan la versión de Flutter y los plugins (`flutter doctor` lo indica).

## 2. Ejecutar en local

| Destino | Comando (dentro de `app/`) | Notas |
|---|---|---|
| Simulador de iOS | `fvm flutter run -d "iPhone 17"` | No requiere cuenta |
| Emulador de Android | `fvm flutter run -d emulator-5554` | |
| iPhone físico | `fvm flutter run -d <id>` | Sin cuenta de pago: firma gratuita con tu Apple ID, **la app caduca a los 7 días**; activa el Modo desarrollador en el iPhone |
| Android físico | `fvm flutter run -d <id>` | Depuración USB; o instalar un APK |
| Navegador | `fvm flutter run -d chrome` | Web de pruebas (ADR-0010) |
| Rendimiento | `fvm flutter run --profile --trace-startup` | Siempre en dispositivo real |

## 3. Web de pruebas en Vercel (ADR-0010)

- Proyecto de Vercel conectado al repo, Root Directory `app/`, install `bash ../tools/install-flutter.sh`, build `flutter build web --release --wasm --no-web-resources-cdn`, output `build/web`.
- **Preview** por PR (con Deployment Protection) y **producción** desde `main`.
- Sin variables secretas: la web no tiene backend.
- Plan Hobby gratuito: suficiente para pruebas personales. **[Suposición]** Uso no comercial; si la app pasa a ser un producto de pago, revisar las condiciones del plan.

## 4. Pruebas en dispositivos reales y tiendas

| Canal | Requisito | Coste | Notas |
|---|---|---|---|
| **TestFlight** (iOS) | Apple Developer Program | **99 USD/año** | Hasta 100 testers internos; externos (hasta 10 000) tras una revisión ligera de la beta |
| **Internal testing** (Play) | Google Play Console | **25 USD** (pago único) | Hasta 100 testers; sin revisión |
| **Closed testing** (Play) | Ídem | — | **Cuentas personales nuevas: 12 testers durante 14 días seguidos** antes de poder publicar en producción (riesgo R-07) |
| APK directo | Nada | 0 | Solo para tus dispositivos |
| Compilación en la nube (opcional) | Codemagic / GitHub Actions en macOS | Capa gratuita limitada | No es necesaria: tienes Mac |

Verificación de identidad: ambas tiendas piden datos del desarrollador (y, en Google Play, dirección y teléfono visibles si la cuenta es de organización). **[Pendiente]** Decidir entre cuenta personal u organización (una organización requiere un número D-U-N-S).

## 5. Firma

Ver `docs/security/threat-model.md §6`. Resumen: Play App Signing; *upload key* fuera del repo; certificados de Apple en el llavero. **Nunca** en el repo ni en CI de PR.

## 6. CI (GitHub Actions)

Repositorio público → minutos de Actions gratuitos, también en macOS. Workflows: `ci.yml` (calidad y builds) y `security.yml` (CodeQL, OSV-Scanner, dependency-review). Secret scanning con push protection: nativo de GitHub (Settings → Code security). Detalle en `.github/workflows/`.
