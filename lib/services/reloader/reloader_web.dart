import 'dart:html' as html;

Future<void> recargarApp(
  String? urlDescargaWindows, {
  void Function(double progreso)? onProgreso,
}) async {
  html.window.location.reload();
}