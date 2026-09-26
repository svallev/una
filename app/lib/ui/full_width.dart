import 'package:flutter/foundation.dart';

/// Pantallas abiertas que ocupan todo el ancho aunque el marco de la app lo
/// limite en tablets y plegables (CL-001-7): el visor de imágenes, que va al
/// 100 % del ancho de la pantalla, también en horizontal (CA-007-09/11).
final fullWidthRequests = ValueNotifier<int>(0);
