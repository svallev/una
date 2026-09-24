// SPIKE F1 (S1 arranque + S2 animaciones). Código desechable: no es la app.
import 'dart:io';

import 'package:flutter/material.dart';

import 'anim.dart';
import 'db.dart';
import 'lab.dart';
import 'perf.dart';

late SpikeDb db;
late String base;

Future<void> main() async {
  startup.start();
  WidgetsFlutterBinding.ensureInitialized();
  final marks = <String, Object?>{};
  base = await attachmentsBase();
  const mode = String.fromEnvironment('DB_MODE', defaultValue: 'isolate');
  final docs = await dbDir();
  db = mode == 'main' ? SpikeDb.mainIsolate(docs) : SpikeDb.isolate();
  marks['db_mode'] = mode;
  await db.ensureSchema();
  marks['db_open_ms'] = startup.elapsedMilliseconds;
  final seeded = await db.countPending() == 0;
  if (seeded) await db.seedIfEmpty(base); // solo la primera vez (no se mide)
  const display = String.fromEnvironment('DISPLAY', defaultValue: 'png');
  if (display == 'jpg' && !File('$base/attachments/img1/display_1080.jpg').existsSync()) {
    await db.ensureJpegDisplay(base, 1080); // una vez; esa ejecución no cuenta
    marks['seeded'] = true;
  }
  marks['display'] = display;
  final task = await db.currentTask();
  marks['query_ms'] = startup.elapsedMilliseconds;
  marks['seeded'] = seeded || marks['seeded'] == true;
  runApp(SpikeApp(task: task, marks: marks));
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key, required this.task, required this.marks});
  final CurrentTask? task;
  final Map<String, Object?> marks;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: paper, colorSchemeSeed: ink),
      home: CurrentTaskScreen(task: task, marks: marks),
    );
  }
}

class CurrentTaskScreen extends StatefulWidget {
  const CurrentTaskScreen({super.key, required this.task, required this.marks});
  final CurrentTask? task;
  final Map<String, Object?> marks;
  @override
  State<CurrentTaskScreen> createState() => _CurrentTaskScreenState();
}

class _CurrentTaskScreenState extends State<CurrentTaskScreen> {
  bool _reported = false;
  String _info = '';

  void _visible() {
    if (_reported) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.marks['task_visible_ms'] = startup.elapsedMilliseconds;
      widget.marks['kind'] = widget.task?.kind ?? 'text';
      await reportFullyDrawn(widget.marks);
      setState(() => _info = widget.marks.entries.map((e) => '${e.key}=${e.value}').join(' · '));
      await loadShaders(); // después de ver la tarea, nunca antes
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    Widget body;
    if (t == null) {
      body = const Center(child: Text('Sin tareas'));
      _visible();
    } else if (t.kind == 'image' && t.displayRelPath != null) {
      final w = MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context);
      body = ColoredBox(
        color: Colors.white,
        child: Image.file(
          File('$base/${t.displayRelPath}'),
          fit: BoxFit.contain,
          cacheWidth: w.round(),
          frameBuilder: (context, child, frame, sync) {
            if (frame != null) _visible();
            return child;
          },
        ),
      );
    } else {
      body = StickyNote(text: t.text ?? '', color: palette[t.colorKey % 5]);
      _visible();
    }
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        body,
        Positioned(
          left: 12,
          right: 12,
          bottom: 24,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_info.isNotEmpty)
              Container(color: Colors.white.withValues(alpha: .85), padding: const EdgeInsets.all(6), child: Text(_info, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AnimLab())),
                child: const Text('S2 · Animaciones'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Lab())),
                child: const Text('S3 · S4 · S5'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await db.setCurrent(image: t?.kind != 'image');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambiado. Cierra y reabre la app para medir.')));
                  }
                },
                child: Text(t?.kind == 'image' ? 'Poner texto arriba' : 'Poner imagen arriba'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
