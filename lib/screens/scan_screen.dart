import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../config.dart';
import '../theme.dart';

class ScanScreen extends StatefulWidget {
  final String token;
  final bool puedeCrearProductos;

  const ScanScreen({super.key, required this.token, required this.puedeCrearProductos});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _procesando = false;
  Map<String, dynamic>? _producto;
  String? _error;

  final _cantidadController = TextEditingController(text: '1');
  final _motivoController = TextEditingController();
  String _tipoMovimiento = 'salida';

  String? _ultimoCodigoEscaneado;
  bool _creandoProducto = false;
  List<dynamic> _secciones = [];
  bool _seccionesCargadas = false;
Future<void> _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;

    final codigo = capture.barcodes.first.rawValue;
    if (codigo == null) return;

    _controller.stop();
    await _buscarProducto(codigo);
  }

  Future<void> _buscarProducto(String codigo) async {
    setState(() {
      _procesando = true;
      _error = null;
      _ultimoCodigoEscaneado = codigo;
    });

    try {
      final producto = await ApiService.buscarPorCodigo(widget.token, codigo);
      setState(() {
        _producto = producto;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _procesando = false;
      });
    }
  }

  Future<void> _cargarSeccionesSiHaceFalta() async {
    if (_seccionesCargadas) return;
    try {
      final secciones = await ApiService.getSecciones(widget.token);
      setState(() {
        _secciones = secciones;
        _seccionesCargadas = true;
      });
    } catch (e) {
      // si falla, el dropdown queda vacío y se puede reintentar abriendo el formulario de nuevo
    }
  }

  Future<void> _abrirFormularioNuevoProducto() async {
    if (_ultimoCodigoEscaneado == null) return;
    await _cargarSeccionesSiHaceFalta();
    if (!mounted) return;

    final nombreController = TextEditingController();
    final categoriaController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final stockMinimoController = TextEditingController(text: '0');
    int? seccionSeleccionada = _secciones.isNotEmpty ? _secciones[0]['id'] : null;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Producto no encontrado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Código: $_ultimoCodigoEscaneado', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre del producto *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoriaController,
                  decoration: const InputDecoration(labelText: 'Categoría (opcional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                _secciones.isEmpty
                    ? const Text('Cargando secciones...', style: TextStyle(color: Colors.grey))
                    : DropdownButtonFormField<int>(
                        initialValue: seccionSeleccionada,
                        decoration: const InputDecoration(labelText: 'Sección *', border: OutlineInputBorder()),
                        items: _secciones
                            .map<DropdownMenuItem<int>>(
                              (s) => DropdownMenuItem(value: s['id'], child: Text(s['nombre'])),
                            )
                            .toList(),
                        onChanged: (valor) => setDialogState(() => seccionSeleccionada = valor),
                      ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad a ingresar', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockMinimoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock mínimo', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nombreController.text.trim().isEmpty || seccionSeleccionada == null) return;
                Navigator.of(context).pop(true);
                _guardarProductoDesdeEscaneo(
                  codigo: _ultimoCodigoEscaneado!,
                  nombre: nombreController.text.trim(),
                  categoria: categoriaController.text.trim().isEmpty ? null : categoriaController.text.trim(),
                  seccionId: seccionSeleccionada!,
                  stockIngresado: int.tryParse(stockController.text) ?? 0,
                  stockMinimo: int.tryParse(stockMinimoController.text) ?? 0,
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardado != true) {
      _reiniciarEscaneo();
    }
  }

  Future<void> _guardarProductoDesdeEscaneo({
    required String codigo,
    required String nombre,
    String? categoria,
    required int seccionId,
    required int stockIngresado,
    required int stockMinimo,
  }) async {
    setState(() => _creandoProducto = true);
    try {
      final producto = await ApiService.resolverCodigo(
        token: widget.token,
        codigoBarras: codigo,
        nombre: nombre,
        categoria: categoria,
        seccionId: seccionId,
        stockIngresado: stockIngresado,
        stockMinimo: stockMinimo,
      );
      if (!mounted) return;
      setState(() {
        _producto = producto;
        _error = null;
      });
      _mostrarMensaje('Producto guardado correctamente');
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''), esError: true);
      _reiniciarEscaneo();
    } finally {
      if (mounted) setState(() => _creandoProducto = false);
    }
  }

  Future<void> _abrirBusquedaManual() async {
    final codigoController = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar por código'),
        content: TextField(
          controller: codigoController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Código de barras',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (valor) => Navigator.of(context).pop(valor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(codigoController.text.trim()),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );

    if (codigo != null && codigo.isNotEmpty) {
      _controller.stop();
      await _buscarProducto(codigo);
    }
  }

  Future<void> _confirmarMovimiento() async {
    if (_producto == null) return;

    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    if (cantidad <= 0) {
      _mostrarMensaje('La cantidad debe ser mayor a cero', esError: true);
      return;
    }

    setState(() => _procesando = true);

    try {
      final resultado = await ApiService.registrarMovimiento(
        token: widget.token,
        codigoBarras: _producto!['codigo_barras'],
        tipo: _tipoMovimiento,
        cantidad: cantidad,
        motivo: _motivoController.text.trim(),
      );

      if (!mounted) return;
      _mostrarMensaje(
        '¡Listo! Nuevo stock: ${resultado['stock_resultante']} ${_producto!['unidad_medida']}',
      );
      _reiniciarEscaneo();
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''), esError: true);
    } finally {
      setState(() => _procesando = false);
    }
  }

  void _mostrarMensaje(String texto, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: esError ? Colors.red : Colors.green,
      ),
    );
  }

  void _reiniciarEscaneo() {
    setState(() {
      _producto = null;
      _error = null;
      _cantidadController.text = '1';
      _motivoController.clear();
      _tipoMovimiento = 'salida';
    });
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _cantidadController.dispose();
    _motivoController.dispose();
    super.dispose();
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.acentoSuave, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.qr_code_scanner, size: 17, color: AppColors.acento),
            ),
            const SizedBox(width: 10),
            Text('Escanear producto', style: AppTextStyles.cuerpo(size: 16, peso: FontWeight.w800)),
          ],
        ),
      ),
      body: _producto == null ? _vistaCamara() : _vistaProducto(),
    );
  }

 Widget _vistaCamara() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: ElevatedButton.icon(
            onPressed: _abrirBusquedaManual,
            icon: const Icon(Icons.keyboard),
            label: const Text('Buscar por código manualmente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.acento,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.boton)),
            ),
          ),
        ),
        if (_error != null)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.negro2,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.rojoAlerta.withValues(alpha: 0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.rojoAlerta),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_error!, style: AppTextStyles.cuerpo(color: AppColors.rojoAlerta))),
                        TextButton(onPressed: _reiniciarEscaneo, child: const Text('Reintentar')),
                      ],
                    ),
                    if (widget.puedeCrearProductos && _ultimoCodigoEscaneado != null) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _abrirFormularioNuevoProducto,
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Registrar este producto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.acento,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.boton)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (_procesando || _creandoProducto)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }
Widget _vistaProducto() {
    final stockActual = _producto!['stock_actual'];
    final unidad = _producto!['unidad_medida'];
    final String? fotoUrl = _producto!['foto_url'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fotoUrl != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  '${AppConfig.baseUrl}$fotoUrl',
                  height: 180,
                  width: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (fotoUrl != null) const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.negro2,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.grisLinea),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -6, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_producto!['nombre'], style: AppTextStyles.titulo(size: 18)),
                const SizedBox(height: 4),
                Text('Código: ${_producto!['codigo_barras']}', style: AppTextStyles.subtitulo()),
                const SizedBox(height: 12),
                Text('Stock actual: $stockActual $unidad', style: AppTextStyles.cuerpo(size: 15, peso: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Tipo de movimiento', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Entrada (+)'),
                  selected: _tipoMovimiento == 'entrada',
                  onSelected: (_) => setState(() => _tipoMovimiento = 'entrada'),
                  selectedColor: Colors.green[200],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Salida (-)'),
                  selected: _tipoMovimiento == 'salida',
                  onSelected: (_) => setState(() => _tipoMovimiento = 'salida'),
                  selectedColor: Colors.red[200],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _cantidadController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _motivoController,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _procesando ? null : _confirmarMovimiento,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.acento,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.boton)),
            ),
            child: _procesando
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Text('Confirmar movimiento', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _reiniciarEscaneo,
            child: const Text('Escanear otro producto'),
          ),
        ],
      ),
    );
  }
}