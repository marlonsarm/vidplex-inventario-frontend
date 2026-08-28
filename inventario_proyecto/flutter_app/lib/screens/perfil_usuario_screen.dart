import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../config.dart';
import '../theme.dart';

class PerfilUsuarioScreen extends StatefulWidget {
  final String token;

  const PerfilUsuarioScreen({super.key, required this.token});

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  Map<String, dynamic>? _perfil;
  List<dynamic> _movimientos = [];
  bool _cargando = true;
  String? _error;
  Uint8List? _imagenBytes;
  bool _subiendoFoto = false;
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final perfil = await ApiService.obtenerPerfil(widget.token);
      final movimientos = await ApiService.getHistorialUsuario(widget.token, perfil['id']);
      setState(() {
        _perfil = perfil;
        _movimientos = movimientos;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _cargando = false);
    }
  }

  String _formatearFecha(String fechaIso) {
    final fecha = DateTime.parse(fechaIso);
    return DateFormat('dd/MM/yyyy hh:mm a').format(fecha);
  }

  Future<void> _cambiarFoto() async {
    final picker = ImagePicker();
    final XFile? archivo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (archivo == null || _perfil == null) return;

    final bytes = await archivo.readAsBytes();
    setState(() {
      _imagenBytes = bytes;
      _subiendoFoto = true;
    });

    try {
      await ApiService.subirFotoUsuario(widget.token, _perfil!['id'], bytes, archivo.name);
      await _cargarDatos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto actualizada'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
      );
    } finally {
      if (mounted) {
        setState(() {
          _imagenBytes = null;
          _subiendoFoto = false;
        });
      }
    }
  }

  Widget _encabezadoPerfil() {
    final nombre = _perfil?['nombre_completo'] ?? '';
    final fotoUrl = _perfil?['foto_url'];
    final esSuperAdmin = _perfil?['es_super_admin'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.negro2, AppColors.negro3],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.acento.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _subiendoFoto ? null : _cambiarFoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.acento, AppColors.acento.withValues(alpha: 0.6)],
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.acento.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4)),
                    ],
                    image: _imagenBytes != null
                        ? DecorationImage(image: MemoryImage(_imagenBytes!), fit: BoxFit.cover)
                        : (fotoUrl != null && fotoUrl.toString().isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage('${AppConfig.baseUrl}$fotoUrl'),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: _subiendoFoto
                      ? const CircularProgressIndicator(color: Colors.white)
                      : (_imagenBytes == null && (fotoUrl == null || fotoUrl.toString().isEmpty))
                          ? Text(
                              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 36),
                            )
                          : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.acento,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.negro2, width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(nombre, style: AppTextStyles.titulo(size: 18)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.acentoSuave,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.acento.withValues(alpha: 0.25)),
            ),
            child: Text(
              esSuperAdmin ? 'Super Admin' : 'Usuario',
              style: AppTextStyles.cuerpo(size: 12.5, peso: FontWeight.w700, color: AppColors.acento),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _perfil?['email'] ?? '',
            style: AppTextStyles.subtitulo(size: 12.5, color: AppColors.gris),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(title: const Text('Mi perfil')),
      body: RefreshIndicator(
        color: AppColors.acento,
        backgroundColor: AppColors.negro2,
        onRefresh: _cargarDatos,
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: AppColors.acento))
            : _error != null
                ? Center(child: Text(_error!, style: AppTextStyles.cuerpo(color: AppColors.rojoAlerta)))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _encabezadoPerfil(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
                        child: Text('Mis movimientos', style: AppTextStyles.titulo(size: 15)),
                      ),
                      if (_movimientos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              'Todavía no tienes movimientos registrados',
                              style: AppTextStyles.cuerpo(color: AppColors.gris),
                            ),
                          ),
                        )
                      else
                        ..._movimientos.map((mov) {
                          final esEntrada = mov['tipo'] == 'entrada';
                          final colorTema = esEntrada ? AppColors.verdeOk : AppColors.rojoAlerta;
                          return Container(
                            margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.negro2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.grisLinea),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorTema.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    esEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: colorTema,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        esEntrada ? '+${mov['cantidad']} entrada' : '-${mov['cantidad']} salida',
                                        style: AppTextStyles.cuerpo(size: 13, peso: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _formatearFecha(mov['fecha']),
                                        style: AppTextStyles.subtitulo(size: 11.5, color: AppColors.gris),
                                      ),
                                      if (mov['motivo'] != null && mov['motivo'].toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Text(
                                            mov['motivo'],
                                            style: AppTextStyles.subtitulo(size: 11.5, color: AppColors.gris),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Stock: ${mov['stock_resultante']}',
                                  style: AppTextStyles.cuerpo(size: 12, peso: FontWeight.w600, color: AppColors.gris),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}