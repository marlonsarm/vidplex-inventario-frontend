import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../config.dart';
import '../theme.dart';
class HistorialScreen extends StatefulWidget {
  final String token;
  final int productoId;
  final String nombreProducto;
  final String? fotoUrl;

  const HistorialScreen({
    super.key,
    required this.token,
    required this.productoId,
    required this.nombreProducto,
    this.fotoUrl,
  });

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<dynamic> _movimientos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final movimientos = await ApiService.getHistorial(widget.token, widget.productoId);
      setState(() => _movimientos = movimientos);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.negro,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.blanco,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, AppColors.acento, Colors.transparent]),
            ),
          ),
        ),
        title: Text(
          'Historial: ${widget.nombreProducto}',
          style: AppTextStyles.cuerpo(size: 15, peso: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
      ),
     body: RefreshIndicator(
        color: AppColors.acento,
        backgroundColor: AppColors.negro2,
        onRefresh: _cargarHistorial,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _movimientos.isEmpty
                    ? const Center(child: Text('Este producto todavía no tiene movimientos'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _movimientos.length + (widget.fotoUrl != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (widget.fotoUrl != null && index == 0) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    '${AppConfig.baseUrl}${widget.fotoUrl}',
                                    height: 160,
                                    width: 160,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          }
                          final movIndex = widget.fotoUrl != null ? index - 1 : index;
                          final mov = _movimientos[movIndex];
                          final esEntrada = mov['tipo'] == 'entrada';

                          final colorTema = esEntrada ? AppColors.verdeOk : AppColors.rojoAlerta;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.negro2,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: AppColors.grisLinea),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colorTema.withValues(alpha: 0.14),
                                child: Icon(
                                  esEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: colorTema,
                                ),
                              ),
                              title: Text(
                                esEntrada
                                    ? '+${mov['cantidad']} entrada'
                                    : '-${mov['cantidad']} salida',
                                style: AppTextStyles.cuerpo(size: 14, peso: FontWeight.w700, color: colorTema),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Por: ${mov['usuario_nombre']}', style: AppTextStyles.subtitulo(size: 12)),
                                  Text(_formatearFecha(mov['fecha']), style: AppTextStyles.subtitulo(size: 12)),
                                  if (mov['motivo'] != null && mov['motivo'].toString().isNotEmpty)
                                    Text('Motivo: ${mov['motivo']}', style: AppTextStyles.subtitulo(size: 12).copyWith(fontStyle: FontStyle.italic)),
                                ],
                              ),
                              trailing: Text(
                                'Stock: ${mov['stock_resultante']}',
                                style: AppTextStyles.cuerpo(size: 13, peso: FontWeight.w700),
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}



