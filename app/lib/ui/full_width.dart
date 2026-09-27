import 'package:flutter/foundation.dart';

/// Pantallas abiertas que ocupan todo el ancho aunque el marco de la app lo
/// limite en tablets y plegables (CL-001-7): la tarea actual con imagen en
/// horizontal, que va al 100 % del ancho de la pantalla (CA-007-11).
final fullWidthRequests = ValueNotifier<int>(0);
