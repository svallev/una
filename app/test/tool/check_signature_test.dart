import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_signature.dart';
import '../support/aab_support.dart';

/// La firma del paquete (spec 020, T-020-06; plan §3.2, id `signature`): `apksigner verify` en el APK
/// y `jarsigner -verify -strict` + `keytool -printcert -jarfile` en el AAB. Sin firma o con el
/// certificado de depuración es un **aviso de identidad** (CA-020-05 d); una firma que no verifica
/// (alterada, caducada), un fallo. Las salidas de las herramientas son las reales
/// (`test/tool/fixtures/signature/`); las herramientas, scripts de mentira.
const _fx = 'test/tool/fixtures/signature';

String _read(String name) => File('$_fx/$name').readAsStringSync();

const _debugSha =
    'd3a133c7c0f3db537c81d9eaaf58bc47482c52c145dbd3b5a95a448babaf179d';

/// La huella de un certificado de la cadena (no el de la hoja).
const _chainSha =
    'AA:BB:CC:DD:AA:BB:CC:DD:AA:BB:CC:DD:AA:BB:CC:DD:AA:BB:CC:DD:AA:BB:CC:DD:AA:BB:CC:DD:AA:BB:CC:DD';

/// Una huella SHA-256 de prueba que no es la de depuración.
const _ownSha =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

String _colons(String hex) => [
  for (var i = 0; i < hex.length; i += 2) hex.substring(i, i + 2).toUpperCase(),
].join(':');

String _keytoolFor(String cn, String sha) =>
    _read('keytool_debug.txt')
        .replaceAll('CN=Android Debug', 'CN=$cn')
        .replaceAll(_colons(_debugSha), _colons(sha));

String _apksignerFor(String cn, String sha) =>
    _read('apksigner_debug.txt')
        .replaceAll('CN=Android Debug', 'CN=$cn')
        .replaceAll(_debugSha, sha);

bool _realTool(String name, List<String> args) {
  try {
    return Process.runSync(name, args).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  group('CA-020-03 (e): lo que dicen las herramientas (parsers)', () {
    test('CA-020-03: apksigner con la firma de depuración: un firmante', () {
      final r = parseApksigner(_read('apksigner_debug.txt'), 0);
      expect(r, isA<SignedPackage>());
      final signers = (r as SignedPackage).signers;
      expect(signers, hasLength(1));
      expect(signers.single.dn, 'C=US, O=Android, CN=Android Debug');
      expect(signers.single.sha256, _debugSha);
      expect(isDebugDn(signers.single.dn), isTrue);
    });

    test('CA-020-03: apksigner sin firma: sin firmar', () {
      expect(
        parseApksigner(_read('apksigner_unsigned.txt'), 1),
        isA<UnsignedPackage>(),
      );
    });

    test('CA-020-03: apksigner con la firma alterada: no verifica, con el '
        'motivo', () {
      final r = parseApksigner(_read('apksigner_corrupt.txt'), 1);
      expect(r, isA<InvalidSignature>());
      expect(
        (r as InvalidSignature).reason,
        contains('integrity check failed'),
      );
    });

    test('CA-020-03: apksigner con otro error además de «sin firma»: no '
        'verifica (no es solo sin firmar)', () {
      const out =
          'DOES NOT VERIFY\nERROR: Missing META-INF/MANIFEST.MF\nERROR: otra cosa\n';
      expect(parseApksigner(out, 1), isA<InvalidSignature>());
    });

    test('CA-020-03: apksigner ilegible, o código ≠ 0 sin el aviso, o código 0 '
        'sin firmantes: no verifica (falla cerrada)', () {
      expect(parseApksigner('', 0), isA<InvalidSignature>());
      expect(parseApksigner('', 1), isA<InvalidSignature>());
      expect(parseApksigner('algo raro\n', 2), isA<InvalidSignature>());
      expect(
        parseApksigner(_read('apksigner_debug.txt'), 1),
        isA<InvalidSignature>(),
        reason: 'código 1 con firmantes legibles: no se fía',
      );
    });

    test('CA-020-03: jarsigner con firma autofirmada («with signer errors»): '
        'verifica', () {
      expect(
        parseJarsigner(_read('jarsigner_debug.txt')),
        isA<SignedPackage>(),
      );
    });

    test('CA-020-03: jarsigner «jar verified.» a secas: verifica', () {
      expect(parseJarsigner('jar verified.\n'), isA<SignedPackage>());
    });

    test('CA-020-03: jarsigner sin firma: sin firmar', () {
      expect(
        parseJarsigner(_read('jarsigner_unsigned.txt')),
        isA<UnsignedPackage>(),
      );
    });

    test('CA-020-03: jarsigner con un resumen que no cuadra: no verifica', () {
      final r = parseJarsigner(_read('jarsigner_corrupt.txt'));
      expect(r, isA<InvalidSignature>());
      expect((r as InvalidSignature).reason, contains('digest error'));
    });

    test('CA-020-03: jarsigner con un certificado caducado o aún no válido: '
        'no verifica', () {
      for (final problem in [
        'This jar contains entries whose signer certificate has expired.',
        'This jar contains entries whose signer certificate is not yet valid.',
      ]) {
        final out =
            'jar verified, with signer errors.\n\nError: \n$problem\n\nWarning: \nx\n';
        expect(parseJarsigner(out), isA<InvalidSignature>(), reason: problem);
      }
    });

    test('CA-020-03: jarsigner con un error de cadena Y uno desconocido: no '
        'verifica', () {
      const out =
          'jar verified, with signer errors.\n\nError: \n'
          'This jar contains entries whose certificate chain is invalid. Reason: x\n'
          'This jar contains entries whose signer certificate is self-signed.\n'
          'Algo nuevo que no conocemos.\n\nWarning: \nx\n';
      expect(parseJarsigner(out), isA<InvalidSignature>());
    });

    test('CA-020-03: jarsigner ilegible o vacío: no verifica', () {
      expect(parseJarsigner(''), isA<InvalidSignature>());
      expect(parseJarsigner('lo que sea\n'), isA<InvalidSignature>());
    });

    test('CA-020-03: keytool da el sujeto y el SHA-256 del primer certificado '
        'de cada firmante', () {
      final signers = parseKeytool(_read('keytool_debug.txt'));
      expect(signers, hasLength(1));
      expect(signers.single.dn, 'C=US, O=Android, CN=Android Debug');
      expect(signers.single.sha256, _debugSha);
    });

    test('CA-020-03: keytool con dos firmantes y una cadena: uno por firmante, '
        'con el certificado de la hoja', () {
      final one = _read('keytool_debug.txt');
      final text = [
        one,
        one
            .replaceFirst('Signer #1:', 'Signer #2:')
            .replaceAll('CN=Android Debug', 'CN=Otro')
            .replaceAll(_colons(_debugSha), _colons(_ownSha)),
      ].join('\n');
      // Un segundo certificado (de la cadena) en el primer firmante no cuenta como firmante.
      final chained = text.replaceFirst(
        'Signer #2:',
        'Certificate #2:\nOwner: CN=Raíz\nCertificate fingerprints:\n\t SHA256: ${_colons(_ownSha)}\n\nSigner #2:',
      );
      final signers = parseKeytool(chained);
      expect(signers.map((s) => s.sha256), [_debugSha, _ownSha]);
      expect(signers.map((s) => s.dn).last, contains('CN=Otro'));
    });

    test('CA-020-03: keytool: si el primer certificado no trae SHA-256 no se '
        'toma el de la cadena (el firmante no sale)', () {
      const text =
          '''
Signer #1:

Certificate #1:
Owner: CN=Hoja
Certificate fingerprints:
\t SHA1: 2A:B9

Certificate #2:
Owner: CN=Raíz
Certificate fingerprints:
\t SHA256: $_chainSha
''';
      expect(parseKeytool(text), isEmpty);
    });

    test('CA-020-03: apksigner con un firmante sin huella legible: no verifica '
        '(no se descarta en silencio)', () {
      final text = [
        'Signer #1 certificate DN: CN=Uno',
        'Signer #1 certificate SHA-256 digest: $_ownSha',
        'Signer #2 certificate DN: CN=Dos',
      ].join('\n');
      expect(parseApksigner(text, 0), isA<InvalidSignature>());
    });

    test('CA-020-03: keytool sin firmantes: lista vacía', () {
      expect(parseKeytool('Not a signed jar file\n'), isEmpty);
      expect(parseKeytool(''), isEmpty);
    });

    test('CA-020-03: «Android Debug» solo cuenta como atributo CN exacto', () {
      expect(isDebugDn('C=US, O=Android, CN=Android Debug'), isTrue);
      expect(isDebugDn('CN=Android Debug'), isTrue);
      expect(isDebugDn('CN=Android Debug, O=X'), isTrue);
      expect(isDebugDn('CN=Android Debugger'), isFalse);
      expect(isDebugDn('O=CN=Android Debug'), isFalse);
      expect(isDebugDn('CN=Mi Empresa, O=Android Debug'), isFalse);
    });

    test('CA-020-03: la huella del certificado de subida: acepta mayúsculas, '
        'dos puntos y comentarios; rechaza lo demás', () {
      final ok = parseUploadCert(
        '# huella pública\n${_colons(_ownSha)}\n\n$_debugSha # otra\n',
      );
      expect(ok, {_ownSha, _debugSha});
      expect(() => parseUploadCert('abc\n'), throwsFormatException);
      expect(
        () => parseUploadCert('# solo comentarios\n'),
        throwsFormatException,
      );
      expect(() => parseUploadCert(''), throwsFormatException);
      expect(
        () => parseUploadCert('${_ownSha}00\n'),
        throwsFormatException,
        reason: 'más larga que un SHA-256',
      );
    });
  });

  group('CA-020-03 (e), CA-020-05 (d): la herramienta entera (herramientas '
      'de mentira)', () {
    final skip = zipToolsSkip;
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('check_sig_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String fakeTool(String name, String output, {int exit = 0}) {
      final out = File('${tmp.path}/$name.out')..writeAsStringSync(output);
      final script = File('${tmp.path}/$name')
        ..writeAsStringSync('#!/bin/sh\ncat "${out.path}"\nexit $exit\n');
      Process.runSync('chmod', ['+x', script.path]);
      return script.path;
    }

    /// Las tres herramientas de mentira con las salidas dadas.
    List<String> tools({
      String? apksigner,
      int apksignerExit = 0,
      String? jarsigner,
      int jarsignerExit = 0,
      String? keytool,
    }) => [
      '--apksigner',
      fakeTool(
        'apksigner',
        apksigner ?? _read('apksigner_debug.txt'),
        exit: apksignerExit,
      ),
      '--jarsigner',
      fakeTool(
        'jarsigner',
        jarsigner ?? _read('jarsigner_debug.txt'),
        exit: jarsignerExit,
      ),
      '--keytool',
      fakeTool('keytool', keytool ?? _read('keytool_debug.txt')),
    ];

    String aab([String name = 'app']) => zipEntries(tmp, name, aabEntries());
    String apk([String name = 'app']) => zipEntries(tmp, name, {
      'classes.dex': [1],
    }, ext: 'apk');

    ({int code, String out, String err, Map<String, Object?>? json}) run(
      List<String> args, {
      bool json = true,
    }) {
      final jsonPath = '${tmp.path}/sig.json';
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runCheckSignature(
        [
          ...args,
          if (json) ...['--json', jsonPath],
        ],
        out: out,
        err: err,
      );
      final f = File(jsonPath);
      return (
        code: code,
        out: '$out',
        err: '$err',
        json: f.existsSync()
            ? jsonDecode(f.readAsStringSync()) as Map<String, Object?>
            : null,
      );
    }

    List<Map<String, Object?>> issuesOf(Map<String, Object?>? json) =>
        (json!['issues']! as List).cast<Map<String, Object?>>();

    Set<Object?> kinds(Map<String, Object?>? json) =>
        issuesOf(json).map((i) => i['kind']).toSet();

    test('CA-020-05: un AAB firmado con la clave de depuración: aviso `debug` '
        'y código 1', () {
      final r = run([...tools(), aab()]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      expect(kinds(r.json), {'debug'});
      expect(r.json!['complete'], isTrue);
      expect(r.json!['version'], 1);
      expect(r.json!['checks'], isNotEmpty);
      expect(issuesOf(r.json).single['subject'], 'app.aab');
      expect(issuesOf(r.json).single['message'], contains('Android Debug'));
      expect(r.out, contains('::error::'));
      expect(File('${tmp.path}/sig.json.tmp').existsSync(), isFalse);
    }, skip: skip);

    test(
      'CA-020-05: un APK firmado con la clave de depuración: aviso `debug`',
      () {
        final r = run([...tools(), apk()]);
        expect(r.code, 1, reason: '${r.out}${r.err}');
        expect(kinds(r.json), {'debug'});
        expect(issuesOf(r.json).single['subject'], 'app.apk');
      },
      skip: skip,
    );

    test('CA-020-03: jarsigner dice que verifica pero keytool no encuentra '
        'ningún firmante: fallo (falla cerrada)', () {
      final r = run([
        ...tools(
          jarsigner: 'jar verified.\n',
          keytool: 'Not a signed jar file\n',
        ),
        aab(),
      ]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      expect(kinds(r.json), {'fault'});
      expect(issuesOf(r.json).single['message'], contains('keytool'));
    }, skip: skip);

    test('CA-020-05: un AAB sin firmar: aviso `unsigned`', () {
      final r = run([
        ...tools(
          jarsigner: _read('jarsigner_unsigned.txt'),
          keytool: 'Not a signed jar file\n',
        ),
        aab(),
      ]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      expect(kinds(r.json), {'unsigned'});
    }, skip: skip);

    test('CA-020-05: un APK sin firmar: aviso `unsigned`', () {
      final r = run([
        ...tools(apksigner: _read('apksigner_unsigned.txt'), apksignerExit: 1),
        apk(),
      ]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      expect(kinds(r.json), {'unsigned'});
    }, skip: skip);

    test('CA-020-03: una firma que no verifica es un FALLO, no un aviso (APK '
        'y AAB)', () {
      final a = run([
        ...tools(apksigner: _read('apksigner_corrupt.txt'), apksignerExit: 1),
        apk(),
      ]);
      expect(a.code, 1);
      expect(kinds(a.json), {'fault'});
      final b = run([
        ...tools(jarsigner: _read('jarsigner_corrupt.txt'), jarsignerExit: 1),
        aab(),
      ]);
      expect(b.code, 1);
      expect(kinds(b.json), {'fault'});
    }, skip: skip);

    test('CA-020-05: si un paquete tiene un fallo, sus avisos pasan a fallo '
        '(depuración y, además, no es el certificado de subida)', () {
      final cert = File('${tmp.path}/upload-cert.sha256')
        ..writeAsStringSync('${'e' * 64}\n');
      final r = run([
        '--mode',
        'strict',
        '--upload-cert',
        cert.path,
        ...tools(),
        aab(),
      ]);
      expect(r.code, 1);
      expect(kinds(r.json), {'fault'});
      expect(issuesOf(r.json), hasLength(2));
    }, skip: skip);

    test('CA-020-03: firmado con otro certificado, modo testers: limpio '
        '(código 0, JSON sin errores)', () {
      final r = run([
        ...tools(
          jarsigner: 'jar verified.\n',
          keytool: _keytoolFor('Una Upload', _ownSha),
        ),
        aab(),
      ]);
      expect(r.code, 0, reason: '${r.out}${r.err}');
      expect(r.json!['complete'], isTrue);
      expect(issuesOf(r.json), isEmpty);
      expect(r.out, contains('OK'));
    }, skip: skip);

    test('CA-020-03: un APK firmado con otro certificado: limpio, y en '
        'estricto con otra huella, fallo', () {
      final args = tools(apksigner: _apksignerFor('Una Upload', _ownSha));
      final a = run([...args, apk()]);
      expect(a.code, 0, reason: '${a.out}${a.err}');
      final cert = File('${tmp.path}/upload-cert.sha256')
        ..writeAsStringSync('${'e' * 64}\n');
      final b = run([
        '--mode',
        'strict',
        '--upload-cert',
        cert.path,
        ...args,
        apk(),
      ]);
      expect(b.code, 1);
      expect(kinds(b.json), {'fault'});
    }, skip: skip);

    test('CA-020-03: modo estricto sin upload-cert.sha256: aviso '
        '`uploadCertMissing` aunque el firmante no sea el de depuración', () {
      final r = run([
        '--mode',
        'strict',
        '--upload-cert',
        '${tmp.path}/no-existe.sha256',
        ...tools(
          jarsigner: 'jar verified.\n',
          keytool: _keytoolFor('Una Upload', _ownSha),
        ),
        aab(),
      ]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      expect(kinds(r.json), {'uploadCertMissing'});
      expect(issuesOf(r.json).single['subject'], 'no-existe.sha256');
    }, skip: skip);

    test('CA-020-03: modo estricto con la clave de depuración y sin '
        'upload-cert.sha256: los dos avisos', () {
      final r = run([
        '--mode',
        'strict',
        '--upload-cert',
        '${tmp.path}/no-existe.sha256',
        ...tools(),
        aab(),
      ]);
      expect(r.code, 1);
      expect(kinds(r.json), {'debug', 'uploadCertMissing'});
    }, skip: skip);

    test('CA-020-03: modo testers no pide upload-cert.sha256', () {
      final r = run([
        '--mode',
        'testers',
        '--upload-cert',
        '${tmp.path}/no-existe.sha256',
        ...tools(),
        aab(),
      ]);
      expect(kinds(r.json), {'debug'});
    }, skip: skip);

    test('CA-020-03: modo estricto con la huella de subida y el mismo '
        'certificado: limpio', () {
      final cert = File('${tmp.path}/upload-cert.sha256')
        ..writeAsStringSync('# huella pública\n${_colons(_ownSha)}\n');
      final r = run([
        '--mode',
        'strict',
        '--upload-cert',
        cert.path,
        ...tools(
          jarsigner: 'jar verified.\n',
          keytool: _keytoolFor('Una Upload', _ownSha),
        ),
        aab(),
      ]);
      expect(r.code, 0, reason: '${r.out}${r.err}');
      expect(issuesOf(r.json), isEmpty);
    }, skip: skip);

    test('CA-020-03: modo estricto con otro certificado que el de subida: '
        'FALLO', () {
      final cert = File('${tmp.path}/upload-cert.sha256')
        ..writeAsStringSync('$_ownSha\n');
      final r = run([
        '--mode',
        'strict',
        '--upload-cert',
        cert.path,
        ...tools(
          jarsigner: 'jar verified.\n',
          keytool: _keytoolFor('Otro', 'f' * 64),
        ),
        aab(),
      ]);
      expect(r.code, 1);
      expect(kinds(r.json), {'fault'});
      expect(
        issuesOf(r.json).single['message'],
        allOf(contains('subida'), contains('f' * 8)),
      );
    }, skip: skip);

    test('CA-020-03: un upload-cert.sha256 mal formado es un FALLO', () {
      final cert = File('${tmp.path}/upload-cert.sha256')
        ..writeAsStringSync('esto no es una huella\n');
      final r = run([
        '--mode',
        'strict',
        '--upload-cert',
        cert.path,
        ...tools(),
        aab(),
      ]);
      expect(r.code, 1);
      expect(kinds(r.json), contains('fault'));
    }, skip: skip);

    test('CA-020-03: el modo, sin valor o desconocido: uso (2)', () {
      expect(run(['--mode', 'nada', 'a.aab'], json: false).code, 2);
      expect(run(['--mode'], json: false).code, 2);
    });

    test('CA-020-03: una herramienta que no existe: fallo, y el JSON sale '
        'completo', () {
      final r = run([
        '--apksigner',
        '${tmp.path}/nada/apksigner',
        '--jarsigner',
        '${tmp.path}/nada/jarsigner',
        '--keytool',
        '${tmp.path}/nada/keytool',
        apk(),
        aab('b'),
      ]);
      expect(r.code, 1);
      expect(r.json!['complete'], isTrue);
      expect(kinds(r.json), {'fault'});
      expect(issuesOf(r.json), hasLength(2));
    }, skip: skip);

    test(
      'CA-020-03: un paquete que no existe, o sin paquetes: fallo / uso',
      () {
        final r = run([...tools(), '${tmp.path}/no-existe.aab']);
        expect(r.code, 1);
        expect(kinds(r.json), {'fault'});
        expect(issuesOf(r.json).single['subject'], 'no-existe.aab');
        expect(run([...tools()], json: false).code, 2);
        expect(run(['--nada', 'a.aab'], json: false).code, 2);
      },
      skip: skip,
    );

    test('CA-020-03: jarsigner pasa por la lengua inglesa (-J-Duser.language)', () {
      final log = File('${tmp.path}/args.log');
      final script = File('${tmp.path}/jarsigner')
        ..writeAsStringSync(
          '#!/bin/sh\necho "\$*" >> "${log.path}"\ncat "${tmp.path}/j.out"\n',
        );
      File('${tmp.path}/j.out').writeAsStringSync('jar verified.\n');
      Process.runSync('chmod', ['+x', script.path]);
      final keylog = File('${tmp.path}/keyargs.log');
      final key = File('${tmp.path}/keytool')
        ..writeAsStringSync(
          '#!/bin/sh\necho "\$*" >> "${keylog.path}"\ncat "${tmp.path}/k.out"\n',
        );
      File('${tmp.path}/k.out').writeAsStringSync(_keytoolFor('X', _ownSha));
      Process.runSync('chmod', ['+x', key.path]);
      run([
        '--apksigner',
        fakeTool('apksigner', ''),
        '--jarsigner',
        script.path,
        '--keytool',
        key.path,
        aab(),
      ]);
      expect(log.readAsStringSync(), contains('-J-Duser.language=en'));
      expect(log.readAsStringSync(), contains('-verify -strict'));
      expect(keylog.readAsStringSync(), contains('-J-Duser.language=en'));
      expect(keylog.readAsStringSync(), contains('-printcert -jarfile'));
    }, skip: skip);

    test('CA-020-03: apksigner se llama con verify --print-certs', () {
      final log = File('${tmp.path}/args.log');
      final script = File('${tmp.path}/apksigner')
        ..writeAsStringSync(
          '#!/bin/sh\necho "\$*" >> "${log.path}"\ncat "${tmp.path}/a.out"\n',
        );
      File('${tmp.path}/a.out').writeAsStringSync(_read('apksigner_debug.txt'));
      Process.runSync('chmod', ['+x', script.path]);
      run(['--apksigner', script.path, apk()]);
      expect(log.readAsStringSync(), contains('verify --print-certs'));
    }, skip: skip);

    test('CA-020-03: sin --json también funciona (y no deja archivos)', () {
      final r = run([...tools(), aab()], json: false);
      expect(r.code, 1);
      expect(r.json, isNull);
    }, skip: skip);
  });

  group('CA-020-03: el wrapper', () {
    test('CA-020-03: tools/release/check-signature.sh existe, se apoya en '
        'check_signature.dart y falla sin paquetes', () {
      final text = File('../tools/release/check-signature.sh')
          .readAsStringSync();
      expect(text, contains('tool/check_signature.dart'));
      final r = Process.runSync('bash', [
        '../tools/release/check-signature.sh',
      ]);
      expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    });

    test('CA-020-03: el archivo de la huella de subida es un [Pendiente, F6]: '
        'hoy no existe', () {
      expect(File('../tools/release/upload-cert.sha256').existsSync(), isFalse);
    });
  });

  group('CA-020-03: con las herramientas y paquetes reales (si están)', () {
    final jarsigner = _realTool('jarsigner', ['-help']);
    final keytool = _realTool('keytool', ['-help']);
    final apksigner = findBuildTool('apksigner');
    final java = _realTool('java', ['-version']);
    final aabFile = File(realAabPath);

    test('CA-020-05: el AAB real de release está firmado con la clave de '
        'depuración (aviso `debug`)', () {
      if (!jarsigner || !keytool || !aabFile.existsSync()) {
        markTestSkipped('sin jarsigner/keytool o sin AAB de release');
        return;
      }
      final out = StringBuffer();
      final json = '${Directory.systemTemp.path}/sig_real_${pid}_aab.json';
      final code = runCheckSignature(
        ['--json', json, aabFile.path],
        out: out,
        err: StringBuffer(),
      );
      final data =
          jsonDecode(File(json).readAsStringSync()) as Map<String, Object?>;
      File(json).deleteSync();
      expect(code, 1, reason: '$out');
      final kinds = (data['issues']! as List)
          .cast<Map<String, Object?>>()
          .map((i) => i['kind'])
          .toSet();
      expect(kinds, {'debug'}, reason: '$out');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('CA-020-05: el AAB real, en modo estricto, además no tiene huella de '
        'subida', () {
      if (!jarsigner || !keytool || !aabFile.existsSync()) {
        markTestSkipped('sin jarsigner/keytool o sin AAB de release');
        return;
      }
      final out = StringBuffer();
      final json = '${Directory.systemTemp.path}/sig_real_${pid}_strict.json';
      runCheckSignature(
        ['--mode', 'strict', '--json', json, aabFile.path],
        out: out,
        err: StringBuffer(),
      );
      final data =
          jsonDecode(File(json).readAsStringSync()) as Map<String, Object?>;
      File(json).deleteSync();
      final kinds = (data['issues']! as List)
          .cast<Map<String, Object?>>()
          .map((i) => i['kind'])
          .toSet();
      expect(kinds, {'debug', 'uploadCertMissing'}, reason: '$out');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('CA-020-05: un APK real de release está firmado con la clave de '
        'depuración (aviso `debug`)', () {
      final apk = File(
        'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
      );
      // apksigner is a Java program: without a runnable JRE it fails closed
      // (`fault`), which says nothing about the signature.
      if (apksigner == null || !java || !apk.existsSync()) {
        markTestSkipped('sin apksigner, sin Java o sin APK de release');
        return;
      }
      final out = StringBuffer();
      final json = '${Directory.systemTemp.path}/sig_real_${pid}_apk.json';
      final code = runCheckSignature(
        ['--json', json, apk.path],
        out: out,
        err: StringBuffer(),
      );
      final data =
          jsonDecode(File(json).readAsStringSync()) as Map<String, Object?>;
      File(json).deleteSync();
      expect(code, 1, reason: '$out');
      final kinds = (data['issues']! as List)
          .cast<Map<String, Object?>>()
          .map((i) => i['kind'])
          .toSet();
      expect(kinds, {'debug'}, reason: '$out');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
