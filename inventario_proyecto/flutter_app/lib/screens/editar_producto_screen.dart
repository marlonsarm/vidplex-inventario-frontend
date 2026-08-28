import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme.dart';

class EditarProductoScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> producto;

  const EditarProductoScreen({super.key, required this.token, required this.producto});

  @override
  State<EditarProductoScreen> createState() => _EditarProductoScreenState();
}

class _EditarProductoScreenState extends State<EditarProductoScreen> {
  late final TextEditingController _nombreController;
  late final TextEditingController _codigoController;
  late final TextEditingController _categoriaController;
  late final TextEditingController _stockMinimoController;
  late final TextEditingController _unidadController;

  Uint8List? _imagenBytes;
  String? _imagenNombre;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.producto['nombre']);
    _codigoController = TextEditingController(text: widget.producto['codigo_barras'] ?? '');
    _categoriaController = TextEditingController(text: widget.producto['categoria'] ?? '');
    _stockMinimoController = TextEditingController(text: '${widget.producto['stock_minimo']}');
    _unidadController = TextEditingController(text: widget.producto['unidad_medida'] ?? 'unidad');
  }

  Future<void> _elegirImagen() async {
    final picker = ImagePicker();
    final XFile? archivo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    setState(() {
      _imagenBytes = bytes;
      _imagenNombre = archivo.name;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      if (_imagenBytes != null) {
        await ApiService.subirFotoProducto(widget.token, widget.producto['id'], _imagenBytes!, _imagenNombre ?? 'foto.jpg');
      }

      await ApiService.editarProducto(
        token: widget.token,
        productoId: widget.producto['id'],
        codigoBarras: _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        categoria: _categoriaController.text.trim(),
        stockMinimo: int.tryParse(_stockMinimoController.text) ?? widget.producto['stock_minimo'],
        unidadMedida: _unidadController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto actualizado'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarEliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Seguro que quieres eliminar "${widget.producto['nombre']}"? Su historial de movimientos se conserva.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ApiService.eliminarProducto(widget.token, widget.producto['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoController.dispose();
    _categoriaController.dispose();
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
            decoration: BoxDecoration(color: AppColors.acentoSuave, borderRadius: BorderRadius.circular(8)),
            child: Icon(icono, size: 16, color: AppColors.acento),
          ),
          const SizedBox(width: 10),
          Text(texto, style: AppTextStyles.etiqueta(size: 12, color: AppColors.gris)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea, width: 1.2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea, width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.acento, width: 2)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -6, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? fotoUrl = widget.producto['foto_url'];

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
          'Editar: ${widget.producto['nombre']}',
          style: AppTextStyles.cuerpo(size: 15, peso: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.rojoAlerta),
            tooltip: 'Eliminar producto',
            onPressed: _confirmarEliminar,
          ),
        ],
      ),
      body: ListView(
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
                  border: Border.all(color: AppColors.acento, width: 2),
                  boxShadow: [BoxShadow(color: AppColors.acento.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: -6, offset: const Offset(0, 10))],
                  image: _imagenBytes != null
                      ? DecorationImage(image: MemoryImage(_imagenBytes!), fit: BoxFit.cover)
                      : (fotoUrl != null ? DecorationImage(image: NetworkImage(fotoUrl), fit: BoxFit.cover) : null),
                ),
                child: (_imagenBytes == null && fotoUrl == null)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(color: AppColors.acentoSuave, shape: BoxShape.circle),
                            child: const Icon(Icons.add_a_photo_rounded, size: 26, color: AppColors.acento),
                          ),
                          const SizedBox(height: 10),
                          Text('Cambiar foto', style: AppTextStyles.subtitulo(size: 12.5)),
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
                TextField(
                  controller: _nombreController,
                  style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w600),
                  decoration: _decoracion('Nombre del producto', icono: Icons.label_outline),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _codigoController,
                  style: AppTextStyles.cuerpo(size: 14.5),
                  decoration: _decoracion('Código de barras', icono: Icons.qr_code_2),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _categoriaController,
                  style: AppTextStyles.cuerpo(size: 14.5),
                  decoration: _decoracion('Categoría', icono: Icons.folder_outlined),
                ),
              ],
            ),
          ),
          _tituloSeccion(Icons.numbers_rounded, 'STOCK'),
          _tarjeta(
            child: Column(
              children: [
                TextField(
                  controller: _stockMinimoController,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w700),
                  decoration: _decoracion('Stock mínimo', icono: Icons.warning_amber_outlined),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _unidadController,
                  style: AppTextStyles.cuerpo(size: 14.5),
                  decoration: _decoracion('Unidad de medida', icono: Icons.straighten),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.acentoSuave, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.acento),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El stock actual (${widget.producto['stock_actual']}) solo se cambia con entradas/salidas, no aquí.',
                          style: AppTextStyles.subtitulo(size: 11.5, color: AppColors.acento),
                        ),
                      ),
                    ],
                  ),
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
                  onTap: _guardando ? null : _guardar,
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
                                Text('Guardar cambios', style: AppTextStyles.cuerpo(size: 13.5, color: Colors.white, peso: FontWeight.w700)),
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
    );
  }
}