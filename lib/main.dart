import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/actualizacion_requerida_screen.dart';
import 'services/api_service.dart';
import 'services/version_service.dart';
import 'config.dart';
import 'theme.dart';
void main() {
  runApp(const InvPlexApp());
}

class InvPlexApp extends StatelessWidget {
  const InvPlexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InvPlex',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const DecisorDeInicio(),
    );
  }
}

/// Al abrir la app (o recargar la página), revisa si ya había una sesión
/// guardada y activa. Si sigue siendo válida, entra directo al Dashboard
/// sin pedir correo/contraseña de nuevo.
class DecisorDeInicio extends StatefulWidget {
  const DecisorDeInicio({super.key});

  @override
  State<DecisorDeInicio> createState() => _DecisorDeInicioState();
}

class _DecisorDeInicioState extends State<DecisorDeInicio> {
  @override
  void initState() {
    super.initState();
    _revisarVersionYSesion();
  }

  Future<void> _revisarVersionYSesion() async {
    final info = await VersionService.obtenerInfoVersion();
    final versionMinima = info.versionMinima;

    if (versionMinima != null &&
        VersionService.necesitaActualizar(AppConfig.appVersion, versionMinima)) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActualizacionRequeridaScreen(
            urlDescargaWindows: info.urlDescargaWindows,
          ),
        ),
      );
      return;
    }

    await _revisarSesion();
  }

  Future<void> _revisarSesion() async {
    // Por seguridad, cada vez que se abre la app (o se vuelve a abrir tras
    // cerrarla, o tras apagar/prender el PC) se exige iniciar sesión de
    // nuevo. No se reutiliza ninguna sesión guardada de una vez anterior.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _irALogin();
  }

  void _irALogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.negro,
      body: Center(child: CircularProgressIndicator(color: AppColors.acento)),
    );
  }
}