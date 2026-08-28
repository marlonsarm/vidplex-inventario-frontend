import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> descargarExcelWeb(Uint8List bytes, String nombreArchivo) async {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = nombreArchivo;
  anchor.click();
  web.URL.revokeObjectURL(url);
}