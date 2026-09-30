# Spec 011: pruebas en el dispositivo

Guía y resultados de la verificación con `adb` (plan §5). Todo en el **emulador de Android 16 (API 37)**; nunca en el Xiaomi sin permiso del propietario. Las capturas están en `capturas/` (reducidas; solo las tareas de prueba "uno" y "dos", sin datos privados).

## 0. Cómo se usa el script

```bash
# El serial es obligatorio. Un serial que no sea "emulator-*" exige ALLOW_PHYSICAL=1
# (solo con permiso explícito del propietario).
S=emulator-5554
tools/check-recents.sh $S capture uno /tmp/x      # con la tarea A ("uno") en pantalla
# (cambiar a la tarea B, "dos", y repetir)
tools/check-recents.sh $S capture dos /tmp/x
tools/check-recents.sh $S compare uno dos /tmp/x  # CA-011-01: falla si enseña contenido o A y B difieren
tools/check-recents.sh $S secure                  # CA-011-04: sin FLAG_SECURE con la app delante
tools/check-recents.sh $S loop 10 /tmp/x          # CA-011-08 (sin cámara ni selector)
tools/check-recents.sh $S record 10 /tmp/x        # parpadeo (CA-011-03), con tiras de fotogramas
```

- Necesita `adb` (variable `ADB`, `PATH` o el SDK en `~/Library/Android/sdk`) y `python3` con Pillow y numpy (solo herramienta local; no es una dependencia del proyecto).
- **Dos rutas para abrir "Recientes"** (hallazgo de T-011-01, §2): por defecto el script pasa antes por el escritorio (`KEYCODE_HOME` y luego `KEYCODE_APP_SWITCH`); con `VIA=direct` lo abre desde la propia app.
- "Parecido" es la correlación entre la pantalla y la tarjeta de "Recientes" (0,96 con el contenido visible; ≈ 0 sin él). Umbral: 0,5. Las tarjetas de A y B se comparan píxel a píxel dentro de la tarjeta (tolerancia 0,1 % de píxeles).
- Limitación conocida del script: `record` usa `screenrecord --output-format=raw-frames`, que no da tiempos y solo emite fotogramas cuando la pantalla cambia; detecta que hay un fotograma liso blanco o negro, pero no cuánto dura. Los tiempos de §3 salen de un `screenrecord` a mp4 leído con `AVAssetReader` (script de un solo uso, no incluido).

## 1. Estado de partida (T-011-01 a)

Compilación *release* de `main` (sin `RecentsPrivacy`), tareas "uno" y "dos", emulador API 37.

- [x] **Hoy "Recientes" enseña el contenido.** `capturas/partida-escritorio-uno.png` y `partida-escritorio-dos.png` (por el escritorio) y `partida-directo-uno.png` (directo): se ve el logotipo, el menú, "uno" y el botón.
- [x] **El script falla en este estado** (código de salida 1):

```
[uno] la tarjeta ... FALLO CA-011-01: la tarjeta de 'uno' enseña el contenido (parecido 0.959 con la pantalla)
FALLO CA-011-01: la tarjeta de 'dos' enseña el contenido (parecido 0.960 con la pantalla)
FALLO CA-011-01: las tarjetas de uno y dos difieren (píxeles distintos: 0.00325)
```

- [x] Con la app delante: sin `FLAG_SECURE` y captura con contenido (CA-011-04 hoy se cumple).
- [x] Sin parpadeo hoy: 4 vueltas de `record`, ningún fotograma liso (`capturas/partida-vuelta-tira.png`) y ningún fotograma liso en 5 vueltas grabadas a mp4.

## 2. Mecanismos probados en API 37 (T-011-01 c)

Mismo `RecentsPrivacy.kt` provisional con una constante (`A`: `setRecentsScreenshotEnabled(false)` en `onCreate`; `B`: `FLAG_SECURE` en `onPause` y fuera en `onResume`; `none`: nada). Compilación *release*.

| Comprobación | Partida (`none`) | A (Android 13+) | B (`FLAG_SECURE` al pausar) |
|---|---|---|---|
| **Escritorio → "Recientes"**: tarjeta con contenido | Sí (0,96) | **No (≈ 0)**; fondo blanco con franja negra arriba (`A-escritorio-*.png`) | **No (≈ 0)**; igual que A (`B-escritorio-*.png`) |
| Tarjetas de A y B idénticas | No | **Sí** (0,05 % de píxeles) | **Sí** (0 %) |
| **Desde la propia app → "Recientes"** (`VIA=direct`) | Contenido | **Contenido (0,96)** (`A-directo-uno.png`) | **Contenido (0,96)** (`B-directo-uno.png`) |
| `FLAG_SECURE` con la app delante | No | No | No |
| Captura (`screencap`) con la app delante y tras volver | Con contenido | Con contenido | Con contenido |
| **Fotograma blanco liso al volver desde "Recientes"** (CA-011-03) | **No** (0 de 9 vueltas) | **Sí**: 2 de 4 vueltas con `raw-frames` y 2 de 5 con mp4 | **Sí**: 3 de 5 vueltas con `raw-frames` y 2 de 5 con mp4 |
| `screenrecord` de la app en segundo plano | Contenido | Blanco | Negro (la ventana es segura mientras dura la pausa) |

Lecturas:

1. **Los dos mecanismos ocultan la instantánea** cuando la app se ha ido al segundo plano de verdad (por el escritorio). Se ve lo mismo con A y con B: la tarjeta en blanco que pinta el sistema.
2. **Ninguno de los dos oculta la tarjeta cuando "Recientes" se abre desde la propia app** (deslizar hacia arriba con la app delante). Ahí el lanzador enseña la ventana **en vivo** de la app y la actividad **no llega a pausarse** (no hay `wm_pause_activity` de la app; el lanzador es el único en `ResumedActivity` del sistema pero la app conserva el `topResumedActivity` de su tarea). `setRecentsScreenshotEnabled` solo actúa sobre la instantánea y `FLAG_SECURE` en `onPause` llega tarde. **[Hecho]** para API 37; **[Suposición]** que en Android 13–16 es igual (transición "transitoria" de "Recientes"). Es lo que hace hoy "Recientes" con cualquier app; la instantánea queda oculta en cuanto se cambia de app.
3. **Al volver desde "Recientes" se ve un fotograma blanco a pantalla completa** con la instantánea vacía, antes de que la app se dibuje (`A-vuelta-tira.png`, `B-vuelta-tira.png`: el fotograma liso, entre "Recientes" y la app). Con la app sin ocultar no ocurre. Con mp4 el fotograma blanco dura ≈ 1,0–1,1 s en las dos vueltas en que se ve (13,504 → 14,610 s y 30,191 → 31,181 s en A); **[Suposición]** el valor está inflado por la carga de la grabación en el emulador. El blanco coincide con el `windowBackground` del `LaunchTheme` (`launch_background.xml`: blanco): **[Suposición]** es lo que el sistema pinta cuando no hay instantánea.
4. Con B, `dumpsys window` marca `SECURE` solo con la app detrás (por el escritorio) y nunca delante.

### Decisión (regla de desempate de la spec) — **PARO, se pregunta al propietario**

- **Los dos mecanismos incumplen CA-011-03** en Android 16 (fotograma blanco al volver desde "Recientes"), y la spec dice: *"Si el sistema enseña un instante su propio fondo o la pantalla de arranque en Android 13+, se para y se pregunta."* No se ha cambiado la spec ni se ha "arreglado" el parpadeo.
- Entre los dos, **A y B se comportan igual** en lo medido (ocultan por el escritorio, no ocultan en directo, dejan un fotograma blanco). **Recomendación técnica si el propietario acepta el blanco:** **A en Android 13+ y B en 8–12** (como dice el plan §1): A no toca la ventana, así que no puede interferir con capturas, con la lupa ni con la vista web (R-4), y no hay que sincronizarla con `onPause`/`onResume`.
- Opciones que se pueden explorar (necesitan decisión del propietario o de diseño; no se han hecho): (a) **fondo del `LaunchTheme` en un color neutro del diseño** en lugar de blanco (el fondo de cada tarea varía: amarillo, rosa, verde…, así que seguiría habiendo un cambio de color, pero menos brusco); (b) aceptar el fotograma con una nota de la beta; (c) mecanismo distinto (no probado).
- **Pregunta abierta sobre el CA-011-01:** la spec dice *"la app en segundo plano y abre 'Recientes'"*. Con la ruta directa (desde la app) el CA no se puede cumplir con ninguno de los dos mecanismos (punto 2). **Recomendación:** que el CA se verifique por el escritorio (o desde otra app), que es cuando existe la instantánea, y que se anote el resto como comportamiento del sistema.

## 3. Matriz, vueltas y casos límite (T-011-03) — pendiente

Se hace tras T-011-02 con el mecanismo que decida el propietario.

## 4. Estado en que queda el árbol

- `app/android/app/src/main/kotlin/invalid/pending/app/RecentsPrivacy.kt` es **PROVISIONAL** (constante `MODE`, dejada en `"A"`). T-011-02 **debe sustituirlo** por la versión final, sin `MODE`, con el mecanismo decidido y B para `SDK_INT < 33`.
- `MainActivity.kt` ya llama a `RecentsPrivacy` en `onCreate`, `onPause` y `onResume`; esa parte es la definitiva.
- El emulador se ha dejado con la compilación *release* de A instalada y las tareas de prueba borradas o completadas (datos de desarrollo).
