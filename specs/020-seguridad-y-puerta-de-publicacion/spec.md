# Spec 020: Seguridad y puerta de publicación

- **Estado:** **Aprobada** por el propietario el 2026-10-14 («aprobada»; Q-020-1, 2, 4 y 5 respondidas: sí, sí, sí y no, §9). Antes **Borrador** (2026-10-13). Alcance decidido por el propietario el 2026-10-13 en la ronda de preguntas de `/spec-new 020`: **1c** (puerta y herramientas, los hallazgos bajos que tocan código de la app y las pruebas MASTG), **2 sí** (un trabajo de publicación aparte, estricto con una etiqueta `v*` y en modo «entrega a testers» cuando se lanza a mano), **3 sí** (las marcas de la política bloquean en modo estricto) y **4** (pantallas grandes, R-25/PD-11, en la 022). Revisada por `spec-reviewer` el 2026-10-14: 2 bloqueantes (la entrega a testers frente a lo comprobado y el *package name* provisional fuera de la puerta), 19 importantes y varios menores, **aplicados**.
- **Fase:** F5 Endurecimiento. Es la primera de las specs 020–023 (D30) y empieza al terminar F4b (la 019 se fusionó el 2026-10-13, PR #50). Tamaño **L**.
- **Reglas de producto:** ninguna regla R nueva. Desarrolla **P4** (privacidad por defecto), **P5** (seguridad desde el diseño, OWASP MASVS/MASTG) y **P11** (dependencias con criterio). Cierra lo que `docs/PLAN.md` deja «para la 020».
- **Pantallas del prototipo:** **sin diseño**. La spec no cambia ninguna pantalla, texto ni interacción de la app.
- **Decisiones y ADR relacionados:**
  - **D27** (2026-10-04): las direcciones marcador de `identity.yaml`, y la puerta de publicación que impide publicar con ellas.
  - **D2** (sin cuenta de Google Play todavía) y **D17** (Android primero; sin iOS).
  - **D14** (las copias de seguridad del sistema están incluidas): la pasada MASTG comprueba qué entra en ellas y qué no, sin cambiar la decisión.
  - **ADR-0004** (copias de seguridad), **ADR-0005** (almacenamiento), **ADR-0016/0017/0018** (la tarea web), **ADR-0019** («Recientes»), **ADR-0024** (grupos de fotos), **ADR-0025** (notificaciones) y **ADR-0026** (licencias en la web): la spec los comprueba y no los cambia.
  - **[Suposición]** No hace falta un ADR nuevo ni subir la constitución (sigue en la 1.10): no hay ninguna excepción a ningún principio. Si el plan cambia cómo se firma, se publica o se ejecuta la CI más allá de lo que dice esta spec, abre su ADR.
- **Hallazgos de origen** (todos de `docs/PLAN.md`):
  - De la 015: **M-1**, **B-2**, **B-3**, **M8** de `spec-reviewer`, **B-4**, **B-5** y **B-6**.
  - De la 012: **012-S3**, **012-S4** y **012-S6**.
  - De la 016: el **(c)** de seguridad de su cierre.
  - De la 018: los bajos **(1)** y **(2)** de seguridad de su cierre.
  - De la 019: el **(e)** de su cierre, los bajos **(a)** y **(d)** de su implementación y «la puerta de la 020» (fila F5, T-019-16).
  - De la 014: el **S2** de `security-reviewer` (declarado fuera de alcance, §8).
  - Del modelo de amenazas: **§8**, las «pruebas MASTG seleccionadas antes de la v1.0».
- **Dependencias:** 001–019 en `main`. Sin esquema de BD nuevo, sin permisos ni componentes nuevos y sin dependencias de ejecución nuevas (CA-020-25).
- **Nomenclatura:**
  - **Puerta de publicación:** ya está en el glosario (specs 012 y 015). Esta spec la amplía: pasa a ser **el trabajo de publicación entero**, no solo el script de la identidad y de la política.
  - **Trabajo de publicación:** el proceso automático, aparte de la CI de las PR, que compila la versión que se entregaría y pasa todas las comprobaciones sobre ella. Corre en dos **modos**:
    - **Modo estricto:** el que se usa para publicar. Se lanza con una etiqueta de versión `vX.Y.Z` y no admite ningún marcador.
    - **Modo «entrega a testers»** (o **modo testers**): se lanza a mano. Pasa las mismas comprobaciones, pero los **avisos de identidad** (CA-020-05) no lo paran: los lista.
  - **Puerta de la identidad:** el script de hoy (`tools/check-release-config.sh`), que valida `identity.yaml`, lo generado y la política. Es **una** de las comprobaciones del trabajo de publicación; donde esta spec dice «la puerta de la identidad» se refiere solo a él.
  - **Aviso de identidad:** un fallo que hoy es normal mientras no hay dominio (PD-2) ni cuenta de Play (PD-3). Son cinco: una dirección marcador, el *package name* provisional, un hueco o una marca de la política, la firma de depuración y, en modo testers, la falta de etiqueta. Es una lista **cerrada** (CA-020-05).
  - **Comprobación estática MASTG:** la que se hace sobre el paquete compilado, sin instalarlo. **Pasada MASTG:** la que se hace a mano en el emulador, con la app instalada, siguiendo una lista fija de pruebas de OWASP MASTG (CA-020-23).

> Esta spec describe **qué** y **por qué**. Al ser una spec de endurecimiento, nombra las comprobaciones y los archivos que ya existen para que cada criterio sea verificable. El **cómo** (scripts nuevos, pasos de CI, consultas) va en `plan.md`.

## 1. Objetivo

Que **nada se pueda publicar ni entregar a testers sin haber pasado, de forma automática y sobre el commit que se entrega, todas las comprobaciones de seguridad y privacidad del proyecto**. En F6, lo que se suba a Play será el AAB que compile este trabajo en modo estricto, nunca una compilación local (CA-020-06). Hoy la puerta de la identidad solo se pasa a mano en `/release-checklist` (M-1). También se cierran los hallazgos de seguridad bajos que quedaron abiertos en las specs 012–019 y se hace la verificación MASTG que el modelo de amenazas pide antes de la v1.0. Así, cuando lleguen el dominio (PD-2) y la cuenta de Play (PD-3), solo faltará la firma (F6).

## 2. Historias de usuario

- **HU-020-1** Como propietario, quiero que publicar una versión **falle sola** si lleva una dirección marcador, una política a medio escribir, un permiso de más o un paquete sin licencia, para no depender de acordarme de pasar la checklist a mano.
- **HU-020-2** Como propietario, quiero poder **comprobar el commit de una entrega a testers** antes de tener dominio y cuenta de Play, y que me diga qué le falta para publicar sin bloquearme, para poder empezar la beta (F6) cuanto antes.
- **HU-020-3** Como usuario, quiero que la app que instalo haya pasado las **pruebas de seguridad de referencia** (OWASP MASTG) y no guarde, registre ni exponga lo que pongo en mis tareas fuera de lo que ya conozco, para poder confiar en ella con fotos de documentos personales.
- **HU-020-4** Como propietario, quiero que los **hallazgos bajos** que dejé abiertos spec a spec queden cerrados o aceptados por escrito antes de la beta, para no llegar a las tiendas con deuda de seguridad sin revisar.

## 3. Criterios de aceptación

**Trazabilidad HU → CA**

| HU | Criterios |
|---|---|
| HU-020-1 | CA-020-01, 02, 03, 05, 07, 09 a 14 |
| HU-020-2 | CA-020-04, 05, 06 y 08 |
| HU-020-3 | CA-020-16 a 23, 27 y 28 |
| HU-020-4 | CA-020-15 a 21, 24, 27 y 28 |
| Transversales | CA-020-25 y 26 |

### A. El trabajo de publicación (M-1, 012-S3)

- **CA-020-01 Un trabajo aparte, que solo se lanza a propósito**
  - **Dado** el repositorio en GitHub
  - **Cuando** se mira qué lanza el trabajo de publicación
  - **Entonces**:
    - se lanza **solo** de dos formas: al subir una etiqueta `v*` (modo estricto) o a mano desde GitHub (modo testers). **Nunca** con una PR, con un *push* a una rama ni con un evento de un *fork*;
    - es un workflow **separado** de la CI de las PR (`ci.yml`), que sigue como está;
    - cumple las reglas de CI de `docs/security/checklist.md`: permisos mínimos (solo lectura del contenido y, si se usa CA-020-02 (0), lectura de las ejecuciones), acciones fijadas por SHA, sin `pull_request_target`, credenciales no persistidas en el *checkout* y **sin ningún secreto** (no hay firma hasta F6).
  - **Verificable:** un test o un *lint* del workflow comprueba los disparadores, los permisos, que las acciones van fijadas por SHA y que no se usa ningún secreto. La ejecución real de cada modo en GitHub solo es posible **después de fusionar** (el lanzamiento a mano exige el workflow en `main`, y el modo estricto, una etiqueta con permiso del propietario): se hace en la sesión de cierre o en una PR de documentación posterior, y hasta entonces la spec queda **Implementada parcialmente** (también para CA-020-04 y 06).

- **CA-020-02 Compila lo que se entregaría y lo comprueba todo**
  - **Dado** el trabajo de publicación lanzado en cualquiera de los dos modos
  - **Cuando** se ejecuta sobre un commit
  - **Entonces** compila desde ese commit, con el *lockfile* obligatorio y el Flutter verificado contra `tools/flutter-sdk.lock`, la versión de *release*: los APK por ABI y el **AAB**, que es lo que se subirá a Play. Pasa, como mínimo:
    0. **la CI y Security de ese commit en verde**: o bien comprueba que sus ejecuciones terminaron bien, o bien repite sus comprobaciones (formato, `analyze`, código generado al día, tests, pruebas JVM, licencias de los paquetes de pub, OSV-Scanner). El plan elige; un commit con la CI en rojo nunca sale en verde;
    1. la puerta de la identidad (`tools/check-release-config.sh`), con `gen_identity.dart --check` y las ampliaciones de CA-020-09 a 11;
    2. los textos nativos al día (`gen_android_strings.dart --check`);
    3. los permisos y la lista blanca de componentes del manifiesto combinado de *release* (`tools/check-android-permissions.sh release`, con CA-020-13);
    4. ninguna clase de pruebas en el paquete (`tools/check-apk-no-test-classes.sh`, sin `org/junit` ni `org/hamcrest`);
    5. PDFium fijado (`tools/check-pdfium.sh`);
    6. las licencias completas, con el archivo de avisos emitido y verificado (`tools/check-licenses.sh`) y su prueba negativa;
    7. el tamaño de descarga (< 25 MB comprimido por ABI);
    8. la comprobación estática MASTG (CA-020-22).

    Las comprobaciones 3, 4, 5 y 8 se pasan sobre los APK **y sobre el AAB**.

    Si cualquiera falla, el trabajo falla en los dos modos. La única excepción son los avisos de identidad en modo testers (CA-020-04 y 05). **Falla cerrada:** una comprobación que no llega a ejecutarse, se salta o termina con un código inesperado es un fallo en los dos modos, y el resumen enumera **todas** las comprobaciones con su resultado.
  - **Verificable:** la lista de pasos del workflow, frente a esta lista; y una ejecución con un fallo provocado en cada clase (CA-020-07).

- **CA-020-03 Modo estricto: con una etiqueta `vX.Y.Z`, ningún marcador**
  - **Dado** una etiqueta `vX.Y.Z` subida al repositorio
  - **Cuando** corre el trabajo en modo estricto
  - **Entonces** falla, además de por lo de CA-020-02, si:
    - (a) cualquiera de las tres direcciones de `identity.yaml` no sirve para publicar (marcador, dominio reservado, ruta no válida…);
    - (b) la política de privacidad tiene un hueco (`[NOMBRE DE LA APP]`…) o una **marca de documento** (CA-020-11);
    - (c) la etiqueta no tiene la forma `vX.Y.Z` (tres números) o **no coincide con la versión de `pubspec.yaml`** (`X.Y.Z+build`);
    - (d) el commit de la etiqueta **no está en la historia de `main`**;
    - (e) el paquete está firmado con el **certificado de depuración** o sin firmar. **[Pendiente, F6]** Cuando exista la clave de subida, se compara además con la huella SHA-256 **pública** de su certificado, guardada en el repositorio (no es un secreto);
    - (f) el *package name* (`applicationId`) es el provisional (`invalid.pending.*`) o usa un dominio reservado (PD-2): es el marcador que no se puede cambiar después de la primera subida.

    **[Suposición]** Hoy el modo estricto falla siempre, por (a), (b), (e) y (f): es lo esperado hasta PD-2 y F6, y es la prueba de que la puerta funciona.
  - **Verificable:** tests del script de la puerta y de la clasificación (CA-020-05) con identidades, políticas, versiones y firmas de prueba; y una ejecución real con una etiqueta de prueba (CL-020-1).

- **CA-020-04 Modo testers: lista lo que falta sin bloquear**
  - **Dado** el trabajo lanzado a mano (modo testers) desde `main`
  - **Cuando** corre
  - **Entonces**:
    - pasa **todas** las comprobaciones de CA-020-02 y CA-020-03;
    - los fallos que son **avisos de identidad** (CA-020-05) no lo hacen fallar: aparecen en un **resumen** del trabajo, uno por línea, con la comprobación, la clave o el archivo y el motivo, y una frase final que dice que **esta versión no se puede publicar**;
    - cualquier otro fallo lo hace fallar igual que en modo estricto.

    El resumen no lleva contenido de usuario (no lo hay en el repositorio) ni ningún secreto.
  - **Verificable:** test de la clasificación con una identidad con marcadores (sale verde con avisos) y con un permiso de más (sale rojo); y una ejecución real en GitHub, con el resumen anotado en `mastg.md` o en la PR.

- **CA-020-05 La lista de avisos de identidad es cerrada**
  - **Dado** la clasificación de los fallos en «aviso de identidad» o «fallo»
  - **Cuando** se mira qué cuenta como aviso de identidad
  - **Entonces** son **solo** estos:
    - (a) una dirección de `identity.yaml` que es un marcador o tiene un dominio reservado;
    - (b) el *package name* provisional (CA-020-03 f);
    - (c) un hueco o una marca de documento en la política;
    - (d) la firma de depuración o un paquete sin firmar;
    - (e) en modo testers, que no haya etiqueta.

    **Todo lo demás es un fallo en los dos modos**, por ejemplo: una dirección con ruta no válida, una que no es `https`, una clave que falta, dos direcciones iguales o lo generado desfasado. Si una misma dirección tiene un aviso y un fallo (p. ej. `https://example.com/%2e`), **cuenta como fallo**. Una comprobación nueva que se añada en el futuro es un fallo **por defecto**, salvo que una spec la añada a esta lista.
  - **Verificable:** test que recorre cada tipo de error de la puerta y comprueba su clase; una dirección `http://ejemplo-propio.es` y una `https://example.com/%2e` fallan también en modo testers.

- **CA-020-06 Qué deja el trabajo**
  - **Dado** un trabajo de publicación terminado (en verde, o en verde con avisos)
  - **Cuando** se miran sus artefactos
  - **Entonces** deja:
    - el **archivo de avisos de terceros** de **esa** compilación (`third-party-notices.txt`, 90 días), que es el que `/release-checklist` adjunta a la versión;
    - el **resumen** de CA-020-04.

    **[Suposición]** **No** sube APK ni AAB (Q-020-5). El APK de *release* de hoy va firmado con el certificado de depuración y **sí** se puede instalar a mano, pero el repositorio es público y el artefacto lo podría descargar cualquiera con cuenta de GitHub. Las entregas a testers se compilan del **mismo commit** que pasó el modo testers. En F6, lo que se sube a Play es el AAB de este trabajo en modo estricto (firmado entonces), nunca una compilación local.
  - **Verificable:** la lista de artefactos de una ejecución real.

- **CA-020-07 La puerta se prueba a sí misma**
  - **Dado** las comprobaciones del trabajo de publicación
  - **Cuando** se pasan sus pruebas automáticas, en la CI de las PR
  - **Entonces** cada comprobación tiene su caso negativo, que **falla con un mensaje que nombra lo que falla**:

    | Comprobación | Caso negativo |
    |---|---|
    | Puerta de la identidad (CA-020-09 a 12) | Una dirección con cada error, una política con un hueco y con cada marca, un archivo ausente |
    | Lo generado al día | Un `app_identity.g.dart` o unos textos nativos desfasados |
    | Versión y etiqueta (CA-020-03 c, d) | Etiqueta mal formada, que no coincide con `pubspec.yaml`, fuera de `main` |
    | *Package name* (CA-020-03 f) | `invalid.pending.app` |
    | Permisos y componentes (CA-020-13) | Un permiso, un `<intent-filter>` o una forma `-sdk-23` de más |
    | Clases de pruebas | Un paquete con `org/junit` |
    | Estática MASTG y firma (CA-020-22) | Uno por regla |
    | Licencias | Las de `check-licenses.sh --negative`, que se mantienen |

    Quedan **exentos** el tamaño y PDFium: ya fallan por construcción (un umbral y una suma fijada) y no tienen entrada que se pueda mutar sin compilar.
  - **Verificable:** los propios tests (`test/tool/…` y pasos negativos de CI).

- **CA-020-08 No estorba en el día a día**
  - **Dado** una compilación local (*debug* o *release*), la CI de una PR o una compilación de *release* para medir o para el Xiaomi
  - **Cuando** se compila
  - **Entonces** la puerta de la identidad **no** se ejecuta ni hace fallar la compilación: los marcadores siguen siendo normales mientras se desarrolla (spec 015, CA-015-13b). La CI de las PR sigue pasando las comprobaciones que ya pasaba y suma la estática MASTG (CA-020-22), que no depende de la identidad.
  - **Verificable:** `flutter build apk --release` local con los marcadores de hoy termina bien; la CI de la PR de esta spec, en verde.

### B. La puerta de la identidad y de la política, endurecida

- **CA-020-09 La ruta de las direcciones, restringida (B-2)**
  - **Dado** una dirección de `identity.yaml`
  - **Cuando** la puerta la valida
  - **Entonces** la ruta (lo que va tras el dominio) solo puede estar vacía o ser `/` seguida de **letras ASCII, cifras, `.`, `_`, `~`, `-` y `/`**. Se rechazan:
    - los caracteres invisibles o de dirección (U+200B, U+200E/F, U+202A–E, U+2066–9);
    - cualquier `%` (también `%2e`, `%2f`, `%5c` y `%00`);
    - los segmentos `.` y `..`;
    - las barras dobles `//`.

    Las reglas de hoy se mantienen: `https`, sin usuario ni puerto, sin `?`, `#` ni `\`, dominio solo ASCII y direcciones distintas entre sí. La puerta sigue sin poder ser más permisiva que la regla de la app (`privacyLink`) (CA-015-13b).
  - **Verificable:** tests de la puerta con cada carácter y cada secuencia de la lista; y el test que ya compara la puerta con `privacyLink`.

- **CA-020-10 Dominios reservados completos y con fuente (B-3, M8 de la 015)**
  - **Dado** la lista de dominios y sufijos reservados de la puerta
  - **Cuando** se valida una dirección
  - **Entonces**:
    - se rechazan también los sufijos `.alt`, `.home`, `.corp`, `.mail`, `.intranet`, `.private` y `.arpa`, además de los de hoy (`example`, `test`, `invalid`, `localhost`, `local`, `internal`, `lan`, `localdomain`, `onion` y los dominios `example.com/net/org`, `yourdomain.com` y `home.arpa`);
    - la lista de **TLD de prueba IDN** queda **contrastada con la de IANA**: se anota en el código la fuente y la fecha, y desaparece la **[Suposición]** «escrita de memoria».

    La comprobación compara sin distinguir mayúsculas y quita un punto final (`example.com.`).
  - **Verificable:** un test con cada sufijo, con su versión en mayúsculas y con un punto final.

- **CA-020-11 Las marcas de la política bloquean (012-S4)**
  - **Dado** `docs/legal/privacy-policy.md`
  - **Cuando** la puerta la revisa
  - **Entonces**, **en las partes española e inglesa** (el mismo ámbito que los huecos de hoy; la cabecera y las «Notas para la revisión» quedan fuera, porque no se publican), cuenta como error, además de los huecos, cualquier marca de documento **`[Suposición]`, `[Assumption]`, `[Pendiente]` o `[Pending]`**:
    - sin distinguir mayúsculas y con o sin espacios dentro de los corchetes;
    - también con texto detrás, como ya se usa en el proyecto (`[Pendiente PD-2]`, `[Suposición, PD-9]`).

    `[Hecho]` no bloquea. Cada marca se informa con su número de línea. Es un aviso de identidad (CA-020-05 c): bloquea en modo estricto y se lista en modo testers. **[Suposición]** `[Pendiente]` y `[Pending]` también bloquean: una política publicada no puede decir que algo está pendiente (Q-020-1). Hoy hay 12 marcas en esas partes (6 en español y 6 en inglés).
  - **Verificable:** un test con una política con cada marca y sus variantes, dentro y fuera de las partes publicadas; y una ejecución con la política real, que da 12 o más avisos.

- **CA-020-12 La puerta falla cerrada**
  - **Dado** un archivo que la puerta debe leer (`identity.yaml`, la política o lo generado) que falta, está vacío, no es YAML válido o no se puede leer
  - **Cuando** corre la puerta
  - **Entonces** falla con un mensaje que nombra el archivo, **en los dos modos**: no es un aviso de identidad. Nunca da por buena una comprobación que no ha podido hacer.
  - **Verificable:** tests con cada caso.

### C. Herramientas de comprobación

- **CA-020-13 Permisos y componentes sin huecos (019-e)**
  - **Dado** el manifiesto combinado de *release*
  - **Cuando** pasa `tools/check-android-permissions.sh release`
  - **Entonces**, además de lo de hoy:
    - (a) la `MainActivity` tiene **exactamente** un `<intent-filter>`, con la acción `MAIN` y la categoría `LAUNCHER`, sin `<data>`, sin `BROWSABLE` ni `DEFAULT` y sin otras acciones (sin *deep links*, T-8);
    - (b) cuentan **todas** las formas de pedir un permiso: `<uses-permission>`, `<uses-permission-sdk-23>` y `<uses-permission-sdk-m>`.

    Un manifiesto de prueba con cada uno de estos casos hace fallar el script.
  - **Verificable:** pasos negativos del script con manifiestos de prueba, en la CI de las PR.

- **CA-020-14 El *wrapper* de Gradle, verificado (012-S6)**
  - **Dado** `app/android/gradle/wrapper/gradle-wrapper.properties`
  - **Cuando** se descarga Gradle (en local y en CI)
  - **Entonces**:
    - la distribución se comprueba con su **suma SHA-256** fijada en el propio archivo (la que publica Gradle para esa versión), y una suma que no coincide hace fallar la compilación;
    - el `gradle-wrapper.jar` del repositorio, que es lo que se ejecuta, coincide con una de las sumas que publica Gradle;
    - la CI comprueba las dos cosas, también después de que una actualización de Flutter reescriba el archivo y la suma desaparezca (CL-020-18).

    El residual «sin *lockfile* de Gradle» (`threat-model.md` §5) **sigue fuera de alcance**, anotado.
  - **Verificable:** un paso de CI que falla si falta la suma o si el jar no coincide; la compilación de CI, en verde con ella.

- **CA-020-15 Las herramientas de los iconos, acotadas (018, bajos 1 y 2)**
  - **Dado** las herramientas `app/tool/png_lite.dart` y `app/tool/gen_icons.dart`, que no se empaquetan
  - **Cuando** leen un PNG o escriben en `--out`
  - **Entonces**:
    - el lector rechaza un PNG de más de **2048 px de lado**, un **segundo `IHDR`** y unos datos que, una vez descomprimidos, superen lo que corresponde a sus dimensiones;
    - el generador **no sigue enlaces simbólicos** al escribir y, ante un error de escritura, termina con un mensaje que nombra la ruta y el motivo y con un código de error, sin traza.

    Los iconos generados no cambian (las pruebas de la 018 siguen en verde).
  - **Verificable:** tests de las herramientas con un PNG de 4096 px, uno con dos `IHDR`, uno con una bomba de descompresión y un `--out` que es un enlace.

### D. Endurecimiento del código de la app (hallazgos bajos)

- **CA-020-16 Lectura de los ajustes acotada (B-4)**
  - **Dado** una base de datos restaurada o manipulada en la que un valor de `settings` mide más de **16 caracteres** (o un millón)
  - **Cuando** la app lee los ajustes (al arrancar o al abrir Ajustes)
  - **Entonces** ese valor **no se carga entero en memoria** (se acota al leerlo, antes de llegar a la app) y se trata como **ilegible**, con su valor por defecto (CA-015-26, CA-017-03 y CA-019-05). La app arranca normal, sin errores y sin registrar nada. Los valores válidos de hoy (todos de 16 caracteres o menos) se leen igual que antes.
  - **Verificable:** test de datos con un valor de 17 caracteres y uno de 1 MB, que comprueba que se lee el defecto y que lo que llega a la app no supera el límite; los tests de los ajustes, en verde.

- **CA-020-17 Arranque tolerante con todos los valores guardados (B-5)**
  - **Dado** una base de datos con `firstRunDone` o `hasEverHadTasks` ilegibles: un entero, un BLOB, `NULL`, un texto que no es `true` ni `false` o uno demasiado largo
  - **Cuando** arranca la app
  - **Entonces** arranca sin fallar ni mostrar errores, **como si esa clave no existiera**, igual que los demás ajustes (CA-015-26), y sin registrar el valor.
  - **Verificable:** test del arranque con cada valor raro en cada clave. Enmienda CA-015-26 (§10).

- **CA-020-18 Los comentarios dicen la verdad (B-6)**
  - **Dado** `LinkOpener.kt`
  - **Cuando** se lee el comentario que dice que la dirección «ya [está] confirmada en Dart»
  - **Entonces** el comentario describe los **dos** caminos que pasan por ahí hoy:
    - **Ajustes:** sin confirmación (CA-015-12a), con direcciones que son constantes de compilación, y la regla `https` sin usuario solo en Dart (residual 012-S1, aceptado);
    - **enlaces del PDF:** sí se confirman antes (CA-008-12) y admiten `http(s)`, `mailto:` y `tel:` (T-5).

    El comportamiento del código **no** cambia.
  - **Verificable:** revisión del diff. Los tests de los enlaces no cambian.

- **CA-020-19 El barrido de arranque, por lotes (016-c)**
  - **Dado** una base de datos con muchas filas de adjuntos (50 000 en el test) y huérfanos en disco
  - **Cuando** corre el barrido de arranque
  - **Entonces**:
    - **ninguna consulta** del barrido usa ni devuelve más de **N identificadores** (N lo fija el plan) y la memoria que usa **no crece** con el número de filas de la BD: no carga todos los identificadores ni los consulta uno a uno por cada huérfano;
    - el resultado es el mismo que hoy: borra lo que no está en la BD y nunca lo que pertenece a una tarea, también a una recuperada o a una retenida para deshacer (CA-014-13);
    - sigue empezando después del arranque (P2 sin cambios).
  - **Verificable:** test del barrido con 50 000 filas y huérfanos mezclados, que comprueba que ninguna consulta supera N; los tests de la 014 y la 016 del barrido, en verde.

- **CA-020-20 La migración v2→v3, paginada y atómica (016-c)**
  - **Dado** una base de datos v2 con muchas filas de adjuntos (50 000 en una tarea, y repartidas en muchas)
  - **Cuando** se migra a v3
  - **Entonces**:
    - la migración numera **por páginas**, sin cargar todas las filas en memoria, y el resultado es **idéntico** al de hoy (mismas posiciones);
    - si falla a mitad, **no queda nada cambiado** (la BD sigue en v2 y entera), igual que la prueba que ya existe de v1→v2.

    Sin `schemaVersion` nueva: cambia cómo se migra, no el esquema.
  - **Verificable:** test de migración con 50 000 filas, que compara con la captura de hoy; y un test de fallo a mitad de v2→v3.

- **CA-020-21 El tope de 10 fotos, probado en nativo, y su límite, escrito (016-c)**
  - **Dado** el selector de fotos que devuelve **5000 elementos**
  - **Cuando** la parte nativa los recibe
  - **Entonces**:
    - una prueba del código nativo, sin emulador, comprueba que solo se tocan **10**: ninguno más se abre, se consulta ni se copia (CA-016-24);
    - el modelo de amenazas (T-16) anota el límite conocido: con una limpieza abandonada, la cola de limpieza puede encadenar falsos vencimientos de 20 s hasta el total de 2 min. El comportamiento no cambia.
  - **Verificable:** la prueba nativa en la CI; el diff de `threat-model.md`.

- **CA-020-27 Una dirección mal codificada no rompe nada (019, bajo a)**
  - **Dado** una dirección web guardada (restaurada, manipulada o escrita por el usuario) con una secuencia `%` que no es UTF-8 válido (p. ej. `https://dominio.es/%C3`)
  - **Cuando** la app calcula el dominio que enseña (la barra del dominio, la etiqueta de la tarea, la card de deshacer o la notificación)
  - **Entonces** no lanza ningún error: muestra el dominio igual que con una dirección bien formada (o la etiqueta genérica de la web si no hay dominio legible), sin registrar nada. El comportamiento con direcciones válidas no cambia.
  - **Verificable:** test de la función del dominio con `%C3`, `%`, `%ZZ` y `%E2%82` sueltos.

- **CA-020-28 La orden de abrir de la notificación, probada sin emulador (019, bajo d)**
  - **Dado** el código nativo que publica la notificación y recibe la orden de abrir
  - **Cuando** se pasan las pruebas nativas de la CI
  - **Entonces** hay prueba de que:
    - la notificación lleva la versión pública genérica, es solo local y usa órdenes explícitas e inmutables;
    - la orden de abrir sin el `nonce` vigente, con uno usado o con otro, se ignora;
    - el receptor descarta cualquier acción fuera de su lista blanca.

    Hoy solo están comprobados en el emulador y con tests de Dart que leen el código.
  - **Verificable:** las pruebas nativas nuevas, en la CI.

### E. Verificación MASTG

- **CA-020-22 Comprobación estática MASTG del paquete de *release***
  - **Dado** el APK de *release* (y, en el trabajo de publicación, el AAB)
  - **Cuando** pasa la comprobación estática, **en la CI de las PR y en el trabajo de publicación**
  - **Entonces** falla si:
    - (a) la app es **depurable** o de solo pruebas (`debuggable` o `testOnly`);
    - (b) admite **tráfico en claro** (`usesCleartextTraffic` distinto de `false` o una configuración de red con `cleartextTrafficPermitted="true"`, **cualquier `<domain-config>`**, **certificados del usuario** (`<certificates src="user">`) o anclas de depuración fuera de *debug*);
    - (c) faltan o no se referencian las reglas de copia de seguridad y de transferencia (`fullBackupContent` y `dataExtractionRules`), o su contenido no es **exactamente el conjunto esperado** de reglas (D14, ADR-0004, ADR-0016, CA-019-23; como hoy `backup_rules_test.dart`, pero sobre el paquete compilado);
    - (d) hay algún `<provider>` exportado, o las rutas del FileProvider van más allá de las de hoy (ninguna `<root-path>` ni rutas amplias; `grantUriPermissions` puntual es lo esperado, spec 007);
    - (e) el `minSdk` no es 26 (D12) o el `targetSdk` está por debajo del mínimo que acepta Google Play (Q-020-3);
    - (f) el paquete contiene algo con forma de **secreto**: claves privadas (`BEGIN … PRIVATE KEY`), claves de API de Google (`AIza…`), claves de AWS (`AKIA…`), *tokens* de GitHub (`ghp_`, `github_pat_`) o archivos de firma (`*.jks`, `*.keystore`, `*.p12`);
    - (g) se pierden ajustes de privacidad de hoy: `MetricsOptOut` de la WebView a `true` (P4) y la afinidad de tarea de la `MainActivity`.

    En modo estricto, además, la firma y el *package name* (CA-020-03 e y f). Cada fallo nombra la regla y el archivo, y nunca imprime el posible secreto entero.
  - **Verificable:** pasos negativos con manifiestos, configuraciones de red y paquetes de prueba (uno por regla); el APK real, en verde.

- **CA-020-23 Pasada MASTG en el emulador, con su informe**
  - **Dado** la compilación de *release* instalada en el emulador de API 37 (**no** en el Xiaomi; Q-020-4), con tareas de prueba de cada tipo (texto con una cadena secreta, una foto con GPS, un grupo de fotos, un PDF y una web), la card de deshacer y las notificaciones encendidas
  - **Cuando** se hace la pasada MASTG
  - **Entonces** se ejecuta y se anota en `specs/020-seguridad-y-puerta-de-publicacion/mastg.md`, con **[Hecho]**, **[Pendiente]** o **hallazgo** y el comando o la evidencia, **al menos** esta lista:
    - **MASVS-STORAGE:**
      - (1) todo vive en el *sandbox*: nada en el almacenamiento externo ni en el compartido;
      - (2) ningún archivo de la app fuera de la BD contiene la cadena secreta (`shared_prefs`, la copia derivada, cachés y `app_webview`);
      - (3) las fotos guardadas no llevan EXIF ni GPS;
      - (4) tras completar o eliminar una tarea y pasado el barrido, no quedan sus archivos;
      - (5) la **copia en la nube** contiene la BD y los ajustes, y **no** las imágenes ni los PDF (ADR-0004), la caché, la zona temporal, la WebView ni el almacenamiento «device protected»;
      - (5b) la **transferencia entre dispositivos** contiene además las imágenes y los PDF (CA-016-17), y tampoco lleva la caché, la zona temporal, la WebView ni el almacenamiento «device protected». El método para obtener cada una lo justifica el plan.
    - **Registros:**
      - (6) un ciclo completo de todas las funcionalidades (crear, editar, ver, completar, eliminar y deshacer, importar fotos, PDF y web, notificación y Ajustes) deja **0 coincidencias** de la cadena secreta, de la dirección de la web y de los **nombres originales** de los archivos importados en el **registro entero** del sistema. Lo que escriba el sistema (no la app) se anota aparte, con su origen.
    - **MASVS-PLATFORM:**
      - (7) `am start` sobre la `MainActivity` con datos, *extras* y acciones ajenas no hace nada distinto de abrir la app;
      - (8) las difusiones al `WakeReceiver` desde otra app se rechazan o se ignoran (T-8);
      - (9) ningún proveedor responde a consultas de otra app;
      - (10) la orden de abrir de la notificación sin el `nonce` vigente se ignora;
      - (11) «Recientes»: `tools/check-recents.sh` (`capture`, `compare`, `secure`, `loop 10`, `record 10`) en verde;
      - (12) la app no escribe nunca en el portapapeles sin una acción del usuario;
      - (12b) todas las órdenes que la app deja a otros (`PendingIntent`) son explícitas e inmutables.
    - **MASVS-NETWORK:**
      - (13) con red, durante el ciclo completo, la app solo abre las conexiones de la web pedida y las de Safe Browsing de la WebView del sistema (decisión del propietario, `threat-model.md` §4); las de Ajustes las hace el navegador. El método de medida lo fija el plan;
      - (14) una web `http://` y una con certificado inválido no cargan.
    - **WebView** (ADR-0016/0018):
      - (15) `file://`, `content://` y `javascript:` no se cargan;
      - (16) tras salir de la tarea no quedan cookies ni almacenamiento web.
    - **MASVS-CODE:**
      - (17) el paquete de *release* no lleva rutas absolutas de la máquina de compilación (`/Users/…`, `/home/runner/…`) ni símbolos de depuración de Dart.

    Lo que dependa de Android 8–12 (PD-10) o del Xiaomi se marca **[Pendiente, 022]**.
  - **Verificable:** el propio `mastg.md`, revisado por `security-reviewer` en el cierre.

- **CA-020-24 Hallazgos cerrados o aceptados por escrito**
  - **Dado** los hallazgos de la pasada MASTG y de las revisiones de cierre (`security-reviewer`, `spec-reviewer`)
  - **Cuando** se cierra la spec
  - **Entonces**:
    - no queda **ningún hallazgo alto**;
    - cada **medio** está corregido en la rama o **aceptado por el propietario** con su motivo en `threat-model.md` §7;
    - los **bajos** sin corregir quedan en `docs/PLAN.md`, con su spec de destino (022 o 023).

    Los hallazgos de origen de esta spec (cabecera) y los que el §8 declara fuera de alcance quedan **todos** marcados como corregidos, aceptados o movidos, ninguno sin estado.
  - **Verificable:** la tabla de hallazgos de `mastg.md` y el diff de `docs/PLAN.md`.

### F. Transversales

- **CA-020-25 Sin cambios para el usuario**
  - **Dado** la app antes y después de esta spec
  - **Cuando** se usa
  - **Entonces**:
    - no cambia **ninguna pantalla, texto, interacción, permiso ni componente**;
    - no hay esquema de BD nuevo ni dependencias de ejecución nuevas (`pubspec.lock` sin paquetes nuevos de ejecución; las acciones de GitHub nuevas, si las hay, van fijadas por SHA y justificadas en la PR, P11);
    - el **arranque en frío no se degrada**: CA-020-16 y 17 tocan el arranque, así que se mide el p50 frente a `main` en el emulador de API 37 (20 arranques de cada uno, `tools/measure-cold-start.sh`), y la diferencia debe quedar dentro de la deriva medida entre dos series de `main` (como en la 017 y la 019);
    - los *goldens* no cambian.
  - **Verificable:** `git diff main -- app/lib/l10n app/android/app/src/main/AndroidManifest.xml app/pubspec.lock` sin cambios de ejecución, salvo lo que pida CA-020-22 con su justificación en la PR; la medida en `docs/perf/baseline.md`; la CI, en verde.

- **CA-020-26 Documentación al día**
  - **Dado** el cierre de la spec
  - **Cuando** se revisa la documentación
  - **Entonces** quedan al día:
    - `docs/security/checklist.md`: el trabajo de publicación, los dos modos y la estática MASTG;
    - `docs/security/threat-model.md`, con versión nueva: T-10 a T-13, T-16, §5, §7 y §8 (con la pasada hecha y su fecha);
    - la skill `/release-checklist`: remite al resultado del trabajo de publicación en lugar de pedir el script a mano, conserva los puntos manuales y fija el **orden**: etiqueta `vX.Y.Z` (con confirmación) → trabajo estricto en verde → archivo de avisos adjunto → publicar. **Sin una ejecución en verde del trabajo sobre ese commit, la versión no es publicable.** Si el trabajo falla, la etiqueta se borra (con permiso del propietario) y se crea otra tras corregir;
    - `docs/testing.md`, el glosario, `docs/PLAN.md` (fila F5, hallazgos cerrados y la 021 como siguiente) y `CLAUDE.md` («Fase actual»).
  - **Verificable:** revisión del diff en el cierre.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-020-1 | Etiqueta de prueba para ver el modo estricto (p. ej. `v0.0.0-gate`) | No tiene la forma `vX.Y.Z`: falla por CA-020-03 c, igual que una mal escrita. **[Suposición]** Para probar el modo estricto se usa una etiqueta `vX.Y.Z` que coincida con `pubspec.yaml`, subida solo con permiso del propietario (CLAUDE.md: nada de etiquetas sin confirmación) y borrada después; falla por los avisos de identidad, que es lo esperado |
| CL-020-2 | Etiqueta `v1.2.3` sobre un commit de una rama que no está en `main` | Falla (CA-020-03 d), aunque todo lo demás pase |
| CL-020-3 | Lanzamiento a mano desde una rama distinta de `main` | **[Suposición]** Falla al empezar, con un mensaje claro: las entregas a testers salen de `main` (Q-020-2) |
| CL-020-4 | Dos etiquetas sobre el mismo commit, o el mismo trabajo lanzado dos veces | Cada ejecución es independiente y da el mismo resultado; no comparten artefactos |
| CL-020-5 | Un *fork* sube una etiqueta `v*` en su copia | No corre en el repositorio original; en el *fork* no hay secretos que robar (no hay ninguno) |
| CL-020-6 | Dirección `https://dominio-propio.es` (sin ruta) o `https://dominio-propio.es/` | Válidas (CA-020-09) |
| CL-020-7 | Dirección `https://DOMINIO-PROPIO.ES/Privacy` | Válida si el dominio no está reservado. La comparación de dominios no distingue mayúsculas; las rutas sí. «Distintas entre sí» sigue normalizando como en la 015 |
| CL-020-8 | Dominio en *punycode* (`xn--…`) que no es de prueba | Se admite (la puerta ya exige ASCII); si su TLD es de la lista de prueba de IANA, se rechaza |
| CL-020-9 | La política tiene una marca dentro de un bloque de código o en un comentario HTML | Cuenta igual: la política publicada no lleva marcas en ninguna parte |
| CL-020-10 | Un ajuste guardado mide exactamente 16 caracteres | Se lee (dentro del límite); con 17, ilegible → defecto (CA-020-16) |
| CL-020-11 | Base de datos v2 con un millón de filas de adjuntos | La migración sigue lineal y paginada; si el sistema la mata a mitad, la BD queda en v2 y se reintenta en el siguiente arranque (CA-020-20) |
| CL-020-12 | La comprobación de secretos encuentra un falso positivo (p. ej. un texto de una licencia o un recurso de un paquete con forma de clave) | Falla igual; el plan define una **lista de excepciones** por archivo y patrón, revisada en la PR, nunca un patrón que la desactive |
| CL-020-13 | Flutter sube el `targetSdk` en una actualización | La comprobación sigue pasando si está por encima del mínimo; si Play sube el mínimo, se actualiza el valor en su único sitio (CA-020-22 e) |
| CL-020-14 | La pasada MASTG encuentra algo que solo se arregla en otra spec (p. ej. accesibilidad o Android 8) | Se anota como hallazgo con su spec de destino; no se arregla aquí (CA-020-24) |
| CL-020-15 | El emulador no permite una prueba (p. ej. la transferencia entre dispositivos) | Se anota **[Pendiente, 022]** con el motivo; no se da por hecha |
| CL-020-16 | Etiqueta `vX.Y.Z` sobre un commit anterior a esta spec, que no tiene el workflow | No se lanza nada. **Sin ejecución en verde, la versión no es publicable** (`/release-checklist`, CA-020-26) |
| CL-020-17 | El `versionCode` (el `+build` de `pubspec.yaml`) es igual o menor que el de una etiqueta anterior | Falla en modo estricto: Play lo rechazaría. **[Suposición]** Se compara con la etiqueta `v*` anterior más alta del repositorio |
| CL-020-18 | Una actualización de Flutter reescribe `gradle-wrapper.properties` y la suma desaparece | La CI falla (CA-020-14) hasta que se vuelve a poner la suma de la versión nueva |
| CL-020-19 | Una etiqueta movida o subida a la fuerza a otro commit | Se lanza de nuevo sobre el commit nuevo y se comprueba de cero; la ejecución anterior no cuenta para el commit nuevo |
| CL-020-20 | Una dirección con un aviso y un fallo a la vez (`https://example.com/%2e`) | Fallo en los dos modos (CA-020-05) |

## 5. Estados vacíos y de error

No hay estados nuevos en la app. En el trabajo de publicación:

| Estado | Cuándo | Qué ve el propietario |
|---|---|---|
| Verde | Modo estricto sin fallos (cuando estén PD-2, PD-3 y la firma) | Todas las comprobaciones en verde y el archivo de avisos como artefacto |
| Verde con avisos | Modo testers con marcadores, sin otros fallos | El trabajo en verde y, en el resumen, la lista de avisos de identidad y la frase «Esta versión no se puede publicar» |
| Rojo | Cualquier fallo que no es un aviso de identidad, o cualquier aviso en modo estricto | El paso que falla y un mensaje que nombra la comprobación, el archivo o la clave y el motivo |
| Rojo al empezar | Lanzamiento a mano fuera de `main` (CL-020-3) o etiqueta mal formada | Un mensaje que lo dice, antes de compilar |

## 6. Accesibilidad

No aplica a la app: no cambia ninguna pantalla, texto ni interacción (CA-020-25). El resumen del trabajo de publicación es texto: no depende del color para distinguir un aviso de un fallo (cada línea dice «aviso» o «fallo»).

## 7. Textos (ES / EN)

Sin textos nuevos en la app (ARB sin cambios). Los mensajes de las herramientas y del trabajo de publicación van en español, como los de los scripts de `tools/`. No son textos de la app ni pasan por ARB (P7 se refiere a lo que ve el usuario).

## 8. Fuera de alcance

- **La firma** con la clave de subida, Play App Signing, la subida a Play y las etiquetas reales de versión: **F6** (y `release-please` / `CHANGELOG.md`, si se usan).
- **El dominio y las direcciones reales** (PD-2), la cuenta de Play (PD-3), Data Safety, la ficha de la tienda, el contenido de la política y la revisión legal del ADR-0026: **023 / F6**.
- **Pantallas grandes** (R-25, PD-11) y **Android 8 y 12L** (PD-10): **022**.
- Los hallazgos de **accesibilidad** de las specs 012–019 y las casillas de dispositivo: **022**.
- **Repetir en Kotlin** la regla `https` sin usuario de `LinkOpener.kt` (012-S1): sigue aceptado como residual; solo se corrige el comentario (CA-020-18).
- El nombre de la app escrito tal cual en `app/web/index.html` y `manifest.json` (bajo 3 de la 018): no es de seguridad; sigue en `docs/PLAN.md`.
- El *fuzzing* de importadores (T-14): no hay importadores mientras el flag `imports` esté apagado.
- iOS (D17), *pinning* de certificados (no hay servidor propio, T-6) y biometría (D11).
- Pruebas MASTG de resiliencia (detección de *root*, antimanipulación): fuera del objetivo de MASVS-L1 de esta app.
- **014 S2** (el barrido solo corre a los 2 s del arranque): se queda como está. Si el sistema mata la app antes, los archivos esperan al siguiente arranque, con la exposición ya aceptada en T-7. Se reconsidera si la pasada MASTG lo señala.
- **T-11, la configuración del repositorio:** reglas de rama y de **etiquetas `v*`** (quién puede lanzar el modo estricto), aprobación de los workflows de *forks* y *secret scanning*. **[Suposición]** Hoy el propietario es el único con escritura, así que solo él puede subir una etiqueta. Se configura y se anota en F6, antes de la primera subida a Play.
- El *lockfile* de Gradle (residual de `threat-model.md` §5): sigue anotado como residual.

## 9. Preguntas abiertas

- **Q-020-1** ✅ **Resuelta (propietario, 2026-10-14): sí.** ¿`[Pendiente]` y `[Pending]` también bloquean en la política, además de `[Suposición]` y `[Assumption]`? **[Suposición]** Sí (CA-020-11).
- **Q-020-2** ✅ **Resuelta (propietario, 2026-10-14): sí, solo desde `main`.** ¿El modo testers solo se lanza desde `main`, o también desde una rama para probar una entrega antes de fusionar? **[Suposición]** Solo desde `main` (CL-020-3).
- **Q-020-3** ✅ **Resuelta en el plan (2026-10-14): `targetSdk` ≥ 36**, requisito de Google Play desde el 31-08-2026, fijado en `playMinTargetSdk` de `app/tool/check_package.dart` (plan §1). (Claude Code, en el plan) El valor mínimo de `targetSdk` que exige Play hoy y dónde se fija. **[Suposición]** Se toma el requisito vigente de Google Play al escribir el plan, en un solo sitio.
- **Q-020-4** ✅ **Resuelta (propietario, 2026-10-14): solo en el emulador.** ¿La pasada MASTG se hace solo en el emulador, o también en el Xiaomi (con tu permiso y sin capturas)? **[Suposición]** Solo en el emulador; lo que dependa del Xiaomi va a la 022.
- **Q-020-5** ✅ **Resuelta (propietario, 2026-10-14): no.** ¿El modo testers debería dejar el APK como artefacto (firmado con el certificado de depuración, de retención corta) para que la entrega sea **ese** archivo? Como el repositorio es público, lo podría descargar cualquiera con cuenta de GitHub. **[Suposición]** No: la entrega se compila del mismo commit (CA-020-06).

## 10. Enmiendas a otras specs y documentos (al aprobar esta spec)

- **Spec 015, CA-015-13b:** se resuelve la **[Suposición]** «hasta que exista el trabajo de CI de la publicación (F6/020), se aplica a mano». La puerta de la identidad corre en el trabajo de publicación (CA-020-02), y `/release-checklist` remite a su resultado.
- **Spec 015, CA-015-26:** la lectura tolerante se amplía a `firstRunDone` y `hasEverHadTasks` (CA-020-17), y todo valor de más de 16 caracteres es ilegible (CA-020-16).
- **`docs/PLAN.md`:**
  - en la fila F6 desaparece «no está en `ci.yml`» (riesgo de CA-012-05);
  - en «Hallazgos de la 012», 012-S3, S4 y S6 pasan a corregidos en la 020;
  - en los cierres de la 015, 016, 018 y 019, los hallazgos que recoge esta spec pasan a corregidos o a su destino.
- **Skill `/release-checklist`:** desaparece «Revisar a mano las frases [Suposición]» (la puerta las detecta, CA-020-11), y cambian el orden y la condición de publicación (CA-020-26).
- **Glosario:** «Puerta de publicación» pasa a ser el trabajo entero y se añaden los términos de la Nomenclatura (hecho en el borrador).
