// La firma del paquete de release (spec 020, T-020-06; plan §3.2, id `signature`; CA-020-03 e,
// CA-020-05 d):
//
//   dart run tool/check_signature.dart [--mode strict|testers] [--json <archivo>]
//       [--upload-cert <archivo>] [--apksigner <ruta>] [--jarsigner <ruta>] [--keytool <ruta>]
//       <apk|aab>...
//
// Lo normal es llamarla con `tools/release/check-signature.sh`. En un APK usa
// `apksigner verify --print-certs`; en un AAB, `jarsigner -verify -strict` (que dice si la firma
// verifica) y `keytool -printcert -jarfile` (de quién es). Clasifica lo que encuentra:
//
//   `unsigned`           el paquete no está firmado (aviso de identidad, CA-020-05 d);
//   `debug`              firmado con el certificado de depuración, `CN=Android Debug` (el mismo aviso);
//   `uploadCertMissing`  en modo `strict`, no existe `tools/release/upload-cert.sha256`, la huella
//                        SHA-256 pública del certificado de subida (**[Pendiente, F6]**): ningún
//                        otro certificado pasa hasta entonces (aviso, CA-020-03 e);
//   `fault`              todo lo demás: una firma que no verifica (alterada, caducada), un
//                        certificado que no es el de subida, una herramienta que falta, un paquete
//                        que no existe. Falla cerrada: nada que no se entienda es un verde.
//
// Si un paquete tiene un fallo, todos sus hallazgos pasan a fallo (CL-020-20). Con `--json` escribe
// la lista (`{version, complete, checks, issues: [{kind, subject, message}]}`) de forma atómica y al
// final, con `complete: true`. Sale con 0 sin hallazgos, 1 con alguno y 2 con un uso incorrecto.
// Las herramientas se llaman en inglés (`-J-Duser.language=en`): su salida se interpreta por texto.
import 'dart:convert';
import 'dart:io';

import 'check_package.dart' show ClassedIssue, writeClassJson;

/// Un firmante: el sujeto de su certificado y su huella SHA-256 (en minúsculas y sin separadores).
class Signer {
  const Signer(this.dn, this.sha256);

  final String dn;
  final String sha256;

  @override
  String toString() => '$dn ($sha256)';
}

/// Lo que dice una herramienta de firma de un paquete.
sealed class SignatureResult {
  const SignatureResult();
}

/// Con firma que verifica; en un AAB, [signers] se completa después con `keytool`.
class SignedPackage extends SignatureResult {
  const SignedPackage(this.signers);

  final List<Signer> signers;
}

/// Sin firma.
class UnsignedPackage extends SignatureResult {
  const UnsignedPackage();
}

/// Con una firma que no verifica, o una salida que no se entiende.
class InvalidSignature extends SignatureResult {
  const InvalidSignature(this.reason);

  final String reason;
}

String _clip(String s, [int max = 200]) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';

String _hex(String raw) => raw.replaceAll(RegExp(r'[\s:]'), '').toLowerCase();

final _sha256 = RegExp(r'^[0-9a-f]{64}$');

/// Si [dn] es el certificado de depuración de Android: su atributo `CN` es exactamente
/// `Android Debug` (no `Android Debugger`, ni un `O=` que lo contenga).
bool isDebugDn(String dn) =>
    RegExp(r'(^|,\s*)CN=Android Debug(\s*,|\s*$)').hasMatch(dn);

/// Una línea de certificado de un firmante de `apksigner verify --print-certs`: la etiqueta del
/// firmante, `DN` o `SHA-256 digest`, y el valor.
final _apksignerCertLine = RegExp(
  r'^(?:(Signer #\d+)|(V\d+(?:\.\d+)? Signer(?: #\d+)?):) certificate (DN|SHA-256 digest): (.*)$',
);

/// Interpreta la salida de `apksigner verify --print-certs` ([exitCode] es su código).
SignatureResult parseApksigner(String output, int exitCode) {
  final lines = const LineSplitter().convert(output);
  if (lines.any((l) => l.trim() == 'DOES NOT VERIFY')) {
    final errors = [
      for (final l in lines)
        if (l.startsWith('ERROR: ')) l.substring(7).trim(),
    ];
    if (errors.length == 1 && errors.single == 'Missing META-INF/MANIFEST.MF') {
      return const UnsignedPackage();
    }
    return InvalidSignature(
      errors.isEmpty ? 'apksigner dice que no verifica' : _clip(errors.first),
    );
  }
  if (exitCode != 0) {
    final detail = lines.firstWhere(
      (l) => l.trim().isNotEmpty && !l.startsWith('WARNING:'),
      orElse: () => '',
    );
    return InvalidSignature(
      'apksigner terminó con el código $exitCode${detail.isEmpty ? '' : ': ${_clip(detail)}'}',
    );
  }
  // Los firmantes, por su etiqueta completa: `Signer #N` (build-tools ≤ 36) o `<esquema> Signer[ #N]`
  // (`V2 Signer`, `V3.1 Signer #2`…; build-tools 37). Las líneas de `Source Stamp` no son firmantes.
  final dns = <String, String>{};
  final shas = <String, String>{};
  var ambiguous = false;
  for (final l in lines) {
    final m = _apksignerCertLine.firstMatch(l);
    if (m == null) continue;
    final label = m.group(1) ?? m.group(2)!;
    final isDn = m.group(3) == 'DN';
    final value = m.group(4)!.trim();
    final target = isDn ? dns : shas;
    final v = isDn ? value : _hex(value);
    if (target.containsKey(label) && target[label] != v) ambiguous = true;
    target[label] = v;
  }
  final labels = {...dns.keys, ...shas.keys};
  final complete = labels.every(
    (k) => dns.containsKey(k) && _sha256.hasMatch(shas[k] ?? ''),
  );
  if (ambiguous || labels.isEmpty || !complete) {
    return const InvalidSignature(
      'apksigner no dio ningún firmante legible (salida que no se entiende)',
    );
  }
  // El mismo certificado en varios esquemas (v2 + v3) o etiquetas es un solo firmante.
  final seen = <String>{};
  final signers = [
    for (final k in labels)
      if (seen.add('${dns[k]}\n${shas[k]}')) Signer(dns[k]!, shas[k]!),
  ];
  return SignedPackage(signers);
}

/// Los errores de `jarsigner` que no son un problema: un certificado autofirmado (la clave de
/// subida lo es) cuya cadena no se puede validar contra una raíz de confianza.
final _benignJarsignerErrors = [
  RegExp(r'certificate chain is invalid'),
  RegExp(r'signer certificate is self-signed'),
];

/// Interpreta la salida de `jarsigner -verify -strict` (en inglés). El resultado es [SignedPackage]
/// con la lista vacía: los firmantes salen de `keytool` ([parseKeytool]).
SignatureResult parseJarsigner(String output) {
  final lines = const LineSplitter().convert(output);
  final first = lines.firstWhere(
    (l) =>
        l.trim().startsWith('jar ') ||
        l.trim().startsWith('jarsigner') ||
        l.trim().startsWith('no manifest'),
    orElse: () => '',
  );
  if (lines.any((l) => l.trim() == 'jar is unsigned.')) {
    return const UnsignedPackage();
  }
  if (first.trim().startsWith('jar verified')) {
    // Los errores de la firma (no de integridad): solo se toleran los de un certificado
    // autofirmado; uno caducado, aún no válido o desconocido, no.
    final errors = <String>[];
    var inErrors = false;
    for (final l in lines) {
      if (l.trim() == 'Error:') {
        inErrors = true;
        continue;
      }
      if (inErrors) {
        if (l.trim().isEmpty) {
          inErrors = false;
        } else {
          errors.add(l.trim());
        }
      }
    }
    final bad = errors.where(
      (e) => !_benignJarsignerErrors.any((p) => p.hasMatch(e)),
    );
    if (bad.isNotEmpty) return InvalidSignature(_clip(bad.first));
    return const SignedPackage([]);
  }
  final error = lines.firstWhere(
    (l) => l.startsWith('jarsigner error:') || l.startsWith('jarsigner:'),
    orElse: () => '',
  );
  return InvalidSignature(
    error.isEmpty
        ? 'jarsigner no dice que la firma verifique (salida que no se entiende)'
        : _clip(error.replaceFirst(RegExp(r'^jarsigner( error)?:\s*'), '')),
  );
}

/// Los firmantes de la salida de `keytool -printcert -jarfile` (en inglés): para cada `Signer #N`,
/// el sujeto (`Owner:`) y el SHA-256 de su **primer** certificado (el de la hoja; la cadena no cuenta).
List<Signer> parseKeytool(String output) {
  final signers = <Signer>[];
  String? dn;
  String? sha;
  var inFirstCert = false;
  var open = false;

  void close() {
    if (open && dn != null && sha != null && _sha256.hasMatch(sha!)) {
      signers.add(Signer(dn!, sha!));
    }
    dn = null;
    sha = null;
    inFirstCert = false;
  }

  for (final raw in const LineSplitter().convert(output)) {
    final line = raw.trim();
    if (RegExp(r'^Signer #\d+:').hasMatch(line)) {
      close();
      open = true;
      continue;
    }
    final cert = RegExp(r'^Certificate #(\d+):').firstMatch(line);
    if (cert != null) {
      inFirstCert = cert.group(1) == '1';
      continue;
    }
    if (!open || !inFirstCert) continue;
    if (dn == null && line.startsWith('Owner:')) {
      dn = line.substring(6).trim();
    }
    final s = RegExp(r'^SHA256:\s*([0-9A-Fa-f:]+)$').firstMatch(line);
    if (sha == null && s != null) sha = _hex(s.group(1)!);
  }
  close();
  return signers;
}

/// Las huellas SHA-256 de `tools/release/upload-cert.sha256`: una por línea, en hexadecimal (con o
/// sin `:`, mayúsculas o minúsculas) y con `#` para comentarios. Lanza [FormatException] si una línea
/// no es una huella o no hay ninguna.
Set<String> parseUploadCert(String text) {
  final out = <String>{};
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.split('#').first.trim();
    if (line.isEmpty) continue;
    final h = _hex(line);
    if (!_sha256.hasMatch(h)) {
      throw FormatException(
        '«${_clip(line, 40)}» no es una huella SHA-256 (64 cifras hexadecimales)',
      );
    }
    out.add(h);
  }
  if (out.isEmpty) throw const FormatException('no hay ninguna huella');
  return out;
}

// ─── Las herramientas ───────────────────────────────────────────────────────────────────────────

int _compareVersions(String a, String b) {
  List<int> parts(String v) =>
      v.split(RegExp(r'[.\-]')).map((s) => int.tryParse(s) ?? 0).toList();
  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// La herramienta [name] (`apksigner`…) de las `build-tools` más nuevas de `$ANDROID_HOME` (o
/// `$ANDROID_SDK_ROOT`, o las carpetas habituales del SDK); `null` si no hay ninguna.
String? findBuildTool(String name) {
  final env = Platform.environment;
  final home = env['HOME'];
  final roots = [
    env['ANDROID_HOME'],
    env['ANDROID_SDK_ROOT'],
    if (home != null) '$home/Library/Android/sdk',
    if (home != null) '$home/Android/Sdk',
  ].whereType<String>().where((r) => r.isNotEmpty);
  for (final root in roots) {
    final dir = Directory('$root/build-tools');
    if (!dir.existsSync()) continue;
    final versions =
        dir
            .listSync()
            .whereType<Directory>()
            .where((d) => File('${d.path}/$name').existsSync())
            .toList()
          ..sort(
            (a, b) => _compareVersions(
              b.path.split(Platform.pathSeparator).last,
              a.path.split(Platform.pathSeparator).last,
            ),
          );
    if (versions.isNotEmpty) return '${versions.first.path}/$name';
  }
  return null;
}

/// `jarsigner` o `keytool`: el de `$JAVA_HOME/bin` si existe; si no, el del PATH.
String _javaTool(String name) {
  final home = Platform.environment['JAVA_HOME'];
  if (home != null && home.isNotEmpty && File('$home/bin/$name').existsSync()) {
    return '$home/bin/$name';
  }
  return name;
}

class _ToolOutput {
  const _ToolOutput(this.exitCode, this.text);

  final int exitCode;
  final String text;
}

/// Ejecuta [tool]; lanza [StateError] con el motivo si no se puede ejecutar.
_ToolOutput _run(String? tool, String label, List<String> args) {
  if (tool == null) {
    throw StateError(
      'no se encuentra $label: instala las build-tools del SDK de Android o pásalo con --$label',
    );
  }
  try {
    final r = Process.runSync(
      tool,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    return _ToolOutput(r.exitCode, '${r.stdout}\n${r.stderr}');
  } on ProcessException catch (e) {
    throw StateError('no se pudo ejecutar $label (${e.message})');
  }
}

const _javaLocale = ['-J-Duser.language=en', '-J-Duser.country=US'];

const _defaultUploadCert = '../tools/release/upload-cert.sha256';

/// Las herramientas que usa la comprobación (rutas dadas o `null` para buscarlas).
class SignatureTools {
  const SignatureTools({this.apksigner, this.jarsigner, this.keytool});

  final String? apksigner;
  final String? jarsigner;
  final String? keytool;
}

List<ClassedIssue> _checkOne(
  String package,
  String subject,
  SignatureTools tools,
  Set<String>? uploadFingerprints,
) {
  final issues = <ClassedIssue>[];
  ClassedIssue issue(String kind, String message) =>
      ClassedIssue(kind, subject, message);

  if (!File(package).existsSync()) {
    return [issue('fault', 'no existe el paquete')];
  }
  SignatureResult result;
  try {
    if (package.toLowerCase().endsWith('.aab')) {
      final jar = _run(tools.jarsigner ?? _javaTool('jarsigner'), 'jarsigner', [
        ..._javaLocale,
        '-verify',
        '-strict',
        package,
      ]);
      result = parseJarsigner(jar.text);
      if (result is SignedPackage) {
        final key = _run(tools.keytool ?? _javaTool('keytool'), 'keytool', [
          ..._javaLocale,
          '-printcert',
          '-jarfile',
          package,
        ]);
        final signers = parseKeytool(key.text);
        result = signers.isEmpty
            ? const InvalidSignature(
                'keytool no encontró ningún firmante en el AAB',
              )
            : SignedPackage(signers);
      }
    } else {
      final sig = _run(
        tools.apksigner ?? findBuildTool('apksigner'),
        'apksigner',
        ['verify', '--print-certs', package],
      );
      result = parseApksigner(sig.text, sig.exitCode);
    }
  } on StateError catch (e) {
    return [issue('fault', e.message)];
  }

  switch (result) {
    case UnsignedPackage():
      issues.add(issue('unsigned', 'el paquete no está firmado'));
    case InvalidSignature(:final reason):
      issues.add(issue('fault', 'la firma no verifica: $reason'));
    case SignedPackage(:final signers):
      for (final s in signers) {
        if (isDebugDn(s.dn)) {
          issues.add(
            issue(
              'debug',
              'firmado con el certificado de depuración (${s.dn}, SHA-256 ${s.sha256})',
            ),
          );
        }
        if (uploadFingerprints != null &&
            !uploadFingerprints.contains(s.sha256)) {
          issues.add(
            issue(
              'fault',
              'firmado con un certificado que no es el de subida (SHA-256 ${s.sha256})',
            ),
          );
        }
      }
  }
  // Un fallo y un aviso del mismo paquete: todo es fallo (CL-020-20).
  final anyFault = issues.any((i) => i.kind == 'fault');
  // Una sola línea por paquete y motivo: el mismo certificado en dos firmantes (keytool) o en dos
  // esquemas no se repite.
  final seen = <String>{};
  return [
    for (final i in issues)
      if (seen.add('${anyFault ? 'fault' : i.kind}\n${i.message}'))
        anyFault ? issue('fault', i.message) : i,
  ];
}

const _usage =
    'Uso: dart run tool/check_signature.dart [--mode strict|testers] [--json <archivo>] '
    '[--upload-cert <archivo>] [--apksigner <ruta>] [--jarsigner <ruta>] [--keytool <ruta>] <apk|aab>...';

/// Ejecuta la herramienta. Devuelve el código de salida: 0 sin hallazgos, 1 con alguno, 2 si se usa
/// mal. [out] y [err] son donde escribe (por defecto, la consola).
int runCheckSignature(List<String> args, {StringSink? out, StringSink? err}) {
  final o = out ?? stdout;
  final e = err ?? stderr;
  var strict = false;
  String? jsonPath;
  String uploadCertPath = _defaultUploadCert;
  String? apksigner;
  String? jarsigner;
  String? keytool;
  final packages = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    const withValue = {
      '--mode',
      '--json',
      '--upload-cert',
      '--apksigner',
      '--jarsigner',
      '--keytool',
    };
    if (withValue.contains(a)) {
      if (i + 1 >= args.length) {
        e.writeln('::error::$a necesita un valor\n$_usage');
        return 2;
      }
      final v = args[++i];
      switch (a) {
        case '--mode':
          if (v != 'strict' && v != 'testers') {
            e.writeln('::error::--mode es strict o testers, no «$v»\n$_usage');
            return 2;
          }
          strict = v == 'strict';
        case '--json':
          jsonPath = v;
        case '--upload-cert':
          uploadCertPath = v;
        case '--apksigner':
          apksigner = v;
        case '--jarsigner':
          jarsigner = v;
        default:
          keytool = v;
      }
    } else if (a.startsWith('--')) {
      e.writeln('::error::argumento desconocido: $a\n$_usage');
      return 2;
    } else {
      packages.add(a);
    }
  }
  if (packages.isEmpty) {
    e.writeln(
      '::error::no hay ningún paquete que comprobar (0 entradas es un fallo)\n$_usage',
    );
    return 2;
  }

  final issues = <ClassedIssue>[];
  // La huella de la clave de subida: solo en modo estricto (hoy no existe: [Pendiente, F6]).
  Set<String>? upload;
  if (strict) {
    final subject = uploadCertPath.split(Platform.pathSeparator).last;
    final file = File(uploadCertPath);
    if (!file.existsSync()) {
      issues.add(
        ClassedIssue(
          'uploadCertMissing',
          subject,
          'no existe: sin la huella SHA-256 pública del certificado de subida ningún certificado '
              'pasa en modo estricto ([Pendiente, F6])',
        ),
      );
    } else {
      try {
        upload = parseUploadCert(file.readAsStringSync());
      } on FormatException catch (ex) {
        issues.add(ClassedIssue('fault', subject, ex.message));
      } on FileSystemException catch (ex) {
        issues.add(
          ClassedIssue(
            'fault',
            subject,
            'no se puede leer (${ex.osError?.message ?? ex.message})',
          ),
        );
      }
    }
  }

  final tools = SignatureTools(
    apksigner: apksigner,
    jarsigner: jarsigner,
    keytool: keytool,
  );
  for (final package in packages) {
    issues.addAll(
      _checkOne(
        package,
        package.split(Platform.pathSeparator).last,
        tools,
        upload,
      ),
    );
  }

  if (jsonPath != null) {
    try {
      writeClassJson(jsonPath, issues, ['signature']);
    } on FileSystemException catch (ex) {
      o.writeln(
        '::error::no se puede escribir $jsonPath (${ex.osError?.message ?? ex.message})',
      );
      return 1;
    }
  }
  if (issues.isEmpty) {
    o.writeln('OK firma de ${packages.length} paquete(s): sin hallazgos');
    return 0;
  }
  for (final i in issues) {
    o.writeln('::error::${i.line}');
  }
  o.writeln(
    'La firma no sirve para publicar (${issues.length}) (spec 020, CA-020-03 e).',
  );
  return 1;
}

void main(List<String> args) {
  exit(runCheckSignature(args));
}
