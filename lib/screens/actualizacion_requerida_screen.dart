import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/reloader/reloader.dart';

/// Pantalla que bloquea el uso de la app cuando el backend indica que la
/// versión instalada quedó desactualizada. No tiene forma de cerrarla:
/// el usuario debe actualizar para poder continuar.
class ActualizacionRequeridaScreen extends StatefulWidget {
  final String? urlDescargaWindows;

  const ActualizacionRequeridaScreen({super.key, this.urlDescargaWindows});

  @override
  State<ActualizacionRequeridaScreen> createState() => _ActualizacionRequeridaScreenState();
}

class _ActualizacionRequeridaScreenState extends State<ActualizacionRequeridaScreen> {
  bool _actualizando = false;
  double _progreso = 0.0;
  String? _error;

  Future<void> _iniciarActualizacion() async {
    setState(() {
      _actualizando = true;
      _error = null;
    });
    try {
      await recargarApp(
        widget.urlDescargaWindows,
        onProgreso: (p) {
          if (mounted) setState(() => _progreso = p);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actualizando = false;
        _error = e.toString();
      });
    }
  }

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
                _error != null
                    ? 'Error al actualizar: $_error'
                    : _actualizando
                        ? 'Descargando actualización...'
                        : 'Debes actualizar InvPlex para seguir usándolo.',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitulo(
                  color: _error != null ? AppColors.rojoAlerta : AppColors.gris,
                ),
              ),
              const SizedBox(height: 28),
              if (_actualizando) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.boton),
                  child: LinearProgressIndicator(
                    value: _progreso > 0 ? _progreso : null,
                    minHeight: 10,
                    backgroundColor: AppColors.negro2,
                    color: AppColors.acento,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progreso * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.subtitulo(),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _iniciarActualizacion,
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