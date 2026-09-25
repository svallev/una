# Tareas — Spec 003: Completar la tarea actual

Requisitos: spec 001 implementada ✅; spec 003 y este plan **aprobados**. `[P]` = puede hacerse en paralelo con la anterior.

| ID | Tarea | Depende de | Verificación | CA |
|---|---|---|---|---|
| T-003-01 | Dominio: `Task.complete`, puerto `complete`/`hasCompleted`, caso de uso `CompleteCurrentTask` | — | Unitarios | 03a, 06 |
| T-003-02 | Repositorios drift y memoria + tests de contrato | 01 | Contrato verde en ambas | 03a, 06, CL-1 |
| T-003-03 [P] | Textos ES/EN de §7 y tokens de tiempos del prototipo que falten | — | Test de consistencia l10n; `validate-tokens` | — |
| T-003-04 | `HoldToCompleteButton`: relleno, retroceso, teclado, multitoque, acción semántica, sin doble toque | 03 | Widget con reloj de pruebas | 01, 02, 07, 08, CL-3, CL-6 |
| T-003-05 | `CompletionController` (fases, guardado antes de animar, bloqueo, error con reintento, vibración) | 01, 02 | Widget | 03a, 09, 12 |
| T-003-06 | Rotura en dos mitades (`ClipPath`, curva `tear`) + enhorabuena (sello, títulos, confeti, "siguiente") + reducir movimiento | 05 | Widget + *goldens* | 03b, 04, CL-5, CL-7 |
| T-003-07 | "Todo hecho." + enrutado (`hasCompleted` en el arranque) + "Crear una tarea" como ruta con color al azar | 05 | Enrutado | 05, 10, 11 |
| T-003-08 | Accesibilidad: anuncio único, foco a la siguiente, 4 s con lector | 05–07 | Widget (semántica) + TalkBack manual | 07, 13 |
| T-003-09 | Integración en dispositivo y medida de fluidez de la rotura | 04–08 | `integration_test` verde; FrameTiming en el Xiaomi | todos |
| T-003-10 | Revisiones (spec, a11y, seguridad), quitar "completar" de DEV-18, *goldens* en Linux | 01–09 | Hallazgos resueltos | DoD |

## Cierre

- [ ] Todos los CA-003 con test en verde.
- [ ] Definition of Done completa (CI, revisiones, prueba en el Xiaomi).
- [ ] Spec marcada como **Implementada**.
