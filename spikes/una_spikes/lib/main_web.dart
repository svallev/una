// SPIKE S6 — entrada web mínima: shader y animaciones (S2) + visor PDF con WASM (S3),
// para validar Flutter web bajo una CSP estricta. Código desechable.
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'anim.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadShaders();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _Home()));
}

class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paper,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Versión de pruebas · los datos pueden borrarse', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AnimLab())),
            child: const Text('S2 · Animaciones'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(appBar: AppBar(title: const Text('PDF (WASM)')), body: PdfViewer.asset('assets/texto_300p.pdf')),
            )),
            child: const Text('S3 · PDF'),
          ),
        ]),
      ),
    );
  }
}
