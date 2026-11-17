# Referencia de la spec 027

`licenses-outside-notices.html` es `dist/licenses/index.html` construido desde `main` (`28793f2`, antes de la
spec 027) con el mundo de los tests (`world()` de `test/support.mjs`, sin `VERCEL_ENV`, con los archivos reales
del repositorio), quitando la única `<section lang="en" aria-labelledby="notices">…</section>` (la expresión
`/<section lang="en" aria-labelledby="notices">[\s\S]*?<\/section>/`, sustituida por nada). Se construyó dos
veces y salió igual. La usa CA-027-07: lo que hay fuera del bloque de avisos no cambia con la 027.

Si una spec posterior cambia a propósito algo de la página fuera de ese bloque, se regenera igual y se dice
en su commit.

`dist-files.txt` es la lista de archivos de `dist/` que construye el mundo de los tests desde `main` (`28793f2`):
`node build.mjs` en un *worktree* con los `node_modules` de la rama, quitando lo que solo hace Vite (la página de
inicio, que el mundo no construye: `index.html`, `assets/`, `favicon.png`, `img/` y las `.woff2`); la lista entera
salió igual que la de la rama, también los nombres de `assets/`. `vercel-main.json` es `landing/vercel.json` de ese
mismo `main`. Los usa CA-027-04: la 027 no añade archivos ni cambia las cabeceras (CSP incluida).
