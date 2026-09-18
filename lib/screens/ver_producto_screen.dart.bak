import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'editar_producto_screen.dart';
import 'historial_screen.dart';

class VerProductoScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> producto;
  final bool puedeEditar;
  final bool puedeRegistrarEntrada;
  final bool puedeRegistrarSalida;

  const VerProductoScreen({
    super.key,
    required this.token,
    required this.producto,
    required this.puedeEditar,
    this.puedeRegistrarEntrada = false,
    this.puedeRegistrarSalida = false,
  });

  @override
  State<VerProductoScreen> createState() => _VerProductoScreenState();
}

class _VerProductoScreenState extends State<VerProductoScreen> {
  late Map<String, dynamic> _producto;
  bool _esSuperAdmin = false;
  List<dynamic> _secciones = [];
  String _nombreAlmacenActual = '';
  bool _huboCambios = false;

  static const int _idCuartoMantenimiento = 1;
  bool get _enCuartoMantenimiento => _producto['seccion_id'] == _idCuartoMantenimiento;

  String _nombreInventario(String nombreCrudo) {
    if (nombreCrudo.toLowerCase().contains('mantenimiento')) return 'Inventario de Herramientas';
    return 'Inventario $nombreCrudo';
  }

  @override
  void initState() {
    super.initState();
    _producto = widget.producto;
    _cargarAlmacen();
  }

  Future<void> _cargarAlmacen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final esAdmin = prefs.getBool('es_super_admin') ?? false;
      final secciones = esAdmin
          ? await ApiService.getTodasLasSecciones(widget.token)
          : await ApiService.getSecciones(widget.token);
      if (!mounted) return;
      final actual = secciones.firstWhere(
        (s) => s['id'] == _producto['seccion_id'],
        orElse: () => null,
      );
      setState(() {
        _esSuperAdmin = esAdmin;
        _secciones = secciones;
        _nombreAlmacenActual = actual != null ? actual['nombre'] : 'Sin almacén';
      });
    } catch (e) {
      // si falla, la fila de almacén simplemente muestra "Sin almacén"
    }
  }

  Widget _filaDato(IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, size: 16, color: const Color(0xFF1E3A5F)),
          ),
          const SizedBox(width: 14),
          Text(etiqueta, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearPrecio(dynamic valor) {
    final numero = double.tryParse(valor.toString()) ?? 0;
    final entero = numero.round();
    final texto = entero.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < texto.length; i++) {
      if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
      buffer.write(texto[i]);
    }
    return '\$$buffer';
  }

  Future<void> _moverDeAlmacenRapido() async {
    if (_secciones.isEmpty) return;

    final nuevoAlmacenId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mover a inventario', style: AppTextStyles.titulo(size: 16)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _secciones.map((s) {
                  final esActual = s['id'] == _producto['seccion_id'];
                  return ActionChip(
                    label: Text(
                      _nombreInventario(s['nombre']),
                      style: AppTextStyles.cuerpo(size: 12.5, color: esActual ? Colors.white : AppColors.acento),
                    ),
                    backgroundColor: esActual ? AppColors.acento : AppColors.acentoSuave,
                    side: BorderSide(color: AppColors.acento.withValues(alpha: esActual ? 1 : 0.3)),
                    onPressed: esActual ? null : () => Navigator.of(context).pop(s['id'] as int),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );

    if (nuevoAlmacenId == null || !context.mounted) return;

    try {
      final actualizado = await ApiService.editarProducto(
        token: widget.token,
        productoId: _producto['id'],
        seccionId: nuevoAlmacenId,
      );
      if (!context.mounted) return;
      final nuevoNombre = _secciones.firstWhere((s) => s['id'] == nuevoAlmacenId)['nombre'];
      setState(() {
        _producto = {..._producto, 'seccion_id': actualizado['seccion_id']};
        _nombreAlmacenActual = nuevoNombre;
        _huboCambios = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Movido a "$nuevoNombre"'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _moverResponsableRapido() async {
    const opciones = ['HERRAMIENTAS JAIME', 'HERRAMIENTAS RAFA', 'HERRAMIENTAS DAVID'];

    final nuevoResponsable = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.negro2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reasignar herramienta a', style: AppTextStyles.titulo(size: 16)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: opciones.map((persona) {
                  final esActual = persona == _producto['responsable'];
                  return ActionChip(
                    label: Text(persona, style: AppTextStyles.cuerpo(size: 12.5, color: esActual ? Colors.white : AppColors.acento)),
                    backgroundColor: esActual ? AppColors.acento : AppColors.acentoSuave,
                    side: BorderSide(color: AppColors.acento.withValues(alpha: esActual ? 1 : 0.3)),
                    onPressed: esActual ? null : () => Navigator.of(context).pop(persona),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );

    if (nuevoResponsable == null || !context.mounted) return;

    try {
      final actualizado = await ApiService.editarProducto(
        token: widget.token,
        productoId: _producto['id'],
        responsable: nuevoResponsable,
      );
      if (!context.mounted) return;
      setState(() {
        _producto = {..._producto, 'responsable': actualizado['responsable']};
        _huboCambios = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reasignado a "$nuevoResponsable"'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editarUbicacionRapido() async {
    final controller = TextEditingController(text: _producto['ubicacion'] ?? '');

    final nuevaUbicacion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación actual'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej: Oficina del jefe, Bodega, Restaurante...', border: OutlineInputBorder()),
          onSubmitted: (valor) => Navigator.of(context).pop(valor.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );

    if (nuevaUbicacion == null || !context.mounted) return;

    try {
      final actualizado = await ApiService.editarProducto(
        token: widget.token,
        productoId: _producto['id'],
        ubicacion: nuevaUbicacion,
      );
      if (!context.mounted) return;
      setState(() {
        _producto = {..._producto, 'ubicacion': actualizado['ubicacion']};
        _huboCambios = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación actualizada'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _registrarMovimiento(String tipo) async {
    final cantidadController = TextEditingController(text: '1');
    final motivoController = TextEditingController();
    final esEntrada = tipo == 'entrada';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(esEntrada ? 'Registrar entrada' : 'Registrar salida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cantidadController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: esEntrada ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(esEntrada ? 'Confirmar entrada' : 'Confirmar salida'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final cantidad = int.tryParse(cantidadController.text) ?? 0;
    if (cantidad <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad debe ser mayor a cero'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final resultado = await ApiService.registrarMovimiento(
        token: widget.token,
        codigoBarras: _producto['codigo_barras'],
        productoId: _producto['id'] as int?,
        tipo: tipo,
        cantidad: cantidad,
        motivo: motivoController.text.trim(),
      );
      if (!context.mounted) return;
      setState(() {
        _producto = {..._producto, 'stock_actual': resultado['stock_resultante']};
        _huboCambios = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listo, nuevo stock: ${resultado['stock_resultante']}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }
   @override
  Widget build(BuildContext context) {
    final String? fotoUrl = _producto['foto_url'];
    final bool stockBajo = _producto['stock_actual'] <= _producto['stock_minimo'];
    const acento = AppColors.acento;
    final anchoPantalla = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
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
        title: Text('Producto', style: AppTextStyles.cuerpo(size: 16, peso: FontWeight.w800)),
        actions: [
          if (widget.puedeEditar)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19),
                tooltip: 'Editar',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.acentoSuave,
                  foregroundColor: AppColors.acento,
                ),
                onPressed: () async {
                  final actualizado = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditarProductoScreen(token: widget.token, producto: _producto),
                    ),
                  );
                  if (actualizado == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          Center(
            child: Container(
              width: anchoPantalla > 500 ? 240 : anchoPantalla - 80,
              height: anchoPantalla > 500 ? 240 : anchoPantalla - 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.negro2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.acento, width: 2),
                boxShadow: [BoxShadow(color: AppColors.acento.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: -6, offset: const Offset(0, 10))],
              ),
              clipBehavior: Clip.antiAlias,
              child: fotoUrl != null && fotoUrl.isNotEmpty
                  ? Image.network(
                      fotoUrl.startsWith('http') ? fotoUrl : '${AppConfig.baseUrl}$fotoUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[350]),
                    )
                  : Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[350]),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.grisLinea),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -6, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                if ((_producto['categoria'] ?? '').toString().isNotEmpty)
                  Text(
                    (_producto['categoria'] as String).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: acento, letterSpacing: 1.0),
                  ),
                const SizedBox(height: 6),
                Text(
                  _producto['nombre'],
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titulo(size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_producto['stock_actual']} ${_producto['unidad_medida']} en stock',
                  style: AppTextStyles.subtitulo(size: 13.5),
                ),
                if (stockBajo)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBEAF0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Stock bajo',
                          style: TextStyle(color: Color(0xFF993556), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.puedeRegistrarEntrada || widget.puedeRegistrarSalida) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.puedeRegistrarEntrada)
                  ElevatedButton.icon(
                    onPressed: () => _registrarMovimiento('entrada'),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Entrada'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.verdeOk,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 20),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.boton)),
                    ),
                  ),
                if (widget.puedeRegistrarEntrada && widget.puedeRegistrarSalida)
                  const SizedBox(width: 12),
                if (widget.puedeRegistrarSalida)
                  OutlinedButton.icon(
                    onPressed: () => _registrarMovimiento('salida'),
                    icon: const Icon(Icons.remove, size: 17),
                    label: const Text('Salida'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rojoAlerta,
                      side: const BorderSide(color: AppColors.rojoAlerta, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.boton)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Container(
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.grisLinea),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -6, offset: const Offset(0, 8))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _filaDato(Icons.qr_code, 'Código', _producto['codigo_barras'] ?? 'Sin código'),
                const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                _esSuperAdmin
                    ? InkWell(
                        onTap: _moverDeAlmacenRapido,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: _filaDato(Icons.warehouse_outlined, 'Inventario', _nombreAlmacenActual.isEmpty ? '...' : _nombreInventario(_nombreAlmacenActual))),
                              const Icon(Icons.chevron_right, size: 18, color: AppColors.gris),
                            ],
                          ),
                        ),
                      )
                    : _filaDato(Icons.warehouse_outlined, 'Inventario', _nombreAlmacenActual.isEmpty ? '...' : _nombreInventario(_nombreAlmacenActual)),
                if (_enCuartoMantenimiento) ...[
                  if (_esSuperAdmin) ...[
                    const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                    InkWell(
                      onTap: _moverResponsableRapido,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: _filaDato(Icons.person_outline, 'Pertenece a', (_producto['responsable'] ?? '').toString().isEmpty ? 'Sin asignar' : _producto['responsable'])),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.gris),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                    InkWell(
                      onTap: _editarUbicacionRapido,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: _filaDato(Icons.location_on_outlined, 'Ubicación', (_producto['ubicacion'] ?? '').toString().isEmpty ? 'Sin definir' : _producto['ubicacion'])),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.gris),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    if ((_producto['responsable'] ?? '').toString().isNotEmpty) ...[
                      const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                      _filaDato(Icons.person_outline, 'Pertenece a', _producto['responsable']),
                    ],
                    if ((_producto['ubicacion'] ?? '').toString().isNotEmpty) ...[
                      const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                      _filaDato(Icons.location_on_outlined, 'Ubicación', _producto['ubicacion']),
                    ],
                  ],
                ],
                const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                _filaDato(Icons.warning_amber_outlined, 'Stock mínimo', '${_producto['stock_minimo']}'),
                if (_producto['precio_unitario'] != null) ...[
                  const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                  _filaDato(Icons.attach_money, 'Precio unitario', _formatearPrecio(_producto['precio_unitario'])),
                ],
                if ((_producto['proveedor_nombre'] ?? '').toString().isNotEmpty) ...[
                  const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                  _filaDato(Icons.local_shipping_outlined, 'Proveedor', _producto['proveedor_nombre']),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HistorialScreen(
                      token: widget.token,
                      productoId: _producto['id'],
                      nombreProducto: _producto['nombre'],
                      fotoUrl: _producto['foto_url'],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Ver historial de movimientos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: acento,
                side: const BorderSide(color: Color(0xFFDADDE1)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}