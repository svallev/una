# Icono de la app

Spec 018 (`specs/018-iconos/`), D29 («hechos a mano y sin dependencias»), DEV-55. Tablero 17 del prototipo («Icono de la app»).

**Qué es:** la «u.» (la letra y el punto) en `#111111` sobre un fondo liso `#FFE55C`. **No** es el logotipo «una.» de la primera pantalla (`wordmark`, `identity.yaml`), que no cambia. El nombre bajo el icono sale de `identity.yaml` (`displayName`); el icono no tiene texto traducible.

## 1. Fuente única

Todas las versiones salen de los PNG del tablero 17 copiados en `design/prototype/assets/icon/` (ver `docs/design/screen-map.md`, «Imágenes del icono»):

| Archivo | Papel |
|---|---|
| `icon-1024.png` | **El original.** 1024 × 1024, RGB, sin transparencia. Base de Play 512 y de la web; fuente de iOS cuando toque (F-iOS, fuera de la 018) |
| `adaptive-foreground-432.png` | **Capa de origen** del primer plano del icono adaptable: 432 × 432 (= 108 dp × 4), RGBA, solo tinta `#111111` y alfa |
| `adaptive-monochrome-432.png` | Referencia de la capa con tema; **no se usa** (ver §5) |
| `themed-preview-432.png` | Vista previa azul del tablero; no se usa |

Los colores salen de `design/tokens.json`, no de los PNG: el fondo es **`palette.classic.0`** (`#FFE55C`, fijo aunque cambie la paleta activa: el icono no es una nota) y la «u.» es **`color.ink`** (`#111111`). Contraste ≈ 14,9 : 1.

## 2. Geometría (la que miden los tests)

Un icono adaptable de Android es un lienzo de **108 dp** (aquí, 432 px) con fondo y primer plano. El lanzador lo recorta con su máscara (círculo, *squircle*, gota…), así que solo se ve un **círculo central de 72 dp** y el dibujo debe caber en la **zona segura**, un círculo de **66 dp** (a ≤ 33 dp del centro).

| Medida | Valor | Test |
|---|---|---|
| Ancho de la «u.» con el punto | **56 %** de la dimensión visible (tolerancia ± 1 punto porcentual) | `android_adaptive_icon_test.dart`, `icon_coherence_test.dart` (CA-018-01 y 10) |
| Caja de la figura en el primer plano de 432 | x 135–296 (162 px), y 164–267 (104 px): **40,5 dp = 56,25 % del círculo de 72 dp**, centrada en (216, 216) ± 1 dp | `android_adaptive_icon_test.dart` |
| Esquina más lejana de la «u.» (Android) | **≈ 24,1 dp** del centro, ≤ 33 dp | CA-018-02 |
| Original de 1024 | «u.» de 574 px de ancho = **56,05 %** del lado, x 225–798; altura 36 %; esquina más lejana a **33,3 %** del lado | `icon_coherence_test.dart`, `icon_image_support_test.dart` |
| Zona segura de un icono «maskable» (web) | círculo de radio el **40 %** del lado; la «u.» queda a ≈ 33 % ≤ 40 % | `web_icons_test.dart` (CA-018-09) |

**Dimensión visible** (el lado sobre el que se mide el 56 %): en Android es el círculo de 72 dp; en el original, Play y la web es el lado entero. Por eso el mismo dibujo vale en todas: en Android el primer plano ocupa la misma proporción de 72 dp (40,5 dp) que el original de su lado.

## 3. Cómo se hizo cada versión

Sin dependencias: ni `flutter_launcher_icons` ni el paquete `image`. Un generador propio, `app/tool/gen_icons.dart` (+ `app/tool/png_lite.dart`: lee PNG RGB/RGBA de 8 bits, reduce por promedio de áreas y escribe RGBA con `ZLibCodec`). Solo `dart:`; **no está en `lib/` ni se empaqueta**. Desde `app/`:

```bash
dart run tool/gen_icons.dart [android] [play] [web]   # sin objetivos, los tres
dart run tool/gen_icons.dart --check [objetivos]       # falla si algo no está al día
```

| Versión | Qué escribe | Qué se hace a mano |
|---|---|---|
| **Android** (`android`) | `android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png` (copia exacta del primer plano de 432; `nodpi` porque el sistema lo estira a los 108 dp) y `res/values/ic_launcher_background.xml` (`<color>` del token, cabecera «GENERADO») | `res/mipmap-anydpi/ic_launcher.xml` (`<adaptive-icon>`: fondo, primer plano y `<monochrome>`; sin sufijo `-v26` porque `minSdk` = 26). El manifiesto no cambia: `android:icon="@mipmap/ic_launcher"` |
| **Con tema** (Android 13+) | Nada: es el mismo drawable (§5) | La línea `<monochrome>` del XML |
| **Google Play** (`play`) | `store/google-play/icon-512.png` (raíz del repo, fuera de `app/`): el original de 1024 reducido a 512 por promedio 2 × 2, RGBA con alfa 255, a sangre, sin esquinas redondeadas ni sombra. **No se empaqueta** | — |
| **Web de pruebas** (`web`) | `app/web/favicon.png` (32), `icons/Icon-192.png`, `Icon-512.png` y los dos `Icon-maskable-*` (iguales a los anteriores: el original a sangre ya cabe en la zona segura) | `manifest.json` (`theme_color` y `background_color` = `#FFE55C`, sin `description`) e `index.html` (sin `<meta name="description">`) |

Las compilaciones `debug`, `profile` y `release` llevan el mismo icono (no hay recursos en `src/debug` ni `src/profile`). **iOS queda fuera** (D17, sin Xcode): `ios/Runner/Assets.xcassets/AppIcon.appiconset` sigue siendo el de la plantilla; la fuente para F-iOS es `icon-1024.png`.

## 4. Qué rehacer si cambia el nombre (CL-018-7)

La «u.» es un **dibujo**, no un texto de la app: cambiar `displayName` o el `wordmark` **no actualiza el icono**. Para rehacerlo:

1. Dibujar el nuevo original en el prototipo (tablero 17) y exportar los PNG a `design/prototype/assets/icon/` con los mismos nombres: `icon-1024.png` (RGB, solo `ink` y `palette.classic.0` más el suavizado) y `adaptive-foreground-432.png` (RGBA, solo tinta y alfa, figura a ≤ 33 dp del centro).
2. `dart run tool/gen_icons.dart` (los tres objetivos) desde `app/`; confirmar con `--check`.
3. `flutter test test/icon test/tool/gen_icons_test.dart`: los tests miden el resultado (56 % ± 1 pp, caja centrada, 33 dp, solo los colores de los tokens, dos piezas). Si el dibujo nuevo tiene otra proporción, se cambia **a la vez** el 56 % de la spec 018 (CA-018-01 y 10), los tests y este documento.
4. Revisar la ficha de Google Play (`store/google-play/icon-512.png`) y la spec 023 antes de F6, y el icono de iOS cuando toque F-iOS.

Los lanzadores pueden guardar el icono viejo en caché hasta reiniciarse o reinstalar (CL-018-6).

## 5. Capa con tema compartida (P-018-2)

La capa `<monochrome>` es **el mismo drawable que el primer plano**, no el `adaptive-monochrome-432.png` del tablero. Medido el 2026-10-10: ese PNG difiere del primer plano en 22 píxeles de borde por 1/255 de alfa, y CA-018-04 exige alfa idéntica píxel a píxel. El sistema tiñe solo con el alfa y el primer plano es tinta maciza (alfa 255 dentro de la «u.» y del punto), así que compartir el recurso lo cumple por construcción y quita un PNG. El PNG del tablero queda en `design/` solo como referencia. La capa con tema es entonces la «u.» con su punto, completa y del mismo tamaño y posición (`icon_coherence_test.dart`: el XML apunta al mismo recurso). El icono pequeño de las notificaciones (spec 019) puede reutilizarla.

## 6. Dónde se vigila

| Qué | Test |
|---|---|
| Android: geometría, colores, capa con tema, ≥ 432 px | `test/icon/android_adaptive_icon_test.dart` |
| Android: manifiesto, sin iconos de plantilla, nombre desde la identidad, sin recursos en `debug`/`profile` | `test/icon/android_icon_packaging_test.dart` |
| Play: RGBA, 512, < 1024 KB, alfa 255, igual al original reducido, no empaquetado | `test/icon/play_icon_test.dart` |
| Web: tamaños, esquinas, «maskable», manifiesto sin texto de plantilla | `test/icon/web_icons_test.dart` |
| **Las cuatro versiones son un solo dibujo** (56 %, centrada, mismos colores, dos piezas, misma silueta) | `test/icon/icon_coherence_test.dart` |
| El generador está al día y se comporta | `test/tool/gen_icons_test.dart`, `dart run tool/gen_icons.dart --check` |

Apariencia con máscaras reales, iconos con tema y arranque: `specs/018-iconos/dispositivo.md`.
