import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../entities/attachment.dart';
import '../entities/notification_settings.dart';
import '../entities/task.dart';
import 'host_display.dart';

/// El texto de las notificaciones de iOS, calculado en Dart (spec 028,
/// CA-028-16, ADR-0030): port de `TaskLabel.kt` y `NotificationText.kt` de la
/// 019 (en Android lo calcula Kotlin al llegar la hora; en iOS se programa por
/// adelantado, así que se calcula aquí, con los textos de los ARB).

/// Una fila de adjunto como la lee `TaskLabel.kt`: tipo y origen **como texto**
/// (`image`, `camera`…; `null` si faltan o son ilegibles) y la dirección.
@immutable
class NotificationAttachmentRow {
  const NotificationAttachmentRow(this.kind, this.origin, this.url);

  /// Desde un [Attachment] leído de la BD: uno marcado como ilegible (tipo u
  /// origen desconocidos, CA-016-25) no tiene tipo.
  factory NotificationAttachmentRow.of(Attachment a) =>
      NotificationAttachmentRow(
        a.unreadable ? null : a.kind.name,
        a.unreadable ? null : a.origin.name,
        a.url,
      );

  final String? kind;
  final String? origin;
  final String? url;
}

/// La etiqueta de la tarea en la notificación (CA-019-16, D25). «Foto»,
/// «Imagen» y «PDF» van como tipo y se traducen al construir el texto; el
/// texto de la tarea y el dominio se dejan tal como están escritos.
@immutable
sealed class NotificationLabel {
  const NotificationLabel();

  /// Letras visibles del texto antes del «…» (Q-019-9).
  static const maxLetters = 120;

  static const ellipsis = '\u2026';

  /// La etiqueta de una tarea con [body] y [rows], o `null` si no la tiene (la
  /// notificación dice entonces lo mismo que la genérica): un grupo de fotos,
  /// una mezcla rara, un adjunto de tipo u origen desconocido o una web sin
  /// dirección legible, siempre sin texto. **El texto manda sobre cualquier
  /// adjunto**, también web.
  static NotificationLabel? of(
    String? body,
    List<NotificationAttachmentRow> rows,
  ) {
    final text = _cleanText(body);
    if (text.isNotEmpty) return NotificationTextLabel(_truncate(text));
    if (rows.length != 1) return null;
    final row = rows.single;
    return switch ((row.kind, row.origin)) {
      ('image', 'camera') => const NotificationPhotoLabel(),
      ('image', 'gallery') => const NotificationImageLabel(),
      ('pdf', 'file') => const NotificationPdfLabel(),
      ('web', 'url') => switch (webAddressHost(row.url)) {
        final host? => NotificationDomainLabel(host),
        null => null,
      },
      _ => null,
    };
  }

  /// La etiqueta de [task] (`null` sin tarea).
  static NotificationLabel? ofTask(Task? task) => task == null
      ? null
      : of(task.text, [
          for (final a in task.attachments) NotificationAttachmentRow.of(a),
        ]);
}

/// El texto del usuario, ya sin saltos de línea y recortado.
final class NotificationTextLabel extends NotificationLabel {
  const NotificationTextLabel(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      other is NotificationTextLabel && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'NotificationTextLabel(${value.length})';
}

final class NotificationPhotoLabel extends NotificationLabel {
  const NotificationPhotoLabel();
}

final class NotificationImageLabel extends NotificationLabel {
  const NotificationImageLabel();
}

final class NotificationPdfLabel extends NotificationLabel {
  const NotificationPdfLabel();
}

/// El dominio de una tarea web, como en la barra de la tarea
/// ([webAddressHost]).
final class NotificationDomainLabel extends NotificationLabel {
  const NotificationDomainLabel(this.host);
  final String host;

  @override
  bool operator ==(Object other) =>
      other is NotificationDomainLabel && other.host == host;

  @override
  int get hashCode => host.hashCode;

  @override
  String toString() => 'NotificationDomainLabel($host)';
}

/// Saltos de línea de `TaskLabel.kt` (`isBreak`).
bool _isBreak(int c) =>
    c == 0x0A ||
    c == 0x0D ||
    c == 0x0B ||
    c == 0x0C ||
    c == 0x85 ||
    c == 0x2028 ||
    c == 0x2029;

/// `Char.isWhitespace()` de Kotlin (no el `trim` de Dart, que también quita
/// U+0085 y U+FEFF): separadores de espacio, de línea y de párrafo, y los
/// controles `\t`, `\n`, U+000B, `\f`, `\r` y U+001C a U+001F.
bool _isWhitespace(int c) =>
    (c >= 0x09 && c <= 0x0D) ||
    (c >= 0x1C && c <= 0x20) ||
    c == 0xA0 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200A) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000;

/// El texto en una línea: cada tramo con saltos de línea (y los espacios que
/// lo rodean) pasa a un espacio, y sin espacios en los extremos. Solo espacios
/// o saltos = `''` (sin texto).
String _cleanText(String? body) {
  if (body == null) return '';
  final out = <int>[];
  var i = 0;
  final units = body.codeUnits;
  while (i < units.length) {
    final c = units[i];
    if (_isBreak(c)) {
      // Los espacios de antes del salto sobran; los de después se saltan.
      while (out.isNotEmpty && _isWhitespace(out.last)) {
        out.removeLast();
      }
      while (i < units.length &&
          (_isBreak(units[i]) || _isWhitespace(units[i]))) {
        i++;
      }
      out.add(0x20); // un espacio sobrante en un extremo lo quita el final
    } else {
      out.add(c);
      i++;
    }
  }
  var start = 0;
  var end = out.length;
  while (start < end && _isWhitespace(out[start])) {
    start++;
  }
  while (end > start && _isWhitespace(out[end - 1])) {
    end--;
  }
  return String.fromCharCodes(out, start, end);
}

/// Hasta 120 letras completas (un emoji con ZWJ, una letra con su acento o una
/// bandera son una) y «…» si sobra alguna (CL-019-13).
String _truncate(String text) {
  // Hasta 120 unidades UTF-16 no puede haber más de 120 letras.
  if (text.length <= NotificationLabel.maxLetters) return text;
  final letters = text.characters;
  if (letters.length <= NotificationLabel.maxLetters) return text;
  return '${letters.take(NotificationLabel.maxLetters)}'
      '${NotificationLabel.ellipsis}';
}

/// Los textos fijos de la notificación en el idioma de la app (los mismos
/// ARB que la app y que los `strings.xml` de Android, CA-019-21 y 27).
@immutable
class NotificationTexts {
  const NotificationTexts({
    required this.title,
    required this.publicBody,
    required this.photo,
    required this.image,
    required this.pdf,
  });

  /// `notificationTitle`: «Tarea actual».
  final String title;

  /// `notificationPublic`: «Tienes una tarea pendiente.», la versión genérica.
  final String publicBody;

  /// `attachmentPhoto`, `attachmentImage`, `attachmentPdf`.
  final String photo;
  final String image;
  final String pdf;

  /// El cuerpo de la notificación con [label]; sin etiqueta, el genérico.
  String bodyFor(NotificationLabel? label) => switch (label) {
    null => publicBody,
    NotificationTextLabel(:final value) => value,
    NotificationDomainLabel(:final host) => host,
    NotificationPhotoLabel() => photo,
    NotificationImageLabel() => image,
    NotificationPdfLabel() => pdf,
  };
}

/// Un aviso diario programado en iOS (`channel-contract.md` §4): la hora local
/// y sus textos. [publicBody] es lo que enseña la pantalla de bloqueo con las
/// previsualizaciones ocultas (CA-019-17): nunca lleva nada de la tarea.
@immutable
class NotificationSlot {
  const NotificationSlot({
    required this.time,
    required this.title,
    required this.body,
    required this.publicBody,
  });

  final NotificationTime time;
  final String title;
  final String body;
  final String publicBody;

  @override
  bool operator ==(Object other) =>
      other is NotificationSlot &&
      other.time == time &&
      other.title == title &&
      other.body == body &&
      other.publicBody == publicBody;

  @override
  int get hashCode => Object.hash(time, title, body, publicBody);

  // Sin el texto de la tarea (CA-019-23): solo la hora.
  @override
  String toString() => 'NotificationSlot(${time.label})';
}

/// Los avisos que hay que programar (CA-028-15 y 16): ninguno con el ajuste
/// apagado o sin tarea actual (CA-019-15); si no, uno por cada hora de
/// [perDay] (08:55, 13:55 y 18:55, CA-019-10) con el texto de [task].
List<NotificationSlot> notificationSlots({
  required bool on,
  required NotificationsPerDay perDay,
  required Task? task,
  required NotificationTexts texts,
}) {
  if (!on || task == null) return const [];
  final body = texts.bodyFor(NotificationLabel.ofTask(task));
  return [
    for (final time in perDay.times)
      NotificationSlot(
        time: time,
        title: texts.title,
        body: body,
        publicBody: texts.publicBody,
      ),
  ];
}
