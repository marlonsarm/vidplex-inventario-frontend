import 'dart:io';
import '../updater_service.dart';

Future<void> recargarApp(
  String? urlDescargaWindows, {
  void Function(double progreso)? onProgreso,
}) async {
  if (urlDescargaWindows == null || urlDescargaWindows.isEmpty) {
    exit(0);
  }

  await UpdaterService.descargarYActualizar(
    urlZip: urlDescargaWindows,
    onProgreso: onProgreso ?? (_) {},
  );
}