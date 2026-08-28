// Test de humo: verifica que la pantalla de login cargue correctamente
// con sus elementos principales, sin depender del contador de ejemplo
// que Flutter genera por defecto.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/screens/login_screen.dart';

void main() {
  testWidgets('La pantalla de login muestra los campos principales', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pump();

    // Verifica que los campos de cédula y contraseña estén presentes.
    expect(find.text('Cédula'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);

    // Verifica que el botón de iniciar sesión esté presente.
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
  });
}