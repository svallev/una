# ADR-0016: Tarea web sin copia local: se guarda solo la dirección y la página se carga en vivo cada vez

- **Estado:** Aceptado (propietario, 2026-09-28, con la spec 009; excepción a P3)
- **Fecha:** 2026-09-28
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 009, D9 (la sustituye), ADR-0007 (lo enmienda: sin captura), constitución P3 (excepción), propuesta de valor 2, modelo de amenazas T-4, T-5, T-6, riesgos R-04, R-05 y R-10

## Contexto

- **[Hecho]** D9 y el ADR-0007 decidieron guardar una **captura de página completa** al crear la tarea web, para verla sin conexión (P3). El spike S4 la validó en Android con un `WebSnapshotter` nativo (Kotlin).
- **[Hecho]** Al preparar la spec 009 (2026-09-28), el propietario decidió: "lo que se guarda es la URL y, cuando se abra, se carga. **No quiero guardar páginas web en local.**"
- **[Hecho]** P3 dice "Todo funciona en modo avión". Una tarea web sin copia no se puede ver sin conexión, así que la decisión es una **excepción a P3**. Cambiar la constitución exige un ADR y la aprobación explícita del propietario (cabecera de `specs/constitution.md`).
- **[Hecho]** La captura era la parte de más riesgo técnico de la F4 (R-05) y la que más ocupa (≈ 1–4 MB por tarea, con el presupuesto de la copia de seguridad de R-10).
- **[Hecho]** Una página de terceros guardada en el móvil (captura, caché o archivo web) es contenido no confiable que se queda en los datos de la app y viaja con las copias.

- **[Hecho]** Al aceptarlo, el propietario lo enmarca así: la web es una función **que obliga a tener conexión** y de **uso residual**, o solo para cuando sí hay conexión. Para tener algo a mano sin cobertura están la imagen y el PDF.

## Opciones consideradas

1. **Captura de página completa** (D9, ADR-0007): la página se ve sin conexión, pero se guarda en local.
2. **Solo la dirección, en vivo cada vez:** no se guarda nada de la página; sin conexión se avisa.
3. **Caché del WebView o archivo web (MHTML):** se guarda HTML y JavaScript de terceros ejecutables. Ya se descartó en el ADR-0007, y además es "guardar la página en local".

## Decisión

Opción 2. La tarea web guarda **solo la dirección**. Cada vez que se muestra, la página se carga en vivo en el WebView endurecido del ADR-0007. **No se guarda nada de la página** en el móvil: ni captura, ni caché en disco, ni cookies, ni almacenamiento web más allá de mientras se ve la tarea. Sin conexión, la tarea muestra el dominio, "Necesitas conexión para ver esta página." y "Reintentar".

Del ADR-0007 **se mantienen**:

- la validación de la dirección;
- el WebView endurecido (sin puente JavaScript, sin acceso a archivos, almacén no persistente, sin permisos ni descargas, certificados inválidos siempre rechazados, sin contenido mixto);
- la navegación contenida en el mismo sitio;
- la barra con el dominio real (punycode si mezcla alfabetos).

**Desaparecen** la captura, el `WebSnapshotter`, "Copia del {fecha}", "Actualizar" y "Copia pendiente".

**Criterio para revisarla:** si en la beta alguien necesita ver una página web sin cobertura y no le sirve la alternativa de abajo, se vuelve a la opción 1 con un ADR nuevo.

## Motivos

- Es lo que quiere el propietario: la app no almacena contenido web de terceros.
- **Privacidad y seguridad:** nada de terceros queda en los datos de la app ni en las copias de seguridad. La superficie T-4 se reduce a lo que pasa mientras se ve la tarea.
- **Menos código y menos riesgo:** sin código nativo de captura ni recorrido de la página (se cierra R-05) y sin archivos que borrar, respaldar ni recuperar ("Adjunto no disponible" no aplica).
- **Hay alternativa sin conexión:** quien necesite una página sin cobertura puede guardarla como PDF desde el navegador (spec 008) o hacer una captura de pantalla y subirla como imagen (spec 007).

## Consecuencias

- **Positivas:**
  - la spec 009 se simplifica mucho;
  - la tarea web no ocupa espacio y no afecta al presupuesto de la copia de seguridad (R-10);
  - se evitan R-04 y R-05;
  - con la app instalada, "Data Not Collected" (P4) no cambia.
- **Negativas y riesgos:**
  - **Excepción a P3:** la tarea web no se ve en modo avión. Se pierde la mitad de HU-009-1 ("verla sin cobertura") y la tarea web deja de cumplir la propuesta de valor 2 sin conexión. Mitigación: el aviso lo dice claramente, y existe la alternativa del PDF o la imagen. Se añade la excepción bajo P3 en la constitución (versión 1.4) al aceptar este ADR.
  - La página tarda en aparecer lo que tarde la red: P2 se cumple con la tarea (la barra del dominio) en menos de 1 s, no con el contenido de la página. Mitigación: indicador de carga.
  - Como no se guardan cookies, cada vez que se muestra la tarea el sitio puede volver a pedir el consentimiento de cookies o el inicio de sesión. Es una consecuencia aceptada (privacidad).
  - **Riesgo nuevo para `docs/PLAN.md`:** R-20, "usuarios que esperan ver la web sin conexión" (probabilidad media, impacto bajo). Seguimiento: el feedback de la beta.
- **Hecho al aceptarlo (2026-09-28):**
  - D9 pasa a "sustituida por el ADR-0016";
  - el ADR-0007 pasa a "Enmendado por el ADR-0016 (sin captura)";
  - R-05 queda cerrado y se añade R-20;
  - DEV-04 se actualiza en `docs/design/prototype-deviations.md`;
  - se añade la excepción bajo P3 en la constitución;
  - se añade la fila en `docs/adr/README.md`;
  - se actualiza T-4 en `docs/security/threat-model.md`: no se guarda nada de la página.
