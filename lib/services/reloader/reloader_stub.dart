import 'dart:io';

void recargarApp([String? urlDescargaWindows]) {
  if (urlDescargaWindows == null || urlDescargaWindows.isEmpty) {
    // No llegó URL de descarga (ej. backend viejo): no hay forma de
    // auto-actualizar, así que solo cerramos como antes.
    exit(0);
  }

  final exePropio = Platform.resolvedExecutable;
  final carpeta = File(exePropio).parent.path;
  final rutaUpdater = '$carpeta\\Updater.exe';

  if (File(rutaUpdater).existsSync()) {
    Process.start(
      rutaUpdater,
      [urlDescargaWindows, exePropio],
      mode: ProcessStartMode.detached,
    ).then((_) => exit(0));
  } else {
    // Esta máquina todavía no tiene el Updater.exe instalado junto a la app.
    exit(0);
  }
}