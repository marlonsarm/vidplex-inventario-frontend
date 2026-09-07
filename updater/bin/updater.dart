import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Uso: updater.exe <url_zip> <ruta_exe_app>');
    exit(1);
  }

  final urlZip = args[0];
  final rutaExeApp = args[1];
  final carpetaApp = File(rutaExeApp).parent.path;
  final nombreExe = File(rutaExeApp).uri.pathSegments.last;

  print('Actualizando InvPlex...');

  // Le damos un momento a la app original para que termine de cerrar
  // del todo y libere el archivo .exe antes de intentar reemplazarlo.
  await Future.delayed(const Duration(seconds: 2));

  final rutaZipTemp = '${Directory.systemTemp.path}\\invplex_update.zip';

  try {
    print('Descargando actualización...');
    final respuesta = await http.get(Uri.parse(urlZip));
    if (respuesta.statusCode != 200) {
      throw Exception('El servidor respondió ${respuesta.statusCode} al descargar el zip.');
    }
    await File(rutaZipTemp).writeAsBytes(respuesta.bodyBytes);

    print('Instalando actualización...');
    final bytes = await File(rutaZipTemp).readAsBytes();
    final archivo = ZipDecoder().decodeBytes(bytes);

    for (final entrada in archivo) {
      final rutaDestino = '$carpetaApp\\${entrada.name}';
      if (entrada.isFile) {
        final datos = entrada.content as List<int>;
        final archivoDestino = File(rutaDestino);
        await archivoDestino.create(recursive: true);
        await archivoDestino.writeAsBytes(datos);
      } else {
        await Directory(rutaDestino).create(recursive: true);
      }
    }

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
      await File(rutaZipTemp).delete();
    } catch (_) {}
  }

  exit(0);
}