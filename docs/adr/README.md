# Registro de decisiones de arquitectura (ADR)

Formato MADR simplificado ([plantilla](0000-template.md)). Nuevos ADR con la skill `/adr-new`. Un ADR aceptado no se edita: se sustituye por otro.

| ADR | Título | Estado |
|---|---|---|
| [0001](0001-stack-tecnologico.md) | Flutter como stack de la app | Aceptado para Android; provisional para iOS |
| [0002](0002-almacenamiento-y-modelo-de-datos.md) | SQLite (drift) tras un repositorio, con migraciones comprobadas | Aceptado |
| [0003](0003-estructura-sdd.md) | SDD con estructura propia ligera, compatible con Spec Kit | Aceptado |
| [0004](0004-copias-de-seguridad.md) | Incluir los datos en las copias de seguridad del sistema | Aceptado, revisado tras S5 (BackupAgent con presupuesto) |
| [0005](0005-cifrado-en-reposo.md) | Sin cifrado propio de la BD en la v1 | Aceptado |
| [0006](0006-eliminacion-y-deshacer.md) | Eliminar: borrado lógico + deshacer 6 s + purga | Sustituido por ADR-0011 |
| [0007](0007-url-sin-conexion.md) | URL: WebView endurecida + captura de página completa | Aceptado para Android (S4); enmendado por ADR-0016 (sin captura) y ADR-0018 (sin navegación); completado por ADR-0017 |
| [0008](0008-visor-de-documentos.md) | PDF dentro; el resto, con el visor del sistema | Aceptado para Android (S3); enmendado por ADR-0014 (v1: solo PDF) |
| [0009](0009-monorepo-y-landing.md) | Monorepo: `app/` y `landing/` | Aceptado |
| [0010](0010-vercel-web-de-pruebas.md) | Web de pruebas en Vercel | Aceptado (S6 en local) |
| [0011](0011-eliminar-sin-deshacer.md) | Eliminar es definitivo (sin deshacer), con marca de borrado sin contenido | Sustituido por ADR-0012 |
| [0012](0012-sin-historico.md) | Sin histórico: completar y eliminar borran la tarea del todo | Aceptado |
| [0013](0013-sin-visor-de-imagenes.md) | Sin visor de imágenes: la imagen se ve y se amplía en la propia tarea | Aceptado (excepción a P6) |
| [0014](0014-solo-pdf-en-la-v1.md) | En la v1 solo se adjuntan PDF, que se ven, giran y se amplían en la propia tarea | Aceptado; enmendado por ADR-0015 (sin "Volver a vertical") |
| [0015](0015-sin-volver-a-vertical.md) | Sin "Volver a vertical": la tarea con adjunto vuelve a vertical solo al girar el móvil | Aceptado (excepción a P6 sin el botón) |
| [0016](0016-web-sin-copia-local.md) | Tarea web sin copia local: se guarda solo la dirección y la página se carga en vivo cada vez | Aceptado (excepción a P3); enmienda el ADR-0007 y sustituye a D9 |
| [0017](0017-webview-fallo-del-proceso.md) | El fallo del proceso de la página se gestiona envolviendo el `WebViewClient` de `webview_flutter` | Aceptado (T-009-01); completa el ADR-0007 |
| [0018](0018-web-sin-navegacion.md) | Tarea web sin navegación: solo se ve la página de la dirección guardada | Aceptado (2026-09-29); enmienda el ADR-0007 y el ADR-0016 |
