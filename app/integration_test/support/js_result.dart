import 'package:webview_flutter/webview_flutter.dart';

/// El resultado de [script] en [web] como texto, igual en las dos plataformas
/// (spec 028, CA-028-19): Android devuelve siempre JSON en un texto (`"a"`,
/// `7`, `true`, `null`); iOS, el valor ya decodificado (`a`, `7.0`, `1`,
/// `<null>`). Sin las comillas de un texto, un número entero sin decimales y
/// un `null` (o `undefined`) de JavaScript como `null`: en iOS, el paquete
/// lanza `ArgumentError` si el resultado es `undefined`.
Future<String> jsText(WebViewController web, String script) async {
  try {
    return jsResultText(await web.runJavaScriptReturningResult(script));
  } on ArgumentError {
    return 'null';
  }
}

String jsResultText(Object? raw) {
  if (raw is bool) return '$raw';
  if (raw is num) return raw == raw.truncate() ? '${raw.toInt()}' : '$raw';
  final text = '$raw';
  if (text == '<null>') return 'null';
  return text.length >= 2 && text.startsWith('"') && text.endsWith('"')
      ? text.substring(1, text.length - 1)
      : text;
}
