import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../config.dart';

/// Todo lo relacionado con revisar y aplicar actualizaciones de la app de escritorio.
class UpdaterService {
  /// Consulta al backend si hay una versión más nueva que la instalada.
  /// Devuelve null si la app ya está actualizada, o un mapa con
  /// {version_minima, url_descarga_windows} si hay que actualizar.
  static Future<Map<String, dynamic>?> verificarActualizacion() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/version/');
      final respuesta = await http.get(url).timeout(const Duration(seconds: 8));

      if (respuesta.statusCode != 200) return null;

      final data = jsonDecode(respuesta.body);
      final versionMinima = data['version_minima'] as String;

      final infoApp = await PackageInfo.fromPlatform();
      final versionActual = infoApp.version;

      if (_esVersionMenor(versionActual, versionMinima)) {
        return data;
      }
      return null;
    } catch (_) {
      // Si falla la consulta (sin internet, backend caído, etc.) no bloqueamos
      // el login por esto — simplemente se deja pasar y se reintenta la próxima vez.
      return null;
    }
  }

  /// Compara dos versiones tipo "1.0.0". Devuelve true si [actual] es menor que [minima].
  static bool _esVersionMenor(String actual, String minima) {
    final partesActual = actual.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final partesMinima = minima.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    for (var i = 0; i < partesMinima.length; i++) {
      final a = i < partesActual.length ? partesActual[i] : 0;
      final m = partesMinima[i];
      if (a < m) return true;
      if (a > m) return false;
    }
    return false;
  }

  /// Descarga el zip de la nueva versión reportando el progreso (0.0 a 1.0),
  /// y cuando termina lanza Updater.exe pasándole la ruta local del zip
  /// y la ruta del ejecutable actual, y cierra la app.
  static Future<void> descargarYActualizar({
    required String urlZip,
    required void Function(double progreso) onProgreso,
  }) async {
    final rutaZipLocal = '${Directory.systemTemp.path}\\invplex_update.zip';

    final request = http.Request('GET', Uri.parse(urlZip));
    final respuesta = await http.Client().send(request);

    final total = respuesta.contentLength ?? 0;
    var recibido = 0;

    final archivo = File(rutaZipLocal).openWrite();

    await respuesta.stream.listen((chunk) {
      recibido += chunk.length;
      archivo.add(chunk);
      if (total > 0) {
        onProgreso(recibido / total);
      }
    }).asFuture();

    await archivo.close();

    final rutaExeApp = Platform.resolvedExecutable;
    final carpetaApp = File(rutaExeApp).parent.path;

    await Process.start(
      '$carpetaApp\\Updater.exe',
      [rutaZipLocal, rutaExeApp],
      mode: ProcessStartMode.detached,
      workingDirectory: carpetaApp,
    );

    exit(0);
  }
}