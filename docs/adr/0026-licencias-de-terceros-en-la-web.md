# ADR-0026: Licencias de terceros solo en una web: se retiran las pantallas de la app, los textos siguen dentro del paquete y el archivo de avisos se genera del APK que se comprueba

- **Estado:** Aceptado (propietario, 2026-10-05, con la spec 015); la parte "los textos siguen dentro del paquete" enmienda CA-015-14a (hecho en la spec)
- **Fecha:** 2026-10-05
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** spec 015 (CA-015-12 a 14b, §9), spec 012 (CA-012-01 a 03, que se sustituyen); D26, D27 y R-27 en `docs/PLAN.md`; constitución P3 y P4 (y 1.7); `docs/security/threat-model.md` §5 (T-4, T-13); ADR-0009 (landing); ADR-0023 (misma subida de la constitución); PD-2 (dominio)

## Contexto

- **[Hecho]** Hoy (spec 012) la app muestra dentro una lista de licencias de código abierto y el texto de cada una (`LicensesScreen`, `LicenseDetailScreen`, `licensesProvider`, `FlutterLicenseSource`, `license_names.dart`), sobre el `LicenseRegistry` de Flutter: el `NOTICES` del motor y de los paquetes de Dart, más lo que añade `registerBundledLicenses` (`assets/licenses/pdfium.txt`, `sqlite.txt` y `android.txt`, unos 155 KB sin comprimir) y el OFL de las dos fuentes (`assets/fonts/*/OFL.txt`).
- **[Hecho]** El propietario decidió el 2026-10-04 que las licencias de terceros vivan **en una web**, como la Política de privacidad y la Ayuda, y que se retiren las pantallas (D26, P-5, **contra la recomendación** que se le dio, que era mantenerlas dentro). Aceptó que sin conexión **no se ven** (P3) y que hay un riesgo de cumplimiento (spec 015, CA-015-14b). No consta otro motivo en los documentos.
- **[Hecho]** `tools/check-licenses.sh` (en CI, tras compilar) comprueba sobre el APK de release de cada ABI: los paquetes de Dart de release ⊆ `NOTICES.Z`; cada `lib/<abi>/*.so` tiene su entrada conocida; los artefactos de Android (`releaseRuntimeClasspath`) ⊆ `android.txt`; cada fuente lleva su OFL; los tres `assets/licenses/*.txt` van dentro del APK; y la línea de origen de `pdfium.txt` coincide con `tools/pdfium.lock`. Además `app/tool/check_licenses.dart` rechaza GPL/LGPL/AGPL/SSPL en `pubspec.lock` (esto no cambia).
- **[Hecho]** `NOTICES.Z` lo genera Flutter en cada compilación y va dentro del APK (el script lo lee de ahí). **[Suposición]** No se puede dejar fuera con una opción de compilación; el plan lo confirma.
- **[Hecho]** Lo que piden los textos que la app redistribuye (según los archivos del repositorio):
  - **OFL 1.1** (Archivo y Space Mono, `OFL.txt`): la redistribución es válida "siempre que **cada copia** contenga el aviso de copyright y esta licencia", que pueden ir en archivos de texto aparte o en los metadatos.
  - **BSD de tres cláusulas** (PDFium y partes del motor): las redistribuciones en forma binaria deben reproducir el aviso "en la documentación y/u otros materiales entregados con la distribución".
  - **Apache 2.0** (PDFium, las bibliotecas de Android): §4(a), dar a los demás receptores **una copia de la licencia**.
  - **SQLite**: dominio público, sin obligación (se incluye el texto por claridad).
- **[Suposición]** Una página web enlazada desde la app cuenta como "otros materiales" o como "dar una copia" para BSD y Apache. No es seguro y no hay revisión legal: **[Pendiente]** revisarlo antes de publicar (F6/023). Para la OFL, la frase "cada copia contenga" apunta a que el texto vaya **dentro** de lo que se distribuye, no solo enlazado. Esto no es asesoramiento jurídico.
- **[Hecho]** No existe `landing/` ni dominio (PD-2, ADR-0009): las tres direcciones son marcadores y la puerta de publicación impide publicar así (CA-015-13).
- **[Hecho]** Riesgo **R-27** del plan (Media/Media): "las licencias piden acompañar la distribución con sus avisos; sin conexión no se ven (P3)"; la mitigación prevista es que el archivo publicado se genere o compruebe desde el APK (`check-licenses.sh`).

## Opciones consideradas

1. **Mantener las pantallas dentro de la app** y añadir un enlace a la web (como recomendó Claude Code). El propietario la descartó (D26, P-5).
2. **Solo web, sin ningún texto de licencia en el paquete** (lectura literal de CA-015-14a: "el paquete no incluye los recursos que solo ellas usaban"): se retiran las pantallas y `assets/licenses/*`, y las licencias solo existen en la web.
3. **Solo web para verlas, pero los textos siguen dentro del paquete sin pantalla**: se retiran las pantallas y el código que las leía; `assets/licenses/*.txt` y los `OFL.txt` se quedan declarados en `pubspec.yaml` y nadie los muestra. `NOTICES.Z` va de todos modos. La web publica el archivo de avisos completo.

## Decisión

Opción 3: no hay ninguna pantalla de licencias en la app, las licencias se ven solo en la web de "Licencias de terceros", y los textos de licencia (`assets/licenses/*.txt`, los `OFL.txt` y el `NOTICES.Z` de Flutter) siguen dentro del paquete sin mostrarse. El **archivo de avisos** que se publica se genera, con la misma herramienta que lo comprueba, **del APK de release** que ha pasado `check-licenses.sh`, de modo que lo publicado es exactamente lo comprobado. Se revisa si la revisión legal concluye que la web no basta, si una tienda o un tester lo pide, si una dependencia exige mostrar su aviso dentro o si el propietario quiere verlas sin conexión.

## Motivos

Criterios (peso): respeta la decisión del propietario D26/P-5 (3), cumplimiento de las licencias (3), uso sin conexión / P3 (2), simplicidad y mantenimiento (2). Puntuación de 0 a 5; la de cumplimiento es mi valoración y descansa en **[Suposición]**, no en una revisión legal.

| Opción | D26 ×3 | Cumplimiento ×3 | Sin conexión ×2 | Simplicidad ×2 | Total |
|---|---|---|---|---|---|
| 1. Pantallas en la app + enlace | 0 → 0 | 5 → 15 | 5 → 10 | 2 → 4 | **29** |
| 2. Solo web, nada en el paquete | 5 → 15 | 1 → 3 | 1 → 2 | 4 → 8 | **28** |
| 3. Solo web, textos dentro sin pantalla | 4 → 12 | 3 → 9 | 1 → 2 | 4 → 8 | **31** |

- **Opción 1:** la mejor para el cumplimiento y para P3, pero es lo que el propietario rechazó; se conserva el código de 012 y 013 (pantallas, *goldens*, deuda de accesibilidad). La matriz le da 0 en D26 por eso.
- **Opción 2:** la más limpia, pero **deja sin su licencia las copias de las fuentes** (OFL) y de PDFium y las bibliotecas de Android (Apache), que viajan dentro del APK. El ahorro es de unos 155 KB más los OFL; el riesgo, de ser el distribuidor que no acompaña lo que redistribuye.
- **Opción 3:** respeta lo esencial de D26 (nada en la app, todo en la web) y se queda con la protección más barata: los textos dentro del paquete **no cuestan código ni pantallas**, solo el espacio de archivos que ya están. `check-licenses.sh` sigue comprobando lo que ya comprueba (los tres `.txt` y los OFL dentro del APK) y casi no cambia. La diferencia con la spec es una frase: CA-015-14a decía que el paquete no incluye esos recursos; aquí se quedan, **sin leerse**.
- **Cómo se genera el archivo de avisos:** `check-licenses.sh` ya descomprime `NOTICES.Z` del APK, lista los paquetes de Dart, las `.so`, los artefactos de Android y las fuentes. Con lo mismo se emite un `third-party-notices.txt` (cabecera con versión y fecha; luego `NOTICES.Z` descomprimido, los tres `.txt` y los OFL) y se comprueba **sobre el archivo emitido** que tiene una entrada por cada paquete, `.so`, artefacto y fuente (CA-015-14b). Así no hay dos listas que se puedan desfasar. **[Suposición]** Nombre, formato (texto plano) y dónde lo deja CI (artefacto de la ejecución, sin añadirlo al repositorio) los decide el plan.

## Consecuencias

- **Positivas:**
  - Se cumple D26: se retiran `LicensesScreen`, `LicenseDetailScreen`, `licensesProvider`, `FlutterLicenseSource`, `LicenseSource`, `LicensePackage`, `license_names.dart`, `registerBundledLicenses`/`bundled_licenses.dart`, sus *goldens*, sus tests y las cadenas `settingsLicenses`, `licensesTitle`, `licensesLoading`, `licensesCount`, `licensesError`, `licensesTextOf` y `licensesAndroidLibraries` (si nada más las usa, lo comprueba el plan). Deja de existir la deuda de accesibilidad de esas pantallas (CA-013-01/02).
  - Sin dependencias, permisos ni esquema nuevos; sigue sin haber red hecha por la app: quien abre la web es el navegador, tras la confirmación de enlace (CA-015-12).
  - Lo publicado en la web es lo comprobado, versión a versión.
- **Negativas y su mitigación:**
  - **P3: sin conexión no se ven las licencias** (ni la política ni la ayuda). Aceptado por el propietario. Mitigación: los textos van dentro del paquete (opción 3), aunque no se muestren. Se anota en P3 (constitución 1.7).
  - **Riesgo de cumplimiento (R-27, Media/Media):** que una web enlazada no cuente como acompañar la distribución. Mitigaciones: (a) los textos siguen dentro del paquete, que es lo que más protege con las fuentes (OFL); (b) la puerta de publicación impide publicar con una dirección marcador (CA-015-13), así que la app no sale sin la web; (c) `/release-checklist` añade "la web de licencias publica el archivo de **esta** versión"; (d) **[Pendiente]** una revisión legal antes de F6. Si concluye que no basta, se restituye la pantalla (el código de la 012 está en el historial, PR svallev/una#22) en una spec nueva.
  - **Web caída o dominio caducado:** las licencias dejan de verse. Mitigación: el archivo vive también en cada paquete y se regenera en cada versión.
  - **Contradice la letra de CA-015-14a** ("el paquete no incluye los recursos"): hay que enmendar la spec al aceptar este ADR (abajo).
  - **Sin ahorro de tamaño** por los textos (unos 155 KB sin comprimir más los OFL).
- **Riesgos para `docs/PLAN.md`:** R-27 se actualiza con estas mitigaciones y con la revisión legal como pendiente (no es un riesgo nuevo). Se propone anotar la revisión legal en los pendientes de F6/023.
- **Qué hay que hacer al aceptarlo:**
  - **Spec 015:** CA-015-14a pasa a decir que no hay pantalla de licencias y que los textos **siguen** dentro del paquete sin mostrarse; CA-015-14b, a que el archivo se emite del APK comprobado; el §7 (cadenas) y el anexo (los assets de `bundled_licenses` **siguen declarados**; solo se retira el código que los leía).
  - **Spec 012:** pasa a "Sustituida por la spec 015" al implementar la 015; CA-012-03 y las pantallas de licencias, retiradas.
  - **`specs/constitution.md` 1.7** (una sola subida junto con el ADR-0023): nota en P3: "la política de privacidad, las licencias de terceros y la ayuda necesitan conexión: viven en una web que abre el navegador ([ADR-0026](../docs/adr/0026-licencias-de-terceros-en-la-web.md)); los textos de licencia siguen dentro del paquete".
  - **`tools/check-licenses.sh`** (emite y comprueba el archivo) y su paso en `.github/workflows/ci.yml` (nombre y, quizá, subir el archivo); **`docs/security/threat-model.md`** (T-4, T-13 y §5), **`docs/security/checklist.md`** (la sección "muestra licencias y política" se reduce al enlace), **`docs/testing.md`**, **`docs/legal/privacy-policy.md`** si cita las licencias, y **`.claude/skills/release-checklist/SKILL.md`**.
  - `docs/PLAN.md` (R-27, pendiente de revisión legal) y `docs/adr/README.md`.
- **Qué dispararía revisarlo:** los criterios de la decisión.
