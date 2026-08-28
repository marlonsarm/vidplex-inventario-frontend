import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _cedulaController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _cargando = false;
  bool _recordarCedula = true;
  bool _verPassword = false;
  String? _mensajeError;

late final AnimationController _brilloController;
  late final AnimationController _logoController;
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _cargarCedulaGuardada();
    _brilloController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  Future<void> _cargarCedulaGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final cedulaGuardada = prefs.getString('cedula_recordada');
    if (cedulaGuardada != null) {
      setState(() {
        _cedulaController.text = cedulaGuardada;
      });
    }
  }

  Future<void> _iniciarSesion() async {
    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    try {
      final resultado = await ApiService.login(
        _cedulaController.text.trim(),
        _passwordController.text,
      );

      final token = resultado['access_token'];
      final usuario = resultado['usuario'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('nombre', usuario['nombre']);
      await prefs.setBool('es_super_admin', usuario['es_super_admin']);
      await prefs.setBool('puede_ver_stock', usuario['puede_ver_stock']);
      await prefs.setBool('puede_registrar_entrada', usuario['puede_registrar_entrada']);
      await prefs.setBool('puede_registrar_salida', usuario['puede_registrar_salida']);
      await prefs.setBool('puede_crear_productos', usuario['puede_crear_productos']);
      await prefs.setBool('puede_eliminar_facturas', usuario['puede_eliminar_facturas'] ?? false);
      await prefs.setBool('puede_ver_facturas', usuario['puede_ver_facturas'] ?? false);
      await prefs.setString('foto_url', usuario['foto_url'] ?? '');
      await prefs.setString('cargo', usuario['cargo'] ?? '');
      await prefs.setString('cedula', usuario['cedula'] ?? '');

      if (_recordarCedula) {
        await prefs.setString('cedula_recordada', _cedulaController.text.trim());
      } else {
        await prefs.remove('cedula_recordada');
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            token: token,
            nombre: usuario['nombre'],
            fotoUrl: usuario['foto_url'],
            esSuperAdmin: usuario['es_super_admin'],
            puedeCrearProductos: usuario['puede_crear_productos'],
            puedeRegistrarEntrada: usuario['puede_registrar_entrada'],
            puedeRegistrarSalida: usuario['puede_registrar_salida'],
            puedeEliminarFacturas: usuario['puede_eliminar_facturas'] ?? false,
            puedeVerFacturas: usuario['puede_ver_facturas'] ?? false,
            cargo: usuario['cargo'] ?? '',
            cedula: usuario['cedula'] ?? '',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _mensajeError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _passwordController.dispose();
    _brilloController.dispose();
    _logoController.dispose();
    _dotsController.dispose();
    super.dispose();
  }Widget _logoAnimado() {
 const letras = ['I', 'N', 'V', 'P', 'L', 'E', 'X'];

    return SizedBox(
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Barra de brillo pulsante debajo del texto
          Positioned(
            bottom: 6,
            child: AnimatedBuilder(
              animation: _brilloController,
              builder: (context, child) {
                final pulso = 1 - (_brilloController.value - 0.5).abs() * 2;
                return Container(
                  width: 130 + pulso * 20,
                  height: 2.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.acento.withValues(alpha: 0.35 + pulso * 0.4),
                        AppColors.dorado.withValues(alpha: 0.35 + pulso * 0.4),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.acento.withValues(alpha: 0.3 + pulso * 0.3), blurRadius: 8 + pulso * 6),
                    ],
                  ),
                );
              },
            ),
          ),
          // Texto metálico con ola letra por letra
          AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              final t = _logoController.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(letras.length, (i) {
                  final delay = i * 0.018;
                  final local = ((t - delay) % 1.0 + 1.0) % 1.0;
                  double onda = 0;
                  if (local > 0.90) {
                    final p = (local - 0.90) / 0.10;
                    onda = p < 0.5 ? p / 0.5 : 1 - (p - 0.5) / 0.5;
                  }
                  final brillo = onda;
                  return Transform.translate(
                    offset: Offset(0, -onda * 5),
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFD6DEE8),
                          Color(0xFF98A6B5),
                          Color(0xFF5C6B7A),
                          Color(0xFF8B99A8),
                        ],
                        stops: [0.0, 0.2, 0.5, 0.72, 1.0],
                      ).createShader(bounds),
                      child: Text(
                        letras[i],
                        style: AppTextStyles.titulo(size: 44).copyWith(
                          letterSpacing: 4.5,
                          shadows: [
                            const Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                            Shadow(color: AppColors.acento.withValues(alpha: 0.15 + brillo * 0.45), blurRadius: 14),
                            Shadow(color: Colors.white.withValues(alpha: 0.2 + brillo * 0.55), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          // Chispita tipo estrella
          Positioned(
            top: -8,
            right: -14,
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                final t = _logoController.value;
                double op = 0;
                if (t > 0.85) {
                  final p = (t - 0.85) / 0.15;
                  op = p < 0.5 ? p * 2 : (1 - p) * 2;
                }
                return Opacity(
                  opacity: op.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.5 + op * 0.6,
                    child: Transform.rotate(
                      angle: 0.8,
                      child: const Icon(Icons.auto_awesome, size: 15, color: AppColors.blanco),
                    ),
                  ),
                );
              },
            ),
          ),
          // Puntos de acento (naranja, dorado, amarillo)
          Positioned(
            top: -12,
            right: 6,
            child: AnimatedBuilder(
              animation: _dotsController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _puntoLogo(AppColors.acento, 0.0),
                    const SizedBox(width: 4),
                    _puntoLogo(AppColors.dorado, 0.09),
                    const SizedBox(width: 4),
                    _puntoLogo(const Color(0xFFF3D250), 0.18),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _puntoLogo(Color color, double delay) {
    final t = _dotsController.value;
    final local = ((t - delay) % 1.0 + 1.0) % 1.0;
    final pulso = local < 0.4 ? local / 0.4 : (local < 0.8 ? 1 - (local - 0.4) / 0.4 : 0.0);
    return Transform.scale(
      scale: 1 + pulso * 0.2,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.5 + pulso * 0.4), blurRadius: 4 + pulso * 5, spreadRadius: 0.5),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF071231),
                  Color(0xFF0B1E4D),
                  AppColors.acentoOscuro,
                  Color(0xFF0B1E4D),
                ],
                stops: [0.0, 0.35, 0.68, 1.0],
              ),
            ),
          ),
          Positioned(top: -160, right: -120, child: _blob(420, AppColors.acento.withValues(alpha: 0.35))),
          Positioned(bottom: -200, left: -160, child: _blob(480, AppColors.dorado.withValues(alpha: 0.10))),
          Positioned(top: 180, left: -80, child: _blob(220, Colors.white.withValues(alpha: 0.05))),
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _LineasDiagonalesPainter()))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _brilloController,
                                    builder: (context, child) {
                                      return Container(
                                        width: 104,
                                        height: 104,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.25 + 0.35 * (1 - (_brilloController.value - 0.5).abs() * 2),
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    width: 88,
                                    height: 88,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Colors.white, Color(0xFFDCE6F5)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(color: AppColors.acento.withValues(alpha: 0.55), blurRadius: 36, spreadRadius: 2),
                                      ],
                                    ),
                                    child: Transform.scale(scale: 1.35, child: Image.asset('assets/images/logo_vidplex.png', fit: BoxFit.contain)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _logoAnimado(),
                              const SizedBox(height: 10),
                              Text(
                                'SISTEMA DE INVENTARIO',
                                style: AppTextStyles.etiqueta(size: 12, color: Colors.white.withValues(alpha: 0.75)),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                  child: Container(
                                    padding: const EdgeInsets.all(AppSpacing.lg),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.97),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: -6, offset: const Offset(0, 22)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          height: 4,
                                          width: 46,
                                          margin: const EdgeInsets.only(bottom: 18),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(colors: [AppColors.acento, AppColors.acentoOscuro]),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        TextField(
                                          controller: _cedulaController,
                                          style: AppTextStyles.cuerpo(),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Cédula',
                                            prefixIcon: Icon(Icons.badge_outlined, color: AppColors.gris),
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        TextField(
                                          controller: _passwordController,
                                          obscureText: !_verPassword,
                                          style: AppTextStyles.cuerpo(),
                                          decoration: InputDecoration(
                                            labelText: 'Contraseña',
                                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.gris),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                color: AppColors.gris,
                                              ),
                                              onPressed: () => setState(() => _verPassword = !_verPassword),
                                            ),
                                          ),
                                          onSubmitted: (_) => _iniciarSesion(),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _recordarCedula,
                                              activeColor: AppColors.acento,
                                              onChanged: (valor) => setState(() => _recordarCedula = valor ?? true),
                                            ),
                                            Text('Recordar mi cédula', style: AppTextStyles.cuerpo(size: 13, color: AppColors.gris)),
                                          ],
                                        ),
                                        if (_mensajeError != null) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppColors.rojoAlerta.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppColors.rojoAlerta.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              _mensajeError!,
                                              style: AppTextStyles.cuerpo(size: 13, color: AppColors.rojoAlerta),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: AppSpacing.md),
                                        Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(AppRadius.boton),
                                            gradient: const LinearGradient(colors: [AppColors.acento, AppColors.acentoOscuro], begin: Alignment.centerLeft, end: Alignment.centerRight),
                                            boxShadow: [
                                              BoxShadow(color: AppColors.acento.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: -4, offset: const Offset(0, 10)),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(AppRadius.boton),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(AppRadius.boton),
                                              onTap: _cargando ? null : _iniciarSesion,
                                              child: Center(
                                                child: _cargando
                                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                    : Text(
                                                        'INICIAR SESIÓN',
                                                        style: AppTextStyles.cuerpo(size: 14.5, color: Colors.white, peso: FontWeight.w800).copyWith(letterSpacing: 1.2),
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Builder(
                                builder: (context) {
                                  const meses = [
                                    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
                                    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
                                  ];
                                  final ahora = DateTime.now();
                                  final fecha = '${ahora.day} de ${meses[ahora.month - 1]} de ${ahora.year}';
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, size: 4, color: Colors.white.withValues(alpha: 0.4)),
                                      const SizedBox(width: 8),
                                      Text(
                                        fecha,
                                        style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.55), letterSpacing: 0.6, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.circle, size: 4, color: Colors.white.withValues(alpha: 0.4)),
                                    ],
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double tamano, Color color) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _LineasDiagonalesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1.2;
    const espaciado = 46.0;
    for (double x = -size.height; x < size.width; x += espaciado) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}