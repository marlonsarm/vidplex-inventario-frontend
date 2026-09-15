import 'dart:io';
import 'package:archive/archive_io.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Uso: updater.exe <ruta_zip_local> <ruta_exe_app>');
    exit(1);
  }

  final rutaZipLocal = args[0];
  final rutaExeApp = args[1];
  final carpetaApp = File(rutaExeApp).parent.path;
  final nombreExe = File(rutaExeApp).uri.pathSegments.last;

  print('Actualizando InvPlex...');

  // Le damos un momento a la app original para que termine de cerrar
  // del todo y libere el archivo .exe antes de intentar reemplazarlo.
  await Future.delayed(const Duration(seconds: 15));

  try {
    print('Instalando actualización...');
    await _extraerConReintentos(rutaZipLocal, carpetaApp);

    print('Actualización instalada. Reabriendo InvPlex...');
    await Process.start(
      '$carpetaApp\\$nombreExe',
      [],
      mode: ProcessStartMode.detached,
      workingDirectory: carpetaApp,
    );
  } catch (e) {
    stderr.writeln('Error al actualizar: $e');
    // Si algo falla, reabrimos la versión vieja para no dejar al usuario sin app.
    if (File(rutaExeApp).existsSync()) {
      await Process.start(rutaExeApp, [], mode: ProcessStartMode.detached, workingDirectory: carpetaApp);
    }
  } finally {
    try {
      await File(rutaZipLocal).delete();
    } catch (_) {}
  }

  exit(0);
}

Future<void> _extraerConReintentos(String rutaZip, String carpetaDestino) async {
  const intentosMaximos = 8;
  Object? ultimoError;

  for (var intento = 1; intento <= intentosMaximos; intento++) {
    try {
      final bytes = await File(rutaZip).readAsBytes();
      final archivo = ZipDecoder().decodeBytes(bytes);

      for (final entrada in archivo) {
        final rutaDestino = '$carpetaDestino\\${entrada.name}';
        if (entrada.isFile) {
          final datos = entrada.content as List<int>;
          final archivoDestino = File(rutaDestino);
          await archivoDestino.create(recursive: true);
          await archivoDestino.writeAsBytes(datos);
        } else {
          await Directory(rutaDestino).create(recursive: true);
        }
      }
      return; // Éxito, salimos de la función.
    } catch (e) {
      ultimoError = e;
      // Probablemente InvPlex.exe todavía no soltó el archivo; reintenta.
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // Se agotaron los intentos: propagamos el último error para que se vea
  // reflejado arriba (y se reabra la versión vieja en vez de quedar a medias).
  throw ultimoError ?? Exception('No se pudo extraer la actualización tras $intentosMaximos intentos');
}
