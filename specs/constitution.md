# Constitución del proyecto

> Principios que **no se negocian**. Toda spec, plan, tarea y PR se revisa contra este documento.
> Para cambiarlo hace falta un ADR que lo justifique y la aprobación explícita del propietario del producto.
> Versión 1.0 · 2026-09-24

## Principios

### P1. Una tarea a la vez
La pantalla principal muestra **solo** la primera tarea pendiente. Ver el resto requiere al menos dos interacciones (menú → "Todas mis tareas"). Ninguna funcionalidad futura (fechas, "hoy", subtareas) puede romper esto sin una decisión de producto explícita registrada en un ADR.

### P2. Instantáneo al abrir
Abrir la app lleva directamente a la tarea actual, a pantalla completa, sin toques extra. Presupuesto: **< 1 s** desde el arranque en frío hasta ver la tarea actual (Android de gama media, compilación *release*). Todo lo que retrase ese momento (inicializaciones, animaciones, migraciones pesadas) se difiere o se justifica.

### P3. Local y sin conexión
Sin servidor, sin cuentas y sin login. Todo funciona en modo avión. Los adjuntos se **copian** dentro de la app: nunca se guardan referencias a archivos externos que pueden desaparecer.

### P4. Privacidad por defecto
Cero red por defecto: sin analítica, sin informes de errores y sin SDK de terceros que envíen datos. La única conexión permitida es la carga de una URL que el usuario ha pedido ver. Objetivo: declarar **"Data Not Collected"** en ambas tiendas. Cualquier excepción futura será opcional, con consentimiento explícito y con su ADR.

### P5. Seguridad desde el diseño
Referencia: OWASP MASVS/MASTG. Todo archivo o URL importado se considera **no confiable**. Permisos mínimos y solicitados solo en el momento de usarlos. Ningún secreto en el repositorio. La checklist de `docs/security/checklist.md` forma parte de la Definition of Done.

### P6. Accesible siempre
WCAG 2.2 AA como mínimo. Toda acción por gesto (mantener pulsado, arrastrar, doble toque) tiene una alternativa accesible para lector de pantalla, teclado y switch. Se respetan "reducir movimiento", el texto dinámico y los objetivos táctiles de **≥ 44 pt**.

### P7. i18n desde el primer día
No hay textos incrustados en el código. Todos los textos (incluidos fechas, plurales y etiquetas de accesibilidad) salen de los archivos de traducción, en español y en inglés. El nombre de la app está centralizado y no aparece en el código, las rutas ni los identificadores.

### P8. La especificación manda (SDD)
Flujo obligatorio por funcionalidad: **spec** (qué y por qué, sin tecnología) → **plan** (cómo) → **tareas** → implementación → verificación contra los criterios de aceptación. El código que contradiga una spec es un bug; si la spec está mal, se corrige primero la spec.

### P9. Nada está hecho sin tests
Ninguna tarea se da por terminada sin tests que prueben sus criterios de aceptación. La lógica de dominio (cola, orden, estados) tiene tests unitarios; las migraciones de datos, tests de migración; los flujos principales, tests de integración.

### P10. Preparado para crecer, sin construir el futuro
El modelo de datos y la capa de persistencia no deben impedir la hoja de ruta (fechas, subtareas, importación, sincronización), pero **no se implementa** nada que la v1 no necesite. Las funcionalidades a medio hacer quedan tras un *feature flag* desactivado.

### P11. Dependencias con criterio
Cada dependencia nueva se justifica: mantenimiento activo, licencia compatible, sin telemetría, tamaño razonable y ninguna alternativa razonable en la plataforma. Versiones fijadas con lockfile. **Skills, plugins y servidores MCP solo a nivel de proyecto**, revisados antes de instalarlos y nunca con confirmación automática.

### P12. El diseño del prototipo es la referencia visual
La identidad visual del prototipo (notas adhesivas, bordes marcados, sombras duras, Archivo + Space Mono) manda sobre los componentes base. Los valores salen **solo** de `design/tokens.json`. Cualquier desviación del prototipo se registra en `docs/design/prototype-deviations.md`.

## Definition of Done (común a toda tarea o PR)

- [ ] Se cumplen los criterios de aceptación de la spec (Dado/Cuando/Entonces), con referencia a su ID.
- [ ] Tests nuevos o actualizados pasando en CI (unitarios, widgets o integración según corresponda).
- [ ] `format`, `analyze` y todos los jobs de CI en verde.
- [ ] Checklist de seguridad (`docs/security/checklist.md`) revisada: puntos aplicables marcados.
- [ ] Revisión de accesibilidad: semántica, alternativas a gestos, contraste, texto dinámico y reducir movimiento.
- [ ] Todos los textos nuevos en `es` y `en`; ninguno incrustado en el código.
- [ ] Sin valores visuales sueltos: todo sale de los tokens.
- [ ] Documentación actualizada (spec, ADR, glosario o arquitectura, si cambian).
- [ ] Rendimiento: el arranque en frío no se degrada (en las PR que tocan el arranque se mide).
- [ ] PR con título en formato Conventional Commits.

## Gobierno

- **Propietario del producto:** decide sobre alcance, textos y desviaciones del prototipo.
- **Decisiones técnicas:** se documentan en `docs/adr/` (formato MADR simplificado). Un ADR aceptado solo se cambia con otro ADR que lo sustituya.
- **Hechos, suposiciones y pendientes:** todo documento los distingue con las etiquetas **[Hecho]**, **[Suposición]** y **[Pendiente]**.
