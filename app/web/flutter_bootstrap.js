{{flutter_js}}
{{flutter_build_config}}

// Sin fuentes remotas (P4, ADR-0010): las fuentes de respaldo (emojis, otros
// alfabetos) se buscan en el propio dominio, nunca en fonts.gstatic.com.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: "assets/fonts/fallback/",
  },
});
