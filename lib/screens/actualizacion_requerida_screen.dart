import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/reloader/reloader.dart';

/// Pantalla que bloquea el uso de la app cuando el backend indica que la
/// versión instalada quedó desactualizada. No tiene forma de cerrarla:
/// el usuario debe actualizar para poder continuar.
class ActualizacionRequeridaScreen extends StatelessWidget {
  final String? urlDescargaWindows;

  const ActualizacionRequeridaScreen({super.key, this.urlDescargaWindows});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update_alt, color: AppColors.acento, size: 64),
              const SizedBox(height: 24),
              Text(
                'Hay una nueva versión disponible',
                textAlign: TextAlign.center,
                style: AppTextStyles.titulo(size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                'Debes actualizar InvPlex para seguir usándolo.',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitulo(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => recargarApp(urlDescargaWindows),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar ahora'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acento,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.boton)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}