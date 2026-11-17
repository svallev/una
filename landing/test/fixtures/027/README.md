# Referencia de la spec 027

`licenses-outside-notices.html` es `dist/licenses/index.html` construido desde `main` (`28793f2`, antes de la
spec 027) con el mundo de los tests (`world()` de `test/support.mjs`, sin `VERCEL_ENV`, con los archivos reales
del repositorio), quitando la única `<section lang="en" aria-labelledby="notices">…</section>` (la expresión
`/<section lang="en" aria-labelledby="notices">[\s\S]*?<\/section>/`, sustituida por nada). Se construyó dos
veces y salió igual. La usa CA-027-07: lo que hay fuera del bloque de avisos no cambia con la 027.

Si una spec posterior cambia a propósito algo de la página fuera de ese bloque, se regenera igual y se dice
en su commit.
