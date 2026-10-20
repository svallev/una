import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_release_config.dart' as gate;

// La política real (`docs/legal/privacy-policy.md`, spec 023, T-023-05): su estructura, lo que tiene
// que decir (CA-023-02) y los nombres de permisos de la declaración de Data Safety (CA-023-08). El
// resto de la puerta (huecos y marcas) se prueba en `check_release_config_test.dart`; la comparación
// con la web, en `landing/test` (T-023-06).

const _esStart = '# Política de privacidad (ES)';
const _enStart = '# Privacy policy (EN)';
const _notes = '## Notas para la revisión';

String _read(String path) => File(path).readAsStringSync();

/// Las dos partes publicadas, sin cabecera ni notas.
({String es, String en}) _halves(String text) {
  final es = text.indexOf(_esStart);
  final en = text.indexOf(_enStart);
  final notes = text.indexOf(_notes);
  if (es < 0 || en < es || notes < en) {
    throw StateError('privacy-policy.md: faltan las dos partes o las notas');
  }
  return (es: text.substring(es, en), en: text.substring(en, notes));
}

/// Secciones `##` en orden, con el número de viñetas de cada una (anidadas incluidas).
List<({String title, int bullets})> _sections(String half) {
  final out = <({String title, int bullets})>[];
  String? title;
  var bullets = 0;
  for (final line in half.split('\n')) {
    if (line.startsWith('## ')) {
      if (title != null) out.add((title: title, bullets: bullets));
      title = line.substring(3).trim();
      bullets = 0;
    } else if (RegExp(r'^\s*[-*] ').hasMatch(line)) {
      bullets++;
    }
  }
  if (title != null) out.add((title: title, bullets: bullets));
  return out;
}

/// Filas de la tabla de permisos de `data-safety.md` §6: (permiso, ES, EN, lista blanca).
List<({String permission, String es, String en, String list})> _permissions() {
  final text = _read('../store/google-play/data-safety.md');
  final out = <({String permission, String es, String en, String list})>[];
  for (final line in text.split('\n')) {
    if (!line.startsWith('| android.permission.')) continue;
    final cells = [for (final c in line.split('|').skip(1)) c.trim()]
      ..removeLast();
    expect(cells, hasLength(4), reason: line);
    out.add((permission: cells[0], es: cells[1], en: cells[2], list: cells[3]));
  }
  return out;
}

void main() {
  final text = _read('../docs/legal/privacy-policy.md');
  final h = _halves(text);

  group('CA-023-03: español e inglés dicen lo mismo', () {
    test('CA-023-03: mismas secciones, en el mismo orden y con las mismas '
        'viñetas', () {
      final es = _sections(h.es);
      final en = _sections(h.en);
      expect(es, isNotEmpty);
      expect(es.length, en.length);
      expect([for (final s in es) s.bullets], [for (final s in en) s.bullets]);
    });

    test('CA-023-03: las secciones son las acordadas, ES y EN a la par', () {
      expect(
        [for (final s in _sections(h.es)) s.title],
        [
          'En pocas palabras',
          'Quién es el responsable',
          'Qué guarda la app y dónde',
          'Qué permisos usa',
          'Las notificaciones',
          'La tarea web',
          'Enlaces y otras apps',
          'Copias de seguridad',
          'Compartir con terceros',
          'Esta web',
          'Cuánto tiempo se guarda y cómo borrarlo',
          'Menores',
          'Tus derechos',
          'Cambios en esta política',
        ],
      );
      expect(
        [for (final s in _sections(h.en)) s.title],
        [
          'In short',
          'Who is responsible',
          'What the app stores and where',
          'What permissions it uses',
          'Notifications',
          'The web task',
          'Links and other apps',
          'Backups',
          'Sharing with third parties',
          'This website',
          'How long data is kept and how to delete it',
          'Children',
          'Your rights',
          'Changes to this policy',
        ],
      );
    });
  });

  group('CA-023-01: sin suposiciones', () {
    test('CA-023-01: el nombre de la app es {appName} en las dos partes', () {
      for (final half in [h.es, h.en]) {
        expect(half, contains('{appName}'));
        expect(half, isNot(contains('[NOMBRE DE LA APP]')));
        expect(half, isNot(contains('[APP NAME]')));
      }
    });

    test('CA-023-01: la cabecera ya no avisa de un borrador con suposiciones '
        'ni de [NOMBRE DE LA APP]', () {
      final header = text.substring(0, text.indexOf(_esStart));
      expect(header, isNot(contains('NOMBRE DE LA APP')));
      expect(header, isNot(contains('[Suposición]')));
    });

    test('CA-023-01: las notas de revisión dan la fuente de cada punto, con '
        'la fecha de consulta', () {
      final notes = text.substring(text.indexOf(_notes));
      expect(notes, contains('2026-10-20'));
      // Un punto numerado por tema de CA-023-02 (copia, residuo, autorrelleno, esta web…).
      expect(
        RegExp(r'^\d+\. ', multiLine: true).allMatches(notes).length,
        greaterThanOrEqualTo(15),
      );
      // Y ninguna nota deja una duda sin dueño: lo pendiente dice que es de F6.
      for (final line in notes.split('\n')) {
        if (line.contains('[Pendiente')) {
          expect(line, contains('F6'), reason: line);
        }
      }
    });
  });

  group('CA-023-02: cubre todo lo que hace la app', () {
    // Cada punto: un texto que tiene que estar en ES y otro en EN.
    final points = <String, (Pattern, Pattern)>{
      'notificaciones': (
        'Tienes una tarea pendiente',
        'You have a task waiting',
      ),
      'grupo de fotos sin etiqueta': (
        RegExp(r'grupo de fotos, solo «Tienes una tarea pendiente\.»'),
        RegExp(r'photo group, only "You have a task waiting\."'),
      ),
      'ajustes que viajan en la copia': (
        RegExp(
          r'idioma, pantalla siempre activa, bloquear zoom y los dos de las '
          r'notificaciones',
        ),
        RegExp(
          r'language, keep screen on, lock zoom and the two notification '
          r'settings',
        ),
      ),
      'la copia aparte de los avisos no viaja': (
        'copia aparte que la app guarda para reprogramar los avisos',
        'separate copy the app keeps to reschedule the reminders',
      ),
      'referente al abrir las webs': ('android-app://', 'android-app://'),
      'la app no envía nada al abrir las webs': (
        RegExp(r'La app no envía nada'),
        RegExp(r'The app sends nothing'),
      ),
      'Safe Browsing': ('Navegación segura de Google', 'Google Safe Browsing'),
      'autorrelleno': (
        RegExp(r'content-autofill|autorrelleno', caseSensitive: false),
        RegExp(r'autofill', caseSensitive: false),
      ),
      'firma del formulario, no lo escrito': (
        'no lo que escribes',
        'not what you type',
      ),
      'residuo de la WebView (redacción aprobada)': (
        'El sistema puede guardar en el espacio privado de la app el nombre de '
            'los sitios que has abierto como tarea web; no entra en las copias '
            'de seguridad y se borra al desinstalar la app',
        'The system may store in the app\'s private space the names of the '
            'sites you have opened as a web task; it isn\'t included in '
            'backups and is erased when you uninstall the app',
      ),
      'abrir en el navegador': ('Abrir en el navegador', 'Open in browser'),
      'enlaces de un PDF': ('mailto:', 'mailto:'),
      'tel:': ('tel:', 'tel:'),
      'red local': ('red local', 'local network'),
      'PDF con metadatos': (
        'con los metadatos que traigan',
        'whatever metadata they carry',
      ),
      'menores de 16': ('menores de 16 años', 'children under 16'),
      'registros del alojamiento': ('dirección IP', 'IP address'),
      'sin cookies ni analítica en las webs': (
        RegExp(r'sin cookies, sin analítica'),
        RegExp(r'no cookies, no analytics'),
      ),
      'el desarrollador no guarda los registros de las webs': (
        RegExp(r'no guarda ni consulta esos registros'),
        RegExp(r'neither keeps nor looks at those logs'),
      ),
      'procedimientos de manejo seguro': (
        RegExp(r'Cómo se protegen'),
        RegExp(r'How the data is protected'),
      ),
    };
    for (final e in points.entries) {
      test('CA-023-02: ES y EN dicen «${e.key}»', () {
        expect(h.es, contains(e.value.$1), reason: 'ES');
        expect(h.en, contains(e.value.$2), reason: 'EN');
      });
    }

    test('CA-023-02: «Cambios en esta política» ya no cita las notificaciones '
        'como ejemplo de algo futuro', () {
      String section(String half, String title) {
        final i = half.indexOf('## $title');
        final j = half.indexOf('\n## ', i + 1);
        return half.substring(i, j == -1 ? half.length : j);
      }

      expect(
        section(h.es, 'Cambios en esta política'),
        isNot(contains('notificaciones')),
      );
      expect(
        section(h.en, 'Changes to this policy'),
        isNot(contains('notifications')),
      );
    });

    test('CA-023-02: la política no promete lo que la app no hace', () {
      // Ni notas internas (PD-9) ni «comprobar con la guía» en el texto publicado.
      for (final half in [h.es, h.en]) {
        expect(half, isNot(contains('PD-9')));
        expect(half, isNot(contains('guía de Play')));
        expect(half, isNot(contains("Play's guidance")));
      }
    });
  });

  group('CA-023-08: los nombres de los permisos son los de Data Safety', () {
    test('CA-023-08: la tabla de data-safety.md tiene los cuatro permisos', () {
      final names = [for (final p in _permissions()) p.permission];
      expect(
        names,
        unorderedEquals([
          'android.permission.INTERNET',
          'android.permission.POST_NOTIFICATIONS',
          'android.permission.RECEIVE_BOOT_COMPLETED',
          'android.permission.ACCESS_LOCAL_NETWORK',
        ]),
      );
    });

    test(
      'CA-023-08: cada nombre de la tabla aparece tal cual en su idioma',
      () {
        for (final p in _permissions()) {
          expect(h.es, contains(p.es), reason: '${p.permission} (ES)');
          expect(h.en, contains(p.en), reason: '${p.permission} (EN)');
        }
      },
    );
  });

  group('CA-023-01: la política real con la puerta', () {
    test('CA-023-01: solo huecos de identidad, ninguno fuera de la lista', () {
      final found = gate.checkPolicyText(text);
      expect(
        found.map((i) => i.kind),
        everyElement(gate.GateIssueKind.policyGap),
      );
    });
  });
}
