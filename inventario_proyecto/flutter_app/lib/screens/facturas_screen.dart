import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

String _formatoCOP(num valor) {
  final entero = valor.round();
  final texto = entero.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < texto.length; i++) {
    if (i != 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return '${entero < 0 ? '-' : ''}\$$buffer';
}

String _formatoUSD(num valorCOP, double tasa) {
  final dolares = valorCOP / tasa;
  final partes = dolares.toStringAsFixed(2).split('.');
  final entero = partes[0].replaceAll('-', '');
  final buffer = StringBuffer();
  for (int i = 0; i < entero.length; i++) {
    if (i != 0 && (entero.length - i) % 3 == 0) buffer.write(',');
    buffer.write(entero[i]);
  }
  return '${dolares < 0 ? '-' : ''}US\$$buffer.${partes[1]}';
}

String _formatearFecha(String? iso) {
  if (iso == null) return '';
  try {
    final fecha = DateTime.parse(iso);
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  } catch (e) {
    return iso;
  }
}

class FacturasScreen extends StatefulWidget {
  final String token;
  final bool puedeEliminar;

  const FacturasScreen({super.key, required this.token, this.puedeEliminar = false});

  @override
  State<FacturasScreen> createState() => _FacturasScreenState();
}

class _FacturasScreenState extends State<FacturasScreen> {
  List<dynamic> _facturas = [];
  bool _cargando = true;
  String? _error;
  final _busquedaController = TextEditingController();
  String _textoBusqueda = '';
  bool _mostrarUSD = false;
  double? _tasa;
  String _orden = 'reciente'; // reciente | mayor | menor
  Map<String, dynamic>? _resumen;

  List<dynamic> get _facturasFiltradas {
    List<dynamic> lista = _facturas;
    if (_textoBusqueda.trim().isNotEmpty) {
      final q = _textoBusqueda.trim().toLowerCase();
      lista = lista.where((f) {
        final numero = (f['numero_factura'] ?? '').toString().toLowerCase();
        final proveedor = (f['proveedor_nombre'] ?? '').toString().toLowerCase();
        return numero.contains(q) || proveedor.contains(q);
      }).toList();
    }
    lista = List.of(lista);
    if (_orden == 'mayor') {
      lista.sort((a, b) =>
          (double.tryParse(b['total'].toString()) ?? 0).compareTo(double.tryParse(a['total'].toString()) ?? 0));
    } else if (_orden == 'menor') {
      lista.sort((a, b) =>
          (double.tryParse(a['total'].toString()) ?? 0).compareTo(double.tryParse(b['total'].toString()) ?? 0));
    }
    return lista;
  }

  Widget _chipOrden(String valor, String etiqueta) {
    final activo = _orden == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(etiqueta),
        selected: activo,
        onSelected: (_) => setState(() => _orden = valor),
        backgroundColor: AppColors.negro2,
        selectedColor: AppColors.acentoSuave,
        showCheckmark: false,
        side: BorderSide(color: activo ? AppColors.acento : AppColors.grisLinea),
        labelStyle: AppTextStyles.cuerpo(size: 12.5, peso: FontWeight.w600, color: activo ? AppColors.acento : AppColors.gris),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarFacturas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final facturas = await ApiService.getFacturas(widget.token);
      setState(() => _facturas = facturas);
      try {
        final resumen = await ApiService.getResumenFacturas(widget.token);
        setState(() => _resumen = resumen);
      } catch (e) {
        // si falla el resumen, no bloquea el resto de la pantalla
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _alternarMoneda() async {
    if (_mostrarUSD) {
      setState(() => _mostrarUSD = false);
      return;
    }
    try {
      final tasa = await ApiService.getTasaCambio(widget.token);
      setState(() {
        _tasa = tasa;
        _mostrarUSD = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
      );
    }
  }

  String _dinero(num valor) {
    if (_mostrarUSD && _tasa != null) return _formatoUSD(valor, _tasa!);
    return _formatoCOP(valor);
  }

  Future<void> _verDetalleFactura(int facturaId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FacturaDetalleScreen(token: widget.token, facturaId: facturaId),
      ),
    );
    _cargarFacturas();
  }
Future<void> _confirmarEliminarFactura(Map factura) async {
    String mensaje = '¿Seguro que quieres eliminar esta factura?';
    try {
      final impacto = await ApiService.verImpactoEliminarFactura(widget.token, factura['id'] as int);
      mensaje = impacto['mensaje']?.toString() ?? mensaje;
    } catch (e) {
      // si falla la consulta previa, igual dejamos que el backend valide al confirmar
    }

    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar factura'),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.rojoAlerta)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.eliminarFactura(widget.token, factura['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura eliminada')),
      );
      _cargarFacturas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
      );
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
            TextField(controller: telefonoCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
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
  }

  Future<void> _abrirFormularioNuevaFactura() async {
    List<dynamic> proveedores = [];
    try {
      proveedores = await ApiService.getProveedores(widget.token);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
      );
      return;
    }

    final numeroController = TextEditingController();
    Map<String, dynamic>? proveedorElegido;
    DateTime fecha = DateTime.now();
    bool guardando = false;

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.negro2,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nueva factura', style: AppTextStyles.titulo(size: 18)),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: numeroController,
                      style: AppTextStyles.cuerpo(),
                      decoration: const InputDecoration(labelText: 'Número de factura'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: () async {
                        final elegido = await _elegirProveedor(proveedores);
                        if (elegido != null) {
                          setModalState(() {
                            if (!proveedores.any((p) => p['id'] == elegido['id'])) {
                              proveedores.add(elegido);
                            }
                            proveedorElegido = elegido;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Proveedor'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              proveedorElegido?['nombre']?.toString() ?? 'Toca para elegir...',
                              style: proveedorElegido == null
                                  ? AppTextStyles.cuerpo(color: AppColors.gris)
                                  : AppTextStyles.cuerpo(),
                            ),
                            const Icon(Icons.search, size: 18, color: AppColors.gris),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: () async {
                        final elegida = await showDatePicker(
                          context: context,
                          initialDate: fecha,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (elegida != null) setModalState(() => fecha = elegida);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Fecha de la factura'),
                        child: Text('${fecha.day}/${fecha.month}/${fecha.year}', style: AppTextStyles.cuerpo()),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: guardando
                            ? null
                            : () async {
                                if (numeroController.text.trim().isEmpty || proveedorElegido == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Completa el número y el proveedor'),
                                      backgroundColor: AppColors.rojoAlerta,
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => guardando = true);
                                try {
                                  final creada = await ApiService.crearFactura(
                                    token: widget.token,
                                    numeroFactura: numeroController.text.trim(),
                                    proveedorId: proveedorElegido!['id'] as int,
                                    fechaFactura: fecha.toIso8601String(),
                                  );
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => _FacturaDetalleScreen(
                                        token: widget.token,
                                        facturaId: creada['id'] as int,
                                        abrirAgregarAlEntrar: true,
                                      ),
                                    ),
                                  );
                                  _cargarFacturas();
                                } catch (e) {
                                  setModalState(() => guardando = false);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: AppColors.rojoAlerta,
                                    ),
                                  );
                                }
                              },
                        child: Text(guardando ? 'Creando...' : 'Continuar y agregar productos'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _columnaResumen(String etiqueta, String valor, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: AppTextStyles.subtitulo(size: 11, color: AppColors.gris)),
          const SizedBox(height: 4),
          Text(valor, style: AppTextStyles.titulo(size: 16).copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _tarjetaResumen() {
    final total = (_resumen!['total_facturado'] as num).toDouble();
    final restante = (_resumen!['valor_restante'] as num).toDouble();
    final consumido = (_resumen!['valor_consumido'] as num).toDouble();
    final activas = _resumen!['facturas_activas'];
    final progreso = total > 0 ? (consumido / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.acento),
              const SizedBox(width: 6),
              Text('Resumen de inventario', style: AppTextStyles.cuerpo(size: 13, peso: FontWeight.w700)),
              const Spacer(),
              Text('$activas facturas activas', style: AppTextStyles.subtitulo(size: 11, color: AppColors.gris)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _columnaResumen('Total facturado', _dinero(total), AppColors.gris.withValues(alpha: 0.9)),
              _columnaResumen('Ya consumido', _dinero(consumido), AppColors.rojoAlerta),
              _columnaResumen('Queda en stock', _dinero(restante), AppColors.verdeOk),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 6,
              backgroundColor: AppColors.verdeOk.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(AppColors.rojoAlerta.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(
        title: Text('Facturas', style: AppTextStyles.titulo(size: 18)),
        actions: [
          IconButton(
            icon: Icon(_mostrarUSD ? Icons.attach_money : Icons.currency_exchange, size: 20),
            tooltip: _mostrarUSD ? 'Ver en pesos' : 'Ver en dólares',
            onPressed: _alternarMoneda,
          ),
          IconButton(
            icon: const Icon(Icons.history, size: 20),
            tooltip: 'Facturas agotadas (últimos 7 días)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => _FacturasAgotadasScreen(token: widget.token)),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormularioNuevaFactura,
        backgroundColor: AppColors.acento,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add),
        label: const Text('Nueva factura'),
      ),
      body: Column(
        children: [
          if (_resumen != null) _tarjetaResumen(),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: TextField(
              controller: _busquedaController,
              style: AppTextStyles.cuerpo(),
              decoration: InputDecoration(
                hintText: 'Buscar por número o proveedor...',
                prefixIcon: const Icon(Icons.search, color: AppColors.gris),
                suffixIcon: _textoBusqueda.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.gris),
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() => _textoBusqueda = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _textoBusqueda = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipOrden('reciente', 'Recientes'),
                  _chipOrden('mayor', 'Mayor a menor'),
                  _chipOrden('menor', 'Menor a mayor'),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.acento,
              backgroundColor: AppColors.negro2,
              onRefresh: _cargarFacturas,
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: AppColors.acento))
                  : _error != null
                      ? Center(child: Text(_error!, style: AppTextStyles.cuerpo(color: AppColors.rojoAlerta)))
                      : _facturasFiltradas.isEmpty
                          ? ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 80),
                                  child: Center(
                                    child: Text(
                                      _textoBusqueda.isEmpty ? 'No hay facturas todavía' : 'Sin resultados',
                                      style: AppTextStyles.cuerpo(color: AppColors.gris),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: _facturasFiltradas.length,
                              itemBuilder: (context, index) {
                                final f = _facturasFiltradas[index];
                                final esBorrador = f['estado'] == 'borrador';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.negro2,
                                    borderRadius: BorderRadius.circular(AppRadius.card),
                                    border: Border.all(color: AppColors.grisLinea),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(AppRadius.card),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(AppRadius.card),
                                  onTap: () => _verDetalleFactura(f['id'] as int),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(f['numero_factura'].toString(), style: AppTextStyles.cuerpo(peso: FontWeight.w700)),
                                                      const SizedBox(height: 4),
                                                      Text(f['proveedor_nombre']?.toString() ?? '-', style: AppTextStyles.subtitulo(size: 12.5)),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: (esBorrador ? AppColors.ambarBajo : AppColors.verdeOk).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    esBorrador ? 'BORRADOR' : 'CONFIRMADA',
                                                    style: AppTextStyles.etiqueta(size: 10, color: esBorrador ? AppColors.ambarBajo : AppColors.verdeOk),
                                                  ),
                                                ),
                                                if (widget.puedeEliminar)
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rojoAlerta),
                                                    tooltip: 'Eliminar factura',
                                                    onPressed: () => _confirmarEliminarFactura(f),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.event_outlined, size: 13, color: AppColors.gris),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatearFecha(f['fecha_factura']?.toString()),
                                                  style: AppTextStyles.subtitulo(size: 11.5, color: AppColors.gris),
                                                ),
                                                const SizedBox(width: 10),
                                                Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.gris),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${(f['detalles'] as List?)?.length ?? 0} productos',
                                                  style: AppTextStyles.subtitulo(size: 11.5, color: AppColors.gris),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                _dinero(double.tryParse(f['total'].toString()) ?? 0),
                                                style: AppTextStyles.cuerpo(size: 15, peso: FontWeight.w700, color: AppColors.acento),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FacturasAgotadasScreen extends StatefulWidget {
  final String token;
  const _FacturasAgotadasScreen({required this.token});

  @override
  State<_FacturasAgotadasScreen> createState() => _FacturasAgotadasScreenState();
}

class _FacturasAgotadasScreenState extends State<_FacturasAgotadasScreen> {
  List<dynamic> _facturas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final facturas = await ApiService.getFacturasAgotadas(widget.token);
      setState(() => _facturas = facturas);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(title: Text('Facturas agotadas', style: AppTextStyles.titulo(size: 16))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.acento))
          : _error != null
              ? Center(child: Text(_error!, style: AppTextStyles.cuerpo(color: AppColors.rojoAlerta)))
              : _facturas.isEmpty
                  ? Center(child: Text('No hay facturas agotadas recientemente', style: AppTextStyles.cuerpo(color: AppColors.gris)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _facturas.length,
                      itemBuilder: (context, index) {
                        final f = _facturas[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.negro2,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.grisLinea),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f['numero_factura'].toString(), style: AppTextStyles.cuerpo(peso: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(f['proveedor_nombre']?.toString() ?? '-', style: AppTextStyles.subtitulo(size: 12.5)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Se elimina definitivamente en unos días',
                                      style: AppTextStyles.subtitulo(size: 11, color: AppColors.gris),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatoCOP(double.tryParse(f['total'].toString()) ?? 0),
                                style: AppTextStyles.cuerpo(size: 13, peso: FontWeight.w700, color: AppColors.gris),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _FacturaDetalleScreen extends StatefulWidget {
  final String token;
  final int facturaId;
  final bool abrirAgregarAlEntrar;

  const _FacturaDetalleScreen({
    required this.token,
    required this.facturaId,
    this.abrirAgregarAlEntrar = false,
  });

  @override
  State<_FacturaDetalleScreen> createState() => _FacturaDetalleScreenState();
}

class _FacturaDetalleScreenState extends State<_FacturaDetalleScreen> {
  Map<String, dynamic>? _factura;
  bool _cargando = true;
  String? _error;
  bool _confirmando = false;
  bool _mostrarUSD = false;
  double? _tasa;

  @override
  void initState() {
    super.initState();
    _cargarFactura().then((_) {
      if (widget.abrirAgregarAlEntrar && mounted) _abrirAgregarProducto();
    });
  }

  Future<void> _cargarFactura() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final factura = await ApiService.getFactura(widget.token, widget.facturaId);
      setState(() => _factura = factura);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _alternarMoneda() async {
    if (_mostrarUSD) {
      setState(() => _mostrarUSD = false);
      return;
    }
    try {
      final tasa = await ApiService.getTasaCambio(widget.token);
      setState(() {
        _tasa = tasa;
        _mostrarUSD = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
      );
    }
  }

  String _dinero(num valor) {
    if (_mostrarUSD && _tasa != null) return _formatoUSD(valor, _tasa!);
    return _formatoCOP(valor);
  }

  Future<void> _quitarProducto(int detalleId) async {
    try {
      await ApiService.eliminarDetalleFactura(
        token: widget.token,
        facturaId: widget.facturaId,
        detalleId: detalleId,
      );
      _cargarFactura();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
      );
    }
  }

  Future<void> _confirmarFactura() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar factura', style: AppTextStyles.titulo(size: 16)),
        content: Text(
          'Al confirmar se moverá el stock de todos los productos agregados, cada uno a su propia sección. Esta acción no se puede deshacer.',
          style: AppTextStyles.cuerpo(color: AppColors.gris),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeOk),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _confirmando = true);
    try {
      await ApiService.confirmarFactura(token: widget.token, facturaId: widget.facturaId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura confirmada, stock actualizado')),
      );
      _cargarFactura();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
      );
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  Future<void> _abrirAgregarProducto() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HojaAgregarProducto(
        token: widget.token,
        facturaId: widget.facturaId,
        onProductoAgregado: _cargarFactura,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final factura = _factura;
    final detalles = (factura?['detalles'] as List?) ?? [];
    final esBorrador = factura?['estado'] == 'borrador';

    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(
        title: Text(factura != null ? 'Factura ${factura['numero_factura']}' : 'Factura', style: AppTextStyles.titulo(size: 16)),
        actions: [
          IconButton(
            icon: Icon(_mostrarUSD ? Icons.attach_money : Icons.currency_exchange, size: 20),
            tooltip: _mostrarUSD ? 'Ver en pesos' : 'Ver en dólares',
            onPressed: _alternarMoneda,
          ),
        ],
      ),
      floatingActionButton: esBorrador
          ? FloatingActionButton.extended(
              onPressed: _abrirAgregarProducto,
              backgroundColor: AppColors.acento,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.add),
              label: const Text('Agregar producto'),
            )
          : null,
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.acento))
          : _error != null
              ? Center(child: Text(_error!, style: AppTextStyles.cuerpo(color: AppColors.rojoAlerta)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Proveedor: ${factura!['proveedor_nombre'] ?? '-'}', style: AppTextStyles.cuerpo(color: AppColors.gris)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: (esBorrador ? AppColors.ambarBajo : AppColors.verdeOk).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            esBorrador ? 'BORRADOR' : 'CONFIRMADA',
                            style: AppTextStyles.etiqueta(size: 11, color: esBorrador ? AppColors.ambarBajo : AppColors.verdeOk),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_formatearFecha(factura['fecha_factura']?.toString()), style: AppTextStyles.subtitulo(size: 12, color: AppColors.gris)),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: AppColors.grisLinea),
                    const SizedBox(height: AppSpacing.sm),
                    if (detalles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: Text('Todavía no se han agregado productos', style: AppTextStyles.cuerpo(color: AppColors.gris))),
                      )
                    else
                      ...detalles.map((d) => Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.negro2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.grisLinea),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d['producto_nombre']?.toString() ?? 'Producto', style: AppTextStyles.cuerpo(size: 13, peso: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text('${d['cantidad']} x ${_dinero(double.tryParse(d['precio_unitario'].toString()) ?? 0)}', style: AppTextStyles.subtitulo(size: 12)),
                                          if (d['seccion_nombre'] != null) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.acentoSuave,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(d['seccion_nombre'].toString(), style: AppTextStyles.etiqueta(size: 9, color: AppColors.acento)),
                                            ),
                                          ],
                                        ],
                                      ),
                                     if (d['cantidad_restante'] != null && d['cantidad_restante'] != d['cantidad'])
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Quedan: ${d['cantidad_restante']} · ${_dinero((d['cantidad_restante'] as num) * (double.tryParse(d['precio_unitario'].toString()) ?? 0))}',
                                            style: AppTextStyles.subtitulo(
                                              size: 11,
                                              color: (d['cantidad_restante'] as num) == 0 ? AppColors.rojoAlerta : AppColors.ambarBajo,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _dinero(double.tryParse(d['valor_total'].toString()) ?? 0),
                                      style: (d['cantidad_restante'] != null && (d['cantidad_restante'] as num) == 0)
                                          ? AppTextStyles.cuerpo(size: 13, peso: FontWeight.w700, color: AppColors.gris)
                                          : AppTextStyles.cuerpo(size: 13, peso: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                if (esBorrador)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: AppColors.rojoAlerta),
                                    onPressed: () => _quitarProducto(d['id'] as int),
                                  ),
                              ],
                            ),
                          )),
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(color: AppColors.grisLinea),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total original', style: AppTextStyles.cuerpo(color: AppColors.gris)),
                        Text(_dinero(double.tryParse(factura['total'].toString()) ?? 0), style: AppTextStyles.subtitulo(size: 13)),
                      ],
                    ),
                    if (esBorrador == false) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Valor que queda', style: AppTextStyles.cuerpo(peso: FontWeight.w700)),
                          Text(
                            _dinero(detalles.fold<double>(0, (suma, d) {
                              final restante = (d['cantidad_restante'] as num?)?.toDouble() ?? 0;
                              final precio = double.tryParse(d['precio_unitario'].toString()) ?? 0;
                              return suma + (restante * precio);
                            })),
                            style: AppTextStyles.titulo(size: 16),
                          ),
                        ],
                      ),
                    ],
                    if (esBorrador && detalles.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmando ? null : _confirmarFactura,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeOk),
                          child: Text(_confirmando ? 'Confirmando...' : 'Confirmar factura'),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _HojaAgregarProducto extends StatefulWidget {
  final String token;
  final int facturaId;
  final VoidCallback onProductoAgregado;

  const _HojaAgregarProducto({
    required this.token,
    required this.facturaId,
    required this.onProductoAgregado,
  });

  @override
  State<_HojaAgregarProducto> createState() => _HojaAgregarProductoState();
}

class _HojaAgregarProductoState extends State<_HojaAgregarProducto> {
  final _busquedaController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _precioController = TextEditingController();
  final _busquedaFocus = FocusNode();
  final _cantidadFocus = FocusNode();
  final _precioFocus = FocusNode();
  List<dynamic> _resultados = [];
  Map<String, dynamic>? _productoElegido;
  bool _buscando = false;
  bool _guardando = false;
  bool _creandoProducto = false;
  bool _guardandoProductoNuevo = false;
  Timer? _debounce;

  List<dynamic> _secciones = [];
  int? _seccionNuevoProducto;

  final _nombreNuevoController = TextEditingController();
  final _categoriaNuevoController = TextEditingController();
  final _unidadNuevoController = TextEditingController(text: 'unidad');

  @override
  void initState() {
    super.initState();
    _cargarSecciones();
  }

  Future<void> _cargarSecciones() async {
    try {
      final secciones = await ApiService.getTodasLasSecciones(widget.token);
      setState(() => _secciones = secciones);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando secciones: $e'), backgroundColor: AppColors.rojoAlerta),
        );
      }
    }
  }

  void _buscarConRetraso(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _buscar(valor));
  }

  Future<void> _buscar(String texto) async {
    if (texto.trim().isEmpty) {
      setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final resultado = await ApiService.getProductos(widget.token, buscar: texto, pagina: 1);
      setState(() => _resultados = resultado['productos']);
    } catch (e) {
      // no bloquea
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _crearProductoRapido() async {
    if (_nombreNuevoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un nombre al producto'), backgroundColor: AppColors.rojoAlerta),
      );
      return;
    }
    if (_seccionNuevoProducto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige a qué almacén pertenece este producto'), backgroundColor: AppColors.rojoAlerta),
      );
      return;
    }
    

    setState(() => _guardandoProductoNuevo = true);
    try {
      final creado = await ApiService.crearProducto(
        token: widget.token,
        nombre: _nombreNuevoController.text.trim(),
        categoria: _categoriaNuevoController.text.trim().isEmpty ? null : _categoriaNuevoController.text.trim(),
        seccionId: _seccionNuevoProducto!,
        stockActual: 0,
        stockMinimo: 0,
        unidadMedida: _unidadNuevoController.text.trim().isEmpty ? 'unidad' : _unidadNuevoController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _productoElegido = creado;
        _creandoProducto = false;
        _guardandoProductoNuevo = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cantidadFocus.requestFocus();
      });
    } catch (e) {
      setState(() => _guardandoProductoNuevo = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
      );
    }
  }

  Future<void> _guardar() async {
    if (_productoElegido == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige un producto de la lista'), backgroundColor: AppColors.rojoAlerta),
      );
      return;
    }
    final cantidad = int.tryParse(_cantidadController.text);
    final precio = double.tryParse(_precioController.text);
    if (cantidad == null || cantidad <= 0 || precio == null || precio < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa la cantidad y el precio'), backgroundColor: AppColors.rojoAlerta),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await ApiService.agregarDetalleFactura(
        token: widget.token,
        facturaId: widget.facturaId,
        productoId: _productoElegido!['id'] as int,
        cantidad: cantidad,
        precioUnitario: precio,
      );
      if (!mounted) return;
      widget.onProductoAgregado();
      setState(() {
        _guardando = false;
        _productoElegido = null;
        _busquedaController.clear();
        _cantidadController.text = '1';
        _precioController.clear();
        _resultados = [];
      });
      FocusScope.of(context).requestFocus(_busquedaFocus);
    } catch (e) {
      setState(() => _guardando = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    _busquedaFocus.dispose();
    _cantidadFocus.dispose();
    _precioFocus.dispose();
    _nombreNuevoController.dispose();
    _categoriaNuevoController.dispose();
    _unidadNuevoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(AppSpacing.md),
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
                Text('Agregar producto', style: AppTextStyles.titulo(size: 18)),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check, size: 18, color: AppColors.verdeOk),
                  label: Text('Listo', style: AppTextStyles.cuerpo(size: 13, color: AppColors.verdeOk)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_productoElegido == null && _creandoProducto) ...[
              Text('Producto nuevo', style: AppTextStyles.cuerpo(peso: FontWeight.w700, size: 14)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _nombreNuevoController,
                style: AppTextStyles.cuerpo(),
                decoration: const InputDecoration(labelText: 'Nombre del producto *'),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int>(
                initialValue: _seccionNuevoProducto,
                decoration: const InputDecoration(labelText: 'Sección de destino *'),
                items: _secciones
                    .map<DropdownMenuItem<int>>((s) => DropdownMenuItem(value: s['id'] as int, child: Text(s['nombre'].toString())))
                    .toList(),
                onChanged: (v) => setState(() => _seccionNuevoProducto = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _categoriaNuevoController,
                style: AppTextStyles.cuerpo(),
                decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _unidadNuevoController,
                style: AppTextStyles.cuerpo(),
                decoration: const InputDecoration(labelText: 'Unidad de medida'),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _creandoProducto = false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _guardandoProductoNuevo ? null : _crearProductoRapido,
                      child: Text(_guardandoProductoNuevo ? 'Creando...' : 'Crear y elegir'),
                    ),
                  ),
                ],
              ),
            ] else if (_productoElegido == null) ...[
              TextField(
                controller: _busquedaController,
                focusNode: _busquedaFocus,
                autofocus: true,
                style: AppTextStyles.cuerpo(),
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre o código',
                  prefixIcon: Icon(Icons.search, color: AppColors.gris),
                ),
                onChanged: _buscarConRetraso,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_buscando) const Center(child: CircularProgressIndicator(color: AppColors.acento)),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _resultados.length,
                  itemBuilder: (context, index) {
                    final p = _resultados[index];
                    return ListTile(
                      title: Text(p['nombre'].toString(), style: AppTextStyles.cuerpo(size: 13)),
                      subtitle: Text('Stock: ${p['stock_actual']} ${p['unidad_medida']}', style: AppTextStyles.subtitulo(size: 11.5)),
                      onTap: () {
                        setState(() => _productoElegido = p);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _cantidadFocus.requestFocus();
                          _cantidadController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _cantidadController.text.length,
                          );
                        });
                      },
                    );
                  },
                ),
              ),
              if (!_buscando && _resultados.isEmpty && _busquedaController.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _creandoProducto = true;
                      _nombreNuevoController.text = _busquedaController.text.trim();
                    }),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Crear "${_busquedaController.text.trim()}" como producto nuevo'),
                  ),
                ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.negro3,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(_productoElegido!['nombre'].toString(), style: AppTextStyles.cuerpo(peso: FontWeight.w700))),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.gris),
                      onPressed: () => setState(() {
                        _productoElegido = null;
                        _cantidadController.text = '1';
                        _precioController.clear();
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _cantidadController,
                focusNode: _cantidadFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                style: AppTextStyles.cuerpo(),
                decoration: const InputDecoration(labelText: 'Cantidad'),
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_precioFocus),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _precioController,
                focusNode: _precioFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                style: AppTextStyles.cuerpo(),
                decoration: const InputDecoration(labelText: 'Precio unitario de esta compra'),
                onSubmitted: (_) => _guardar(),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(_guardando ? 'Guardando...' : 'Agregar a la factura'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}