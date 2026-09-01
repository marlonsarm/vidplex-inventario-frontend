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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _irALogin();
      return;
    }

    try {
      final perfil = await ApiService.obtenerPerfil(token);

      // Refresca los permisos guardados por si cambiaron desde el último login
      await prefs.setBool('es_super_admin', perfil['es_super_admin']);
      await prefs.setBool('puede_ver_stock', perfil['puede_ver_stock']);
      await prefs.setBool('puede_registrar_entrada', perfil['puede_registrar_entrada']);
      await prefs.setBool('puede_registrar_salida', perfil['puede_registrar_salida']);
     await prefs.setBool('puede_crear_productos', perfil['puede_crear_productos']);
      await prefs.setBool('puede_transferir', perfil['puede_transferir'] ?? false);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            token: token,
            nombre: perfil['nombre_completo'],
            esSuperAdmin: perfil['es_super_admin'],
            puedeCrearProductos: perfil['puede_crear_productos'],
            puedeRegistrarEntrada: perfil['puede_registrar_entrada'],
            puedeRegistrarSalida: perfil['puede_registrar_salida'],
            puedeTransferir: perfil['puede_transferir'] ?? false,
          ),
        ),
      );
    } catch (e) {
      // El token ya no es válido (expiró o el usuario fue desactivado)
      await prefs.remove('token');
      _irALogin();
    }
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