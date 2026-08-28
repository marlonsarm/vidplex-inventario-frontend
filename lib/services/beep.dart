export 'beep_stub.dart'
    if (dart.library.html) 'beep_web.dart'
    if (dart.library.io) 'beep_mobile.dart';