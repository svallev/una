# ADR-0017: El fallo del proceso de la página se gestiona envolviendo el `WebViewClient` de `webview_flutter`

- **Estado:** Aceptado (propietario, 2026-09-28: "a. La recomendación"; validado en el emulador en T-009-01)
- **Fecha:** 2026-09-28
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 009 (T-009-01, T-009-09, T-009-10), ADR-0007 (paquete `webview_flutter`; este ADR lo completa, no lo cambia), ADR-0016, plan de la 009 §4 y §7, modelo de amenazas T-4, riesgo R-21

## Contexto

- **[Hecho]** El plan de la 009 (§4) exigía comprobar, antes de construir nada, que un fallo del proceso de la página no cierra la app, y el §7 preveía, si fallaba, una WebView propia en Kotlin sin el paquete (enmendando el ADR-0007).
- **[Hecho]** T-009-01 (emulador Pixel_6a, API 37, WebView 149, `webview_flutter_android` 4.14.1): cargar `chrome://crash` **cierra la app**. El `WebViewClient` del paquete (`WebViewClientProxyApi.WebViewClientImpl`) no implementa `onRenderProcessGone`, y sin él Android mata el proceso de la app cuando muere el de la página.
- **[Hecho]** Un fallo así lo puede provocar cualquier página (un fallo de Chromium o que el sistema mate el proceso por memoria): con la tarea web como tarea actual, la app se cerraría cada vez que se abre.
- **[Hecho]** `minSdk` 26 permite `WebView.getWebViewClient()`, y `WebViewFlutterAndroidExternalApi.getWebView` (API pública y estable del paquete) da la instancia nativa.
- **[Hecho]** El paquete solo pone su cliente al crear la WebView y en `setNavigationDelegate` (`android_webview_controller.dart`); cualquier llamada posterior a `setNavigationDelegate` **quita el envoltorio** (comprobado en la sonda).

## Opciones consideradas

1. **(a) Seguir con el paquete y envolver su cliente desde Kotlin:** un `WebViewClient` que reenvía **todos** los callbacks al del paquete y solo añade `onRenderProcessGone` (devuelve `true`, avisa a Dart y la WebView se recrea).
2. **(b) WebView propia en Kotlin** (vista de plataforma con su `WebViewClient` y su `WebChromeClient`), sin el paquete.

## Decisión

Opción (a). El envoltorio se aplica por el canal `una/webview` **después** de `setNavigationDelegate`, se comprueba que quedó puesto (`webViewClient is` el envoltorio) y la app no vuelve a llamar a `setNavigationDelegate` sobre esa WebView. Tras el fallo, Dart crea un controlador y una WebView nuevos, y la vieja se destruye.

**Se revisa** en cada actualización de `webview_flutter_android` (repitiendo la prueba de `chrome://crash` y la de los callbacks) y si el paquete añade su propio `onRenderProcessGone`, en cuyo caso el envoltorio sobra.

## Motivos

- **[Hecho]** Validada en el emulador (T-009-01): con el envoltorio, `chrome://crash` no cierra la app (mismo proceso), llega `onRenderProcessGone(didCrash=true)`, se recrea la WebView (dos veces seguidas) y el `NavigationDelegate` de la nueva sigue recibiendo `onNavigationRequest`, `onPageStarted`, `onPageFinished`, `onWebResourceError` (DNS, conexión rechazada) y `onSslAuthError` (cancelar y seguir).
- Mucho menos código y riesgo que (b): se conservan la vista de plataforma, los ajustes, las decisiones de navegación y las comprobaciones 1, 2, 3 y 5 del plan §4, ya validadas con el paquete.
- El paquete sigue siendo el del ADR-0007 (oficial, mantenido).

## Consecuencias

- **Positivas:** un fallo de la página no cierra la app; la tarea puede mostrar la página de nuevo (T-009-10).
- **Negativas y riesgos:**
  - **Depende de detalles internos del paquete** (que su cliente sea el único y se ponga solo en esos dos sitios, y que reenviar los métodos del *framework* baste): una actualización podría romperlo en silencio. Mitigación: versión fijada (P11), comprobación de que el envoltorio está puesto cada vez que se aplica, y revalidación en cada actualización (riesgo **R-21** en `docs/PLAN.md`).
  - Si el paquete pasa a usar métodos nuevos del cliente, el envoltorio tiene que reenviarlos también.
  - La WebView destruida no se puede volver a usar: el estado de la página (T-009-10) tiene que soltarla del todo.
- **Pendiente:** implementar el envoltorio en `WebViewHardening.kt` (T-009-09) y la recreación en el `WebPageDriver`/`WebPageController` (T-009-10), con su prueba en el emulador.
- **Nota (2026-09-29, T-009-12, aceptada por el propietario):** el envoltorio ya no "solo añade `onRenderProcessGone`": también avisa a Dart, **antes** de pasar al paquete cada petición del marco principal (`shouldOverrideUrlLoading`), de si es una redirección del servidor (`WebResourceRequest.isRedirect`, que el paquete no da), **sin la dirección** (CL-009-9) y **sin cambiar lo que hace el paquete** (la petición se le reenvía igual y decide él). Sirve para que la carga inicial siga solo las redirecciones del servidor (ADR-0018, CL-009-1). La revalidación de R-21 incluye comprobar que ese aviso sigue llegando antes que el del paquete.
