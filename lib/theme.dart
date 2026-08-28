import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño central de InvPlex, inspirado en la identidad
/// de marca de Vidplex: fondo oscuro premium, acento naranja,
/// tipografía Archivo Black para títulos + Inter para el resto.
class AppColors {
  static const negro = Color(0xFFF5F6F8);      // fondo principal, gris frío neutro
  static const negro2 = Color(0xFFFFFFFF);     // tarjetas, blanco puro
  static const negro3 = Color(0xFFEEF0F3);     // elementos elevados, gris claro
  static const blanco = Color(0xFF1A1D23);     // texto principal, slate oscuro
  static const gris = Color(0xFF6B7280);       // texto secundario, slate gris
  static const grisLinea = Color(0xFFE2E5EA);
  static const acento = Color(0xFF0052FF);     // azul eléctrico, mucho más vivo
  static const acentoOscuro = Color(0xFF0038B8); // para gradientes en botones
  static const acentoSuave = Color(0x290052FF);
  static const dorado = Color(0xFFE6A800);     // dorado, usado en marca InvPlex
  static const ambarBajo = Color(0xFFE08A00);  // ámbar con más presencia para stock bajo
  static const verdeOk = Color(0xFF0EA85C);    // verde vivo, entrada de stock
  static const rojoAlerta = Color(0xFFE2352A); // rojo vivo, salida de stock
}

/// Marca animada de InvPlex: texto con brillo sutil + 3 puntos de acento,
/// inspirado en el logo de VidPlex pero adaptado al tema claro.
class InvPlexMark extends StatefulWidget {
  final double size;
  const InvPlexMark({super.key, this.size = 15});

  @override
  State<InvPlexMark> createState() => _InvPlexMarkState();
}

class _InvPlexMarkState extends State<InvPlexMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final shine = _controller.value;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: const [AppColors.blanco, AppColors.acento, AppColors.blanco],
                  stops: [
                    (shine - 0.3).clamp(0.0, 1.0),
                    shine.clamp(0.0, 1.0),
                    (shine + 0.3).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds);
              },
           child: Text(
                'VIDPLEX',
                style: GoogleFonts.archivoBlack(
                  fontSize: widget.size,
                  color: AppColors.blanco,
                  letterSpacing: 1.4,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final colores = [AppColors.acento, AppColors.dorado, AppColors.verdeOk];
            return Row(
              children: List.generate(3, (i) {
                final t = (_controller.value + i * 0.2) % 1.0;
                final pulso = 0.85 + (0.3 * (1 - (t - 0.5).abs() * 2)).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Transform.scale(
                    scale: pulso,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colores[i],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: colores[i].withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 0.5),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class AppSpacing {
  static const xs = 6.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 40.0;
}

class AppRadius {
  static const card = 16.0;
  static const boton = 999.0; // píldora
  static const chip = 999.0;
}

class AppShadows {
  static const card = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 14,
    spreadRadius: -2,
    offset: Offset(0, 5),
  );
  static const elevated = BoxShadow(
    color: Color(0x60000000),
    blurRadius: 22,
    spreadRadius: -4,
    offset: Offset(0, 9),
  );
  static const glowAcento = BoxShadow(
    color: Color(0x660052FF),
    blurRadius: 26,
    spreadRadius: -3,
    offset: Offset(0, 8),
  );
}

class AppTextStyles {
  static TextStyle titulo({double size = 24, Color color = AppColors.blanco}) {
    return GoogleFonts.archivoBlack(
      fontSize: size,
      color: color,
      letterSpacing: 0.3,
      height: 1.08,
    );
  }

  static TextStyle subtitulo({double size = 14, Color color = AppColors.gris}) {
    return GoogleFonts.inter(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w500,
    );
  }

  static TextStyle cuerpo({double size = 14, Color color = AppColors.blanco, FontWeight peso = FontWeight.normal}) {
    return GoogleFonts.inter(fontSize: size, color: color, fontWeight: peso);
  }

  static TextStyle etiqueta({double size = 11, Color color = AppColors.acento}) {
    return GoogleFonts.inter(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );
  }
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.negro,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.acento,
   brightness: Brightness.light,
      primary: AppColors.acento,
      surface: AppColors.negro2,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.negro,
      foregroundColor: AppColors.blanco,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.titulo(size: 18),
    ),
    cardTheme: CardThemeData(
      color: AppColors.negro2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.grisLinea, width: 1.4),
      ),
      margin: EdgeInsets.zero,
    ),
elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.acento,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.boton)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        overlayColor: Colors.black.withValues(alpha: 0.15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blanco,
        side: const BorderSide(color: AppColors.grisLinea),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.boton)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.negro2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.grisLinea),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.grisLinea),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.acento, width: 2.2),
      ),
      labelStyle: const TextStyle(color: AppColors.gris),
      hintStyle: const TextStyle(color: AppColors.gris),
    ),
    iconTheme: const IconThemeData(color: AppColors.blanco),
    dividerColor: AppColors.grisLinea,
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.negro2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.negro3,
      contentTextStyle: const TextStyle(color: AppColors.blanco),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}