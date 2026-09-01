import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Uso: Updater.exe <url_zip> <ruta_exe_app>');
    exit(1);
  }

  final origenZip = args[0];
  final rutaExeApp = args[1];
  final esUrlRemota = origenZip.startsWith('http://') || origenZip.startsWith('https://');
  final carpetaApp = File(rutaExeApp).parent.path;
  final nombreExeApp = File(rutaExeApp).uri.pathSegments.last;

  // Espera un momento para que InvPlex.exe termine de cerrarse del todo
  // y libere los archivos (puede tardar un instante en soltar el lock).
  await Future.delayed(const Duration(seconds: 2));

  String rutaZip;
  if (esUrlRemota) {
    rutaZip = '${Directory.systemTemp.path}\\invplex_update.zip';
    print('Descargando actualización...');
    await _descargarConReintentos(origenZip, rutaZip);
  } else {
    print('Actualización ya descargada, aplicando...');
    rutaZip = origenZip;
  }

  print('Aplicando actualización...');
  await _extraerConReintentos(rutaZip, carpetaApp);

  try {
    File(rutaZip).deleteSync();
  } catch (_) {
    // No es crítico si no se pudo borrar el temporal.
  }

  print('Reabriendo InvPlex...');
  await Process.start(
    '$carpetaApp\\$nombreExeApp',
    [],
    mode: ProcessStartMode.detached,
    workingDirectory: carpetaApp,
  );

  exit(0);
}

Future<void> _descargarConReintentos(String url, String destino) async {
  const intentosMaximos = 3;
  for (var intento = 1; intento <= intentosMaximos; intento++) {
    try {
      final respuesta = await http.get(Uri.parse(url));
      if (respuesta.statusCode == 200) {
        await File(destino).writeAsBytes(respuesta.bodyBytes);
        return;
      }
      throw Exception('Respuesta ${respuesta.statusCode} al descargar');
    } catch (e) {
      if (intento == intentosMaximos) rethrow;
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}

Future<void> _extraerConReintentos(String rutaZip, String carpetaDestino) async {
  const intentosMaximos = 5;
  for (var intento = 1; intento <= intentosMaximos; intento++) {
    try {
      final bytes = File(rutaZip).readAsBytesSync();
      final archivo = ZipDecoder().decodeBytes(bytes);

      for (final entrada in archivo) {
        final rutaSalida = '$carpetaDestino/${entrada.name}';
        if (entrada.isFile) {
          final datos = entrada.content as List<int>;
          File(rutaSalida)
            ..createSync(recursive: true)
            ..writeAsBytesSync(datos);
        } else {
          Directory(rutaSalida).createSync(recursive: true);
        }
      }
      return;
    } catch (e) {
      if (intento == intentosMaximos) rethrow;
      // Probablemente InvPlex.exe todavía no soltó el archivo; reintenta.
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}