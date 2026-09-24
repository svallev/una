---
name: adr-new
description: Registra una decisión de arquitectura nueva (docs/adr/NNNN-titulo.md) desde la plantilla del proyecto. Úsala cuando se elija entre alternativas técnicas, se cambie una decisión anterior o un plan.md lo requiera.
argument-hint: "<título de la decisión>"
---

# Escribir un ADR

1. Siguiente número de 4 dígitos en `docs/adr/`. Archivo `NNNN-titulo-en-kebab.md` desde `docs/adr/0000-template.md`.
2. **Contexto** con etiquetas **[Hecho] / [Suposición] / [Pendiente]**. Verifica con documentación actual (Context7) los hechos sobre librerías, versiones y plataformas, y cita la fecha de la consulta.
3. **Al menos dos opciones reales**, con criterios explícitos (matriz ponderada si hay ≥ 3 criterios relevantes). Comprueba la suma de la matriz.
4. **Decisión** en 1–2 frases, las condiciones para revisarla y su estado (Propuesto / Provisional / Aceptado).
5. **Consecuencias:** positivas, negativas con su mitigación, y riesgos que haya que añadir al registro de `docs/PLAN.md`.
6. Si sustituye a otro ADR: marca el anterior como "Sustituido por ADR-NNNN" (es el único cambio permitido en un ADR aceptado).
7. Añade la fila a `docs/adr/README.md`.
8. Pide al usuario que acepte el ADR si la decisión es de producto o irreversible.
