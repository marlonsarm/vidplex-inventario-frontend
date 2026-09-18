import re

# --- Archivo 1: api_service.dart ---
ruta1 = "lib/services/api_service.dart"
with open(ruta1, "r", encoding="utf-8") as f:
    c1 = f.read()

viejo1 = """  static Future<Map<String, dynamic>> crearProducto({
    required String token,
    String? codigoBarras,
    required String nombre,
    String? categoria,
    required int seccionId,
    required int stockActual,
    required int stockMinimo,
    required String unidadMedida,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/');

    final respuesta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'codigo_barras': codigoBarras,
        'nombre': nombre,
        'categoria': categoria,
        'seccion_id': seccionId,
        'stock_actual': stockActual,
        'stock_minimo': stockMinimo,
        'unidad_medida': unidadMedida,
      }),
    );"""

nuevo1 = """  static Future<Map<String, dynamic>> crearProducto({
    required String token,
    String? codigoBarras,
    required String nombre,
    String? categoria,
    required int seccionId,
    required int stockActual,
    required int stockMinimo,
    required String unidadMedida,
    int? proveedorId,
    double? precioUnitario,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/');

    final respuesta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'codigo_barras': codigoBarras,
        'nombre': nombre,
        'categoria': categoria,
        'seccion_id': seccionId,
        'stock_actual': stockActual,
        'stock_minimo': stockMinimo,
        'unidad_medida': unidadMedida,
        'proveedor_id': proveedorId,
        'precio_unitario': precioUnitario,
      }),
    );"""

assert c1.count(viejo1) == 1, f"api_service: aparecio {c1.count(viejo1)} veces"
c1 = c1.replace(viejo1, nuevo1, 1)
with open(ruta1, "w", encoding="utf-8") as f:
    f.write(c1)
print("api_service.dart: OK")

# --- Archivo 2: crear_producto_screen.dart ---
ruta2 = "lib/screens/crear_producto_screen.dart"
with open(ruta2, "r", encoding="utf-8") as f:
    c2 = f.read()

# 2a: variables de estado
viejo2a = """  int? _seccionSeleccionada;
  List<dynamic> _secciones = [];
  bool _cargandoSecciones = true;
  bool _guardando = false;"""
nuevo2a = """  int? _seccionSeleccionada;
  List<dynamic> _secciones = [];
  bool _cargandoSecciones = true;
  bool _guardando = false;

  Map<String, dynamic>? _proveedorSeleccionado;
  List<dynamic> _proveedores = [];
  final _precioController = TextEditingController();"""
assert c2.count(viejo2a) == 1, f"2a: aparecio {c2.count(viejo2a)} veces"
c2 = c2.replace(viejo2a, nuevo2a, 1)

# 2b: initState
viejo2b = """  @override
  void initState() {
    super.initState();
    _cargarSecciones();
  }"""
nuevo2b = """  @override
  void initState() {
    super.initState();
    _cargarSecciones();
    _cargarProveedores();
  }"""
assert c2.count(viejo2b) == 1, f"2b: aparecio {c2.count(viejo2b)} veces"
c2 = c2.replace(viejo2b, nuevo2b, 1)

# 2c: agregar metodos nuevos despues de _cargarSecciones
viejo2c = """  Future<void> _cargarSecciones() async {
    try {
      final secciones = await ApiService.getSecciones(widget.token);
      setState(() {
        _secciones = secciones;
        if (secciones.isNotEmpty) _seccionSeleccionada = secciones[0]['id'];
      });
    } catch (e) {
      // si falla, se puede reintentar guardando el producto igual
   } finally {
      setState(() => _cargandoSecciones = false);
    }
  }"""
nuevo2c = viejo2c + """

  Future<void> _cargarProveedores() async {
    try {
      final proveedores = await ApiService.getProveedores(widget.token);
      if (mounted) setState(() => _proveedores = proveedores);
    } catch (e) {
      // si falla, el usuario puede seguir sin elegir proveedor
    }
  }

  Future<Map<String, dynamic>?> _crearProveedorRapido() async {
    final nombreCtrl = TextEditingController();
    final contactoCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo proveedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre *')),
            const SizedBox(height: 8),
            TextField(controller: contactoCtrl, decoration: const InputDecoration(labelText: 'Contacto')),
            const SizedBox(height: 8),
            TextField(controller: telefonoCtrl, decoration: const InputDecoration(labelText: 'Telefono')),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              try {
                final creado = await ApiService.crearProveedor(
                  token: widget.token,
                  nombre: nombreCtrl.text.trim(),
                  contacto: contactoCtrl.text.trim().isEmpty ? null : contactoCtrl.text.trim(),
                  telefono: telefonoCtrl.text.trim().isEmpty ? null : telefonoCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop(creado);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
                  );
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _elegirProveedor(List<dynamic> proveedores) async {
    final busquedaCtrl = TextEditingController();

    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtrados = busquedaCtrl.text.trim().isEmpty
                ? proveedores
                : proveedores.where((p) {
                    final nombre = (p['nombre'] ?? '').toString().toLowerCase();
                    return nombre.contains(busquedaCtrl.text.trim().toLowerCase());
                  }).toList();

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.negro2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Elegir proveedor', style: AppTextStyles.titulo(size: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.acento),
                        tooltip: 'Nuevo proveedor',
                        onPressed: () async {
                          final nuevo = await _crearProveedorRapido();
                          if (nuevo != null && context.mounted) Navigator.of(context).pop(nuevo);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: busquedaCtrl,
                    autofocus: true,
                    style: AppTextStyles.cuerpo(),
                    decoration: const InputDecoration(
                      hintText: 'Buscar proveedor...',
                      prefixIcon: Icon(Icons.search, color: AppColors.gris),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final p = filtrados[index];
                        return ListTile(
                          title: Text(p['nombre'].toString(), style: AppTextStyles.cuerpo(size: 13.5)),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }"""
assert c2.count(viejo2c) == 1, f"2c: aparecio {c2.count(viejo2c)} veces"
c2 = c2.replace(viejo2c, nuevo2c, 1)

# 2d: dispose
viejo2d = """  @override
  void dispose() {
    _debounce?.cancel();
    _codigoController.dispose();
    _nombreController.dispose();
    _categoriaController.dispose();
    _stockActualController.dispose();
    _stockMinimoController.dispose();
    _unidadController.dispose();
    super.dispose();
  }"""
nuevo2d = """  @override
  void dispose() {
    _debounce?.cancel();
    _codigoController.dispose();
    _nombreController.dispose();
    _categoriaController.dispose();
    _stockActualController.dispose();
    _stockMinimoController.dispose();
    _unidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }"""
assert c2.count(viejo2d) == 1, f"2d: aparecio {c2.count(viejo2d)} veces"
c2 = c2.replace(viejo2d, nuevo2d, 1)

# 2e: agregar tarjeta de precio/proveedor antes de STOCK
viejo2e = """                      onChanged: (valor) => setState(() => _seccionSeleccionada = valor),
                    ),
            ),
            _tituloSeccion(Icons.numbers_rounded, 'STOCK'),"""
nuevo2e = """                      onChanged: (valor) => setState(() => _seccionSeleccionada = valor),
                    ),
            ),
            _tituloSeccion(Icons.local_shipping_outlined, 'PRECIO Y PROVEEDOR'),
            _tarjeta(
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final elegido = await _elegirProveedor(_proveedores);
                      if (elegido != null) setState(() => _proveedorSeleccionado = elegido);
                    },
                    child: InputDecorator(
                      decoration: _decoracion('Proveedor (opcional)', icono: Icons.local_shipping_outlined),
                      child: Text(
                        _proveedorSeleccionado?['nombre'] ?? 'Sin proveedor',
                        style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _precioController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w700),
                    decoration: _decoracion('Precio unitario (opcional)', icono: Icons.attach_money),
                  ),
                ],
              ),
            ),
            _tituloSeccion(Icons.numbers_rounded, 'STOCK'),"""
assert c2.count(viejo2e) == 1, f"2e: aparecio {c2.count(viejo2e)} veces"
c2 = c2.replace(viejo2e, nuevo2e, 1)

# 2f: pasar proveedorId y precioUnitario al crear el producto
viejo2f = """      final creado = await ApiService.crearProducto(
        token: widget.token,
        codigoBarras: _codigoController.text.trim().isEmpty ? null : _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        categoria: _categoriaController.text.trim(),
        seccionId: _seccionSeleccionada!,
        stockActual: int.parse(_stockActualController.text),
        stockMinimo: int.parse(_stockMinimoController.text),
        unidadMedida: _unidadController.text.trim().isEmpty ? 'unidad' : _unidadController.text.trim(),
      );"""
nuevo2f = """      final creado = await ApiService.crearProducto(
        token: widget.token,
        codigoBarras: _codigoController.text.trim().isEmpty ? null : _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        categoria: _categoriaController.text.trim(),
        seccionId: _seccionSeleccionada!,
        stockActual: int.parse(_stockActualController.text),
        stockMinimo: int.parse(_stockMinimoController.text),
        unidadMedida: _unidadController.text.trim().isEmpty ? 'unidad' : _unidadController.text.trim(),
        proveedorId: _proveedorSeleccionado?['id'] as int?,
        precioUnitario: double.tryParse(_precioController.text.trim().replaceAll(',', '.')),
      );"""
assert c2.count(viejo2f) == 1, f"2f: aparecio {c2.count(viejo2f)} veces"
c2 = c2.replace(viejo2f, nuevo2f, 1)

with open(ruta2, "w", encoding="utf-8") as f:
    f.write(c2)
print("crear_producto_screen.dart: OK (6 cambios)")
