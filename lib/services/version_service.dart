import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class VersionService {
  /// Compara dos versiones tipo "1.2.3". Devuelve true si [actual] es
  /// MENOR que [minima], es decir, si hay que bloquear y forzar actualizar.
  static bool necesitaActualizar(String actual, String minima) {
    final partesActual = actual.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final partesMinima = minima.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final longitud = partesActual.length > partesMinima.length ? partesActual.length : partesMinima.length;

    for (var i = 0; i < longitud; i++) {
      final a = i < partesActual.length ? partesActual[i] : 0;
      final m = i < partesMinima.length ? partesMinima[i] : 0;
      if (a != m) return a < m;
    }
    return false; // son iguales, no hace falta actualizar
  }
  /// Consulta al backend cuál es la versión mínima requerida ahora mismo,
  /// junto con la URL de descarga del paquete de actualización para Windows.
  /// Si falla (sin internet, backend caído, etc.) devuelve todo en null y NO
  /// se bloquea al usuario: es mejor dejarlo trabajar que tumbarlo por un
  /// problema de red pasajero.
  static Future<({String? versionMinima, String? urlDescargaWindows})> obtenerInfoVersion() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/version/');
      final respuesta = await http.get(url).timeout(const Duration(seconds: 5));

      if (respuesta.statusCode == 200) {
        final data = jsonDecode(respuesta.body);
        return (
          versionMinima: data['version_minima'] as String?,
          urlDescargaWindows: data['url_descarga_windows'] as String?,
        );
      }
      return (versionMinima: null, urlDescargaWindows: null);
    } catch (e) {
      return (versionMinima: null, urlDescargaWindows: null);
    }
  }
}