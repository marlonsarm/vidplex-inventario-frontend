import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> descargarExcelWeb(Uint8List bytes, String nombreArchivo) async {
  await FilePicker.saveFile(
    fileName: nombreArchivo,
    bytes: bytes,
    mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    dialogTitle: 'Guardar Excel',
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
}