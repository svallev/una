# Registro de decisiones de arquitectura (ADR)

Formato MADR simplificado ([plantilla](0000-template.md)). Nuevos ADR con la skill `/adr-new`. Un ADR aceptado no se edita: se sustituye por otro.

| ADR | Título | Estado |
|---|---|---|
| [0001](0001-stack-tecnologico.md) | Flutter como stack de la app | Aceptado para Android; provisional para iOS |
| [0002](0002-almacenamiento-y-modelo-de-datos.md) | SQLite (drift) tras un repositorio, con migraciones comprobadas | Aceptado |
| [0003](0003-estructura-sdd.md) | SDD con estructura propia ligera, compatible con Spec Kit | Aceptado |
| [0004](0004-copias-de-seguridad.md) | Incluir los datos en las copias de seguridad del sistema | Aceptado, revisado tras S5 (BackupAgent con presupuesto) |
| [0005](0005-cifrado-en-reposo.md) | Sin cifrado propio de la BD en la v1 | Aceptado |
| [0006](0006-eliminacion-y-deshacer.md) | Eliminar: borrado lógico + deshacer 6 s + purga | Aceptado |
| [0007](0007-url-sin-conexion.md) | URL: WebView endurecida + captura de página completa | Aceptado para Android (S4) |
| [0008](0008-visor-de-documentos.md) | PDF dentro; el resto, con el visor del sistema | Aceptado para Android (S3) |
| [0009](0009-monorepo-y-landing.md) | Monorepo: `app/` y `landing/` | Aceptado |
| [0010](0010-vercel-web-de-pruebas.md) | Web de pruebas en Vercel | Aceptado (S6 en local) |
