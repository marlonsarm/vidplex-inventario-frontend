import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _procesando = false;
  Map<String, dynamic>? _producto;
  String? _error;

  final _cantidadController = TextEditingController(text: '1');
  final _motivoController = TextEditingController();
  String _tipoMovimiento = 'salida';

  String? _ultimoCodigoEscaneado;
  bool _creandoProducto = false;
  bool _productoRecienCreado = false;
  List<dynamic> _secciones = [];
  bool _seccionesCargadas = false;

  // Controla la animación de la línea de escaneo dentro del recuadro.
  late final AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

Future<void> _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;

    final codigo = capture.barcodes.first.rawValue;
    if (codigo == null) return;

    HapticFeedback.mediumImpact();
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
        _productoRecienCreado = true;
      });
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
      _productoRecienCreado = false;
      _cantidadController.text = '1';
      _motivoController.clear();
      _tipoMovimiento = 'salida';
    });
    _controller.start();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
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
        actions: _producto == null
            ? [
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (context, state, child) {
                    final torchActivo = state.torchState == TorchState.on;
                    return IconButton(
                      tooltip: 'Linterna',
                      onPressed: () => _controller.toggleTorch(),
                      icon: Icon(
                        torchActivo ? Icons.flash_on : Icons.flash_off_outlined,
                        color: torchActivo ? AppColors.acento : AppColors.blanco,
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Cambiar cámara',
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.cameraswitch_outlined, color: AppColors.blanco),
                ),
                const SizedBox(width: 4),
              ]
            : null,
      ),
      body: _producto == null
          ? _vistaCamara()
          : (_productoRecienCreado ? _vistaProductoCreado() : _vistaProducto()),
    );
  }

 Widget _vistaCamara() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        // Overlay profesional: recuadro con esquinas y línea de escaneo animada.
        LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final ladoCutout = math.min(size.width * 0.78, 320.0);
            final cutout = Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2 - 30),
              width: ladoCutout,
              height: ladoCutout,
            );
            return IgnorePointer(
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _scanLineController,
                    builder: (context, _) => CustomPaint(
                      size: size,
                      painter: _ScannerOverlayPainter(
                        cutout: cutout,
                        borderRadius: 24,
                        dimColor: Colors.black.withValues(alpha: 0.55),
                        frameColor: AppColors.acento,
                        scanLineY: _scanLineController.value,
                      ),
                    ),
                  ),
                  Positioned(
                    top: cutout.bottom + 16,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _procesando ? Icons.sync : Icons.center_focus_strong,
                            size: 16,
                            color: AppColors.acento,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _procesando ? 'Verificando código...' : 'Ubica el código dentro del recuadro',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.cuerpo(size: 13, color: Colors.white.withValues(alpha: 0.9)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.boton),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: ElevatedButton.icon(
                onPressed: _abrirBusquedaManual,
                icon: const Icon(Icons.keyboard, size: 20),
                label: Text('Buscar por código manualmente', style: AppTextStyles.cuerpo(size: 14, peso: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.13),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.boton),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                ),
              ),
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
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.rojoAlerta.withValues(alpha: 0.5)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.negro2,
                    AppColors.negro2.withValues(alpha: 0.95),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rojoAlerta.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ],
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
Widget _vistaProductoCreado() {
    final nombre = _producto!['nombre'];
    final categoria = _producto!['categoria'];
    final stockActual = _producto!['stock_actual'];
    final unidad = _producto!['unidad_medida'];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 56),
            ),
            const SizedBox(height: 20),
            Text('Producto creado', style: AppTextStyles.titulo(size: 20)),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.acento.withValues(alpha: 0.2)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.negro2,
                    AppColors.negro2.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: AppTextStyles.cuerpo(size: 18, peso: FontWeight.w800)),
                  if (categoria != null && categoria.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(categoria, style: AppTextStyles.subtitulo()),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.acento.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory, size: 18, color: AppColors.acento),
                        const SizedBox(width: 8),
                        Text(
                          'Stock inicial: $stockActual $unidad',
                          style: AppTextStyles.cuerpo(size: 16, peso: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _reiniciarEscaneo,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear otro producto'),
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
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.acento.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.acento.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    '${AppConfig.baseUrl}$fotoUrl',
                    height: 180,
                    width: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          if (fotoUrl != null) const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.acento.withValues(alpha: 0.2)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.negro2,
                  AppColors.negro2.withValues(alpha: 0.9),
                ],
              ),
              boxShadow: [
                BoxShadow(color: AppColors.acento.withValues(alpha: 0.08), blurRadius: 24, spreadRadius: -6, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.acento.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.acento, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_producto!['nombre'], style: AppTextStyles.titulo(size: 18)),
                          const SizedBox(height: 2),
                          Text('Código: ${_producto!['codigo_barras']}', style: AppTextStyles.subtitulo()),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.acento.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory, size: 18, color: AppColors.acento),
                      const SizedBox(width: 8),
                      Text(
                        'Stock: $stockActual $unidad',
                        style: AppTextStyles.cuerpo(size: 16, peso: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Tipo de movimiento', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tipoMovimiento = 'entrada'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.boton),
                      border: Border.all(
                        color: _tipoMovimiento == 'entrada' ? Colors.greenAccent.withValues(alpha: 0.7) : AppColors.grisLinea,
                        width: _tipoMovimiento == 'entrada' ? 1.5 : 1,
                      ),
                      color: _tipoMovimiento == 'entrada' ? Colors.greenAccent.withValues(alpha: 0.1) : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: _tipoMovimiento == 'entrada' ? Colors.greenAccent : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Entrada (+)',
                          style: TextStyle(
                            color: _tipoMovimiento == 'entrada' ? Colors.greenAccent : Colors.grey,
                            fontWeight: _tipoMovimiento == 'entrada' ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tipoMovimiento = 'salida'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.boton),
                      border: Border.all(
                        color: _tipoMovimiento == 'salida' ? Colors.redAccent.withValues(alpha: 0.7) : AppColors.grisLinea,
                        width: _tipoMovimiento == 'salida' ? 1.5 : 1,
                      ),
                      color: _tipoMovimiento == 'salida' ? Colors.redAccent.withValues(alpha: 0.1) : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.remove_circle_outline,
                          color: _tipoMovimiento == 'salida' ? Colors.redAccent : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Salida (-)',
                          style: TextStyle(
                            color: _tipoMovimiento == 'salida' ? Colors.redAccent : Colors.grey,
                            fontWeight: _tipoMovimiento == 'salida' ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.boton),
              boxShadow: [
                BoxShadow(
                  color: AppColors.acento.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
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

/// Pinta el overlay del scanner: fondo oscurecido con un recuadro
/// recortado (el "cutout"), esquinas tipo marco profesional y una
/// línea de escaneo animada que sube y baja dentro del recuadro.
class _ScannerOverlayPainter extends CustomPainter {
  final Rect cutout;
  final double borderRadius;
  final Color dimColor;
  final Color frameColor;
  final double scanLineY; // 0.0 a 1.0, posición relativa dentro del cutout

  _ScannerOverlayPainter({
    required this.cutout,
    required this.borderRadius,
    required this.dimColor,
    required this.frameColor,
    required this.scanLineY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Offset.zero & size);
    final cutoutRRect = RRect.fromRectAndRadius(cutout, Radius.circular(borderRadius));
    final cutoutPath = Path()..addRRect(cutoutRRect);

    // Fondo oscurecido con el recuadro "recortado" (transparente).
    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      Paint()..color = dimColor,
    );

    // Borde sutil alrededor de todo el recuadro.
    canvas.drawRRect(
      cutoutRRect,
      Paint()
        ..color = frameColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Esquinas tipo marco (estilo apps de escaneo profesionales).
    final cornerPaint = Paint()
      ..color = frameColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 26.0;
    _drawCorner(canvas, cornerPaint, cutout.topLeft, 1, 1, cornerLen);
    _drawCorner(canvas, cornerPaint, cutout.topRight, -1, 1, cornerLen);
    _drawCorner(canvas, cornerPaint, cutout.bottomRight, -1, -1, cornerLen);
    _drawCorner(canvas, cornerPaint, cutout.bottomLeft, 1, -1, cornerLen);

    // Línea de escaneo animada con resplandor neon.
    final lineY = cutout.top + cutout.height * scanLineY;

    // Glow exterior amplio
    final outerGlowRect = Rect.fromLTRB(cutout.left + 4, lineY - 16, cutout.right - 4, lineY + 16);
    final outerGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          frameColor.withValues(alpha: 0),
          frameColor.withValues(alpha: 0.12),
          frameColor.withValues(alpha: 0.2),
          frameColor.withValues(alpha: 0.12),
          frameColor.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(outerGlowRect);
    canvas.drawRect(outerGlowRect, outerGlowPaint);

    // Glow interior más intenso
    final glowRect = Rect.fromLTRB(cutout.left + 6, lineY - 8, cutout.right - 6, lineY + 8);
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          frameColor.withValues(alpha: 0),
          frameColor.withValues(alpha: 0.5),
          frameColor.withValues(alpha: 0.7),
          frameColor.withValues(alpha: 0.5),
          frameColor.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(glowRect);
    canvas.drawRect(glowRect, glowPaint);

    // Línea central sólida con blur
    canvas.drawRect(
      Rect.fromLTRB(cutout.left + 8, lineY - 0.8, cutout.right - 8, lineY + 0.8),
      Paint()
        ..color = frameColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawRect(
      Rect.fromLTRB(cutout.left + 8, lineY - 0.5, cutout.right - 8, lineY + 0.5),
      Paint()..color = Colors.white,
    );
  }

  void _drawCorner(Canvas canvas, Paint paint, Offset corner, double dx, double dy, double len) {
    canvas.drawLine(corner, Offset(corner.dx + dx * len, corner.dy), paint);
    canvas.drawLine(corner, Offset(corner.dx, corner.dy + dy * len), paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanLineY != scanLineY ||
        oldDelegate.cutout != cutout ||
        oldDelegate.frameColor != frameColor;
  }
}