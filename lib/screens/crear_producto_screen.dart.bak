import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme.dart';

class CrearProductoScreen extends StatefulWidget {
  final String token;

  const CrearProductoScreen({super.key, required this.token});

  @override
  State<CrearProductoScreen> createState() => _CrearProductoScreenState();
}

class _CrearProductoScreenState extends State<CrearProductoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _codigoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _stockActualController = TextEditingController(text: '0');
  final _stockMinimoController = TextEditingController(text: '0');
 final _unidadController = TextEditingController(text: 'unidad');

  Uint8List? _imagenBytes;
  String? _imagenNombre;

 int? _seccionSeleccionada;
  List<dynamic> _secciones = [];
  bool _cargandoSecciones = true;
  bool _guardando = false;

  Timer? _debounce;
  List<dynamic> _sugerencias = [];
  bool _buscandoSugerencias = false;
  Map<String, dynamic>? _productoSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarSecciones();
  }

  Future<void> _cargarSecciones() async {
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
  }

  Future<void> _elegirImagen() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;

    final picker = ImagePicker();
    final XFile? archivo = await picker.pickImage(
      source: origen,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (archivo == null) return;

    final bytes = await archivo.readAsBytes();
    setState(() {
      _imagenBytes = bytes;
      _imagenNombre = archivo.name;
    });
  }

  void _onNombreChanged(String texto) {
    if (_productoSeleccionado != null) {
      setState(() => _productoSeleccionado = null);
    }
    _debounce?.cancel();
    if (texto.trim().length < 2) {
      setState(() => _sugerencias = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _buscandoSugerencias = true);
      try {
        final resultado = await ApiService.getProductos(widget.token, buscar: texto.trim(), porPagina: 8);
        if (!mounted) return;
        setState(() => _sugerencias = resultado['productos'] ?? []);
      } catch (e) {
        if (mounted) setState(() => _sugerencias = []);
      } finally {
        if (mounted) setState(() => _buscandoSugerencias = false);
      }
    });
  }

  void _seleccionarSugerencia(Map<String, dynamic> producto) {
    setState(() {
      _nombreController.text = producto['nombre'];
      _productoSeleccionado = producto;
      _sugerencias = [];
    });
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    final nombreIngresado = _nombreController.text.trim();

    Map<String, dynamic>? productoExistente = _productoSeleccionado;
    if (productoExistente == null) {
      try {
        productoExistente = await ApiService.buscarProductoPorNombre(widget.token, nombreIngresado);
      } catch (e) {
        productoExistente = null;
      }
    }

    if (productoExistente != null && mounted) {
      final cantidadASumar = int.tryParse(_stockActualController.text) ?? 0;
      final continuar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Este producto ya existe'),
          content: Text(
            'Ya existe "${productoExistente!['nombre']}" con stock actual '
            '${productoExistente['stock_actual']} ${productoExistente['unidad_medida']}.\n\n'
            'Si continúas, se sumará $cantidadASumar a ese producto en vez de crear uno nuevo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sumar stock a ese producto'),
            ),
          ],
        ),
      );

      if (continuar != true) return;

      setState(() => _guardando = true);
      try {
        await ApiService.registrarMovimiento(
          token: widget.token,
          productoId: productoExistente['id'],
          tipo: 'entrada',
          cantidad: cantidadASumar,
          motivo: 'Ingreso agregado desde formulario (nombre ya existía)',
        );

        if (_imagenBytes != null) {
          try {
            await ApiService.subirFotoProducto(
              widget.token,
              productoExistente['id'],
              _imagenBytes!,
              _imagenNombre ?? 'foto.jpg',
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Stock actualizado, pero la foto no se pudo subir: $e'), backgroundColor: Colors.orange),
              );
            }
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock actualizado correctamente'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _guardando = false);
      }
      return;
    }

    setState(() => _guardando = true);
try {
      final creado = await ApiService.crearProducto(
        token: widget.token,
        codigoBarras: _codigoController.text.trim().isEmpty ? null : _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        categoria: _categoriaController.text.trim(),
        seccionId: _seccionSeleccionada!,
        stockActual: int.parse(_stockActualController.text),
        stockMinimo: int.parse(_stockMinimoController.text),
        unidadMedida: _unidadController.text.trim().isEmpty ? 'unidad' : _unidadController.text.trim(),
      );

      if (_imagenBytes != null) {
        try {
          await ApiService.subirFotoProducto(widget.token, creado['id'], _imagenBytes!, _imagenNombre ?? 'foto.jpg');
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Producto creado, pero la foto no se pudo subir: $e'), backgroundColor: Colors.orange),
            );
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto creado correctamente'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true); // true = "se creó algo, refresca la lista"
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _guardando = false);
    }
  }
  @override
  void dispose() {
    _debounce?.cancel();
    _codigoController.dispose();
    _nombreController.dispose();
    _categoriaController.dispose();
    _stockActualController.dispose();
    _stockMinimoController.dispose();
    _unidadController.dispose();
    super.dispose();
  }
  Widget _tituloSeccion(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.acentoSuave,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, size: 16, color: AppColors.acento),
          ),
          const SizedBox(width: 10),
          Text(
            texto,
            style: AppTextStyles.etiqueta(size: 12, color: AppColors.gris),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracion(String label, {IconData? icono}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icono != null ? Icon(icono, size: 19, color: AppColors.gris) : null,
      filled: true,
      fillColor: AppColors.negro,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.grisLinea, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.grisLinea, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.acento, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.rojoAlerta, width: 1.4),
      ),
      labelStyle: AppTextStyles.subtitulo(size: 13.5),
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.grisLinea),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -6, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.negro,
       appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: true,
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
              child: const Icon(Icons.add_box_rounded, size: 17, color: AppColors.acento),
            ),
            const SizedBox(width: 10),
            Text('Nuevo producto', style: AppTextStyles.cuerpo(size: 16, peso: FontWeight.w800)),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Center(
              child: GestureDetector(
                onTap: _elegirImagen,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.negro2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _imagenBytes != null ? AppColors.acento : AppColors.grisLinea,
                      width: _imagenBytes != null ? 2 : 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.acento.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: -6, offset: const Offset(0, 10)),
                    ],
                    image: _imagenBytes != null
                        ? DecorationImage(image: MemoryImage(_imagenBytes!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imagenBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(color: AppColors.acentoSuave, shape: BoxShape.circle),
                              child: const Icon(Icons.add_a_photo_rounded, size: 26, color: AppColors.acento),
                            ),
                            const SizedBox(height: 10),
                            Text('Agregar foto', style: AppTextStyles.subtitulo(size: 12.5)),
                          ],
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppColors.acento, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            _tituloSeccion(Icons.inventory_2_outlined, 'INFORMACIÓN DEL PRODUCTO'),
            _tarjeta(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombreController,
                    style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w600),
                    decoration: _decoracion('Nombre del producto *', icono: Icons.label_outline),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                    onChanged: _onNombreChanged,
                  ),
                  if (_buscandoSugerencias)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2, color: AppColors.acento),
                    ),
                  if (_sugerencias.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: AppColors.negro2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.grisLinea),
                      ),
                      child: Column(
                        children: _sugerencias.map<Widget>((p) => ListTile(
                          dense: true,
                          title: Text(p['nombre'], style: AppTextStyles.cuerpo(size: 13.5, peso: FontWeight.w600)),
                          subtitle: Text('Stock: ${p['stock_actual']} ${p['unidad_medida']}', style: AppTextStyles.subtitulo(size: 12)),
                          onTap: () => _seleccionarSugerencia(p),
                        )).toList(),
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codigoController,
                    style: AppTextStyles.cuerpo(size: 14.5),
                    decoration: _decoracion('Código de barras (opcional)', icono: Icons.qr_code_2),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _categoriaController,
                    style: AppTextStyles.cuerpo(size: 14.5),
                    decoration: _decoracion('Categoría (opcional)', icono: Icons.folder_outlined),
                  ),
                ],
              ),
            ),
            _tituloSeccion(Icons.dashboard_customize_outlined, 'UBICACIÓN'),
            _tarjeta(
              child: _cargandoSecciones
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator(color: AppColors.acento)),
                    )
                  : DropdownButtonFormField<int>(
                      initialValue: _seccionSeleccionada,
                      style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w600),
                      decoration: _decoracion('Sección *'),
                      items: _secciones
                          .map<DropdownMenuItem<int>>(
                            (s) => DropdownMenuItem(value: s['id'], child: Text(s['nombre'])),
                          )
                          .toList(),
                      onChanged: (valor) => setState(() => _seccionSeleccionada = valor),
                    ),
            ),
            _tituloSeccion(Icons.numbers_rounded, 'STOCK'),
            _tarjeta(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockActualController,
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w700),
                          decoration: _decoracion('Stock actual', icono: Icons.inventory_2_outlined),
                          validator: (v) => (int.tryParse(v ?? '') == null) ? 'Número inválido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stockMinimoController,
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w700),
                          decoration: _decoracion('Stock mínimo', icono: Icons.warning_amber_outlined),
                          validator: (v) => (int.tryParse(v ?? '') == null) ? 'Número inválido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _unidadController,
                    style: AppTextStyles.cuerpo(size: 14.5),
                    decoration: _decoracion('Unidad de medida', icono: Icons.straighten),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.boton),
                  gradient: const LinearGradient(colors: [AppColors.acento, AppColors.acentoOscuro], begin: Alignment.centerLeft, end: Alignment.centerRight),
                  boxShadow: [BoxShadow(color: AppColors.acento.withValues(alpha: 0.30), blurRadius: 14, spreadRadius: -4, offset: const Offset(0, 6))],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.boton),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.boton),
                    onTap: _guardando ? null : _guardarProducto,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Center(
                        child: _guardando
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 17),
                                  const SizedBox(width: 7),
                                  Text('Guardar producto', style: AppTextStyles.cuerpo(size: 13.5, color: Colors.white, peso: FontWeight.w700)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}