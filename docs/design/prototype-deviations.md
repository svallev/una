# Desviaciones respecto al prototipo

El prototipo es la fuente de verdad visual y de interacción (constitución, P12). Cuando la implementación se aparta de él, se registra aquí con su motivo y su decisión de origen. Si el prototipo se actualiza, se revisa esta lista.

| ID | Prototipo | Implementación | Motivo | Origen |
|---|---|---|---|---|
| DEV-01 | Un documento (PDF, Word…) abre la hoja "¿Dónde la pones?" | Todo adjunto (imagen, foto, documento, URL) va **arriba del todo** sin preguntar | R5 manda; un adjunto se añade para consultarlo ya (propuesta 2) | Decisión D5 |
| DEV-02 | "Subir archivo · PDF, Word, Excel, TXT…" (no dice dónde va) | "Subir archivo · PDF, Word, Excel… · va arriba del todo" | Coherencia con DEV-01 | D5 |
| DEV-03 | Word, Excel/CSV y TXT se muestran **dentro** de la tarea (mammoth, SheetJS) | Solo el **PDF** se muestra dentro. El resto: tarjeta con nombre, tipo y tamaño y el botón "Abrir" (QuickLook / intent del sistema) | Riesgo y fidelidad: conversión simplificada y parsers de archivos no confiables | D6, ADR-0008 |
| DEV-04 | Tarea web: "En la app la página se carga aquí" y el enlace "Abrir página ↗" | WebView endurecida con la página en vivo si hay conexión; si no, captura de página completa con el aviso "Copia del dd/mm" | Funcionar sin conexión (P3) | D9, ADR-0007 |
| DEV-05 | Menú: "Configuración y perfil" (sin acción) | "Configuración", con pantalla propia | No hay perfil sin login | D13 |
| DEV-06 | Botón: "Pulsa para completar" | **Revocada (2026-09-24, decisión del propietario):** se mantiene "Pulsa para completar", en una sola línea. Siguen los textos de progreso del prototipo: al mantener, "Sigue pulsando…"; al terminar, "¡Hecho!" | El riesgo de que un toque simple no haga nada se cubre en la spec 003 (pista accesible "Mantén pulsado o usa las acciones para completar") | Propietario |
| DEV-07 | Placeholder: "¿Qué eso que tienes que hacer y no has hecho?" | "¿Qué es eso que tienes que hacer y no has hecho?" | Errata | Decisión propia |
| DEV-08 | Placeholder con opacidad 0,42 (contraste 2,3–2,75:1) | 0,66 (≥ 4,59:1) | WCAG AA | Decisión propia |
| DEV-09 | Eliminar desde el listado: sin animación ni deshacer | Sin animación de arrugado (como el prototipo), pero **con** el aviso "Deshacer" | Deshacer para toda eliminación | D7, ADR-0006 |
| DEV-10 | Sin aviso de deshacer tras arrugar | Aviso "Tarea eliminada · Deshacer" durante 6 s tras la animación | Deshacer | D7 |
| DEV-11 | "Todas mis tareas" deshabilitado con una sola tarea | Se mantiene, con la etiqueta accesible "Solo tienes esta tarea" | — (se documenta para no perderlo) | Prototipo |
| DEV-12 | El prototipo genera colores por `id % 5` | `colorKey` guardado con la tarea; misma regla de no repetir el color de la tarea actual | Estabilidad del color tras reordenar o restaurar | ADR-0002 |
| DEV-13 | Sin alternativa accesible para completar salvo Espacio/Enter mantenidos | Además: acción semántica "Completar" (VoiceOver/TalkBack) y confirmación | P6 | Decisión propia |
| DEV-14 | Reordenar solo arrastrando | Además: acciones semánticas "Mover arriba", "Mover abajo" y "Hacer actual" | P6 | Decisión propia |
| DEV-15 | Fuentes cargadas de Google Fonts | Fuentes empaquetadas en la app | P3/P4: sin red | Decisión propia |
| DEV-16 | Texto de ayuda en `textMuted` sobre las notas | Sobre las notas, el texto secundario va en `ink` | Contraste (rosa 4,0:1; neón < 3:1) | Decisión propia |
| DEV-17 | "Guardar" desactivado (opacidad 0,4) mientras el texto está vacío | "Guardar" siempre activo y con sombra; sin texto no guarda y devuelve el foco al campo | Así se ve en el diseño estático y lo pide el propietario | Propietario (2026-09-25) |
| DEV-18 | "+", menú y completar funcionan | Se ven activos pero no hacen nada hasta sus specs (007–009, 005 y 003) | Implementación por fases | Temporal, spec 001 |

