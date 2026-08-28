import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme.dart';

class CrearUsuarioScreen extends StatefulWidget {
  final String token;

  const CrearUsuarioScreen({super.key, required this.token});

  @override
  State<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends State<CrearUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _cargoController = TextEditingController();
  final _passwordController = TextEditingController();

  Uint8List? _imagenBytes;
  String? _imagenNombre;

  bool _esSuperAdmin = false;
  bool _puedeVerStock = true;
  bool _puedeRegistrarEntrada = false;
  bool _puedeRegistrarSalida = false;
  bool _puedeCrearProductos = false;
  bool _puedeEliminarFacturas = false;
  bool _puedeVerFacturas = false;

  List<dynamic> _secciones = [];
  bool _cargandoSecciones = true;
  bool _guardando = false;

  // Igual que en la pantalla de editar: secciones activas + categorías elegidas por sección.
  // Sección activa sin categorías marcadas = ve todas las categorías de esa sección.
  final Set<int> _seccionesActivas = {};
  final Map<int, List<String>> _categoriasSeleccionadas = {};
  final Map<int, List<dynamic>> _categoriasDisponibles = {};
  final Set<int> _cargandoCategoriasDe = {};

  @override
  void initState() {
    super.initState();
    _cargarSecciones();
  }

  Future<void> _cargarSecciones() async {
    try {
      final secciones = await ApiService.getSecciones(widget.token);
      setState(() => _secciones = secciones);
    } catch (e) {
      // si falla, el formulario igual funciona para super_admin (no necesita secciones)
    } finally {
      setState(() => _cargandoSecciones = false);
    }
  }

  Future<void> _cargarCategoriasDe(int seccionId) async {
    if (_categoriasDisponibles.containsKey(seccionId)) return;
    setState(() => _cargandoCategoriasDe.add(seccionId));
    try {
      final categorias = await ApiService.getCategorias(widget.token, seccionId);
      setState(() => _categoriasDisponibles[seccionId] = categorias);
    } catch (e) {
      // si falla, simplemente no se muestran categorías para elegir
    } finally {
      setState(() => _cargandoCategoriasDe.remove(seccionId));
    }
  }

  String _nombreCategoria(dynamic item) {
    if (item is String) return item;
    if (item is Map) return (item['categoria'] ?? item['nombre'] ?? '').toString();
    return item.toString();
  }

  void _toggleSeccion(int seccionId, bool activa) {
    setState(() {
      if (activa) {
        _seccionesActivas.add(seccionId);
        _categoriasSeleccionadas.putIfAbsent(seccionId, () => []);
        _cargarCategoriasDe(seccionId);
      } else {
        _seccionesActivas.remove(seccionId);
        _categoriasSeleccionadas.remove(seccionId);
      }
    });
  }

  void _toggleCategoria(int seccionId, String categoria, bool activa) {
    setState(() {
      final actuales = _categoriasSeleccionadas[seccionId] ?? [];
      if (activa) {
        if (!actuales.contains(categoria)) actuales.add(categoria);
      } else {
        actuales.remove(categoria);
      }
      _categoriasSeleccionadas[seccionId] = actuales;
    });
  }

  Future<void> _elegirImagen() async {
    final picker = ImagePicker();
    final XFile? archivo = await picker.pickImage(
      source: ImageSource.gallery,
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

  Future<void> _guardarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final seccionesPayload = _esSuperAdmin
          ? <Map<String, dynamic>>[]
          : _seccionesActivas.map((id) {
              return {
                'seccion_id': id,
                'categorias': _categoriasSeleccionadas[id] ?? [],
              };
            }).toList();

      final creado = await ApiService.crearUsuario(
        token: widget.token,
        nombreCompleto: _nombreController.text.trim(),
        cedula: _cedulaController.text.trim(),
        cargo: _cargoController.text.trim().isEmpty ? null : _cargoController.text.trim(),
        password: _passwordController.text,
        esSuperAdmin: _esSuperAdmin,
        puedeVerStock: _puedeVerStock,
        puedeRegistrarEntrada: _puedeRegistrarEntrada,
        puedeRegistrarSalida: _puedeRegistrarSalida,
        puedeCrearProductos: _puedeCrearProductos,
        puedeEliminarFacturas: _puedeEliminarFacturas,
        puedeVerFacturas: _puedeVerFacturas,
        secciones: seccionesPayload,
      );

      // Nota: el usuario queda "pendiente" hasta que se verifique el código enviado
      // al correo, así que todavía no tiene un id real de usuario para subirle foto aquí.
      if (_imagenBytes != null && creado['id'] != null) {
        try {
          await ApiService.subirFotoUsuario(widget.token, creado['id'], _imagenBytes!, _imagenNombre ?? 'foto.jpg');
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Usuario creado, pero la foto no se pudo subir: $e'), backgroundColor: Colors.orange),
            );
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(creado['mensaje'] ?? 'Usuario creado. Actívalo desde la lista de usuarios.'), backgroundColor: Colors.green),
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

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    _cargoController.dispose();
    _passwordController.dispose();
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
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rojoAlerta, width: 1.4)),
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

  Widget _permisoCheck({
    required IconData icono,
    required String titulo,
    String? subtitulo,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: valor ? AppColors.acentoSuave : AppColors.negro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: valor ? AppColors.acento : AppColors.grisLinea, width: valor ? 1.4 : 1),
      ),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icono, color: valor ? AppColors.acento : AppColors.gris),
        title: Text(titulo, style: AppTextStyles.cuerpo(size: 14, peso: FontWeight.w700)),
        subtitle: subtitulo != null ? Text(subtitulo, style: AppTextStyles.subtitulo(size: 12)) : null,
        value: valor,
        activeColor: AppColors.acento,
        onChanged: (v) => onChanged(v ?? false),
      ),
    );
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
              child: const Icon(Icons.person_add_alt_1_rounded, size: 17, color: AppColors.acento),
            ),
            const SizedBox(width: 10),
            Text('Nuevo usuario', style: AppTextStyles.cuerpo(size: 16, peso: FontWeight.w800)),
          ],
        ),
      ),
      body: _cargandoSecciones
          ? const Center(child: CircularProgressIndicator(color: AppColors.acento))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _elegirImagen,
                      child: Container(
                        width: 120,
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.negro2,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.acento, width: 2.4),
                          boxShadow: [BoxShadow(color: AppColors.acento.withValues(alpha: 0.20), blurRadius: 18, spreadRadius: -4, offset: const Offset(0, 8))],
                          image: _imagenBytes != null
                              ? DecorationImage(image: MemoryImage(_imagenBytes!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _imagenBytes == null
                            ? Container(
                                padding: const EdgeInsets.all(14),
                                decoration: const BoxDecoration(color: AppColors.acentoSuave, shape: BoxShape.circle),
                                child: const Icon(Icons.add_a_photo_rounded, size: 24, color: AppColors.acento),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _tituloSeccion(Icons.badge_outlined, 'DATOS PERSONALES'),
                  _tarjeta(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nombreController,
                          style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w600),
                          decoration: _decoracion('Nombre completo *', icono: Icons.person_outline),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _cedulaController,
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.cuerpo(size: 14.5),
                          decoration: _decoracion('Cédula *', icono: Icons.badge_outlined),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _cargoController,
                          style: AppTextStyles.cuerpo(size: 14.5),
                          decoration: _decoracion('Cargo (ej. Gestión Humana)', icono: Icons.work_outline),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: AppTextStyles.cuerpo(size: 14.5),
                          decoration: _decoracion('Contraseña *', icono: Icons.lock_outline),
                          validator: (v) => (v == null || v.length < 4) ? 'Mínimo 4 caracteres' : null,
                        ),
                      ],
                    ),
                  ),
                  _tituloSeccion(Icons.shield_outlined, 'NIVEL DE ACCESO'),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _esSuperAdmin ? AppColors.ambarBajo.withValues(alpha: 0.10) : AppColors.negro2,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: _esSuperAdmin ? AppColors.ambarBajo.withValues(alpha: 0.4) : AppColors.grisLinea, width: 1.4),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(Icons.shield_rounded, color: _esSuperAdmin ? AppColors.ambarBajo : AppColors.gris),
                      title: Text('Es Super Admin', style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w800)),
                      subtitle: Text('Control total, sin restricciones. Puede crear otros usuarios.', style: AppTextStyles.subtitulo(size: 12)),
                      value: _esSuperAdmin,
                      activeThumbColor: AppColors.ambarBajo,
                      onChanged: (valor) => setState(() => _esSuperAdmin = valor),
                    ),
                  ),
                  if (!_esSuperAdmin) ...[
                    _tituloSeccion(Icons.tune_rounded, 'PERMISOS'),
                    _permisoCheck(
                      icono: Icons.visibility_outlined,
                      titulo: 'Puede ver el stock',
                      valor: _puedeVerStock,
                      onChanged: (v) => setState(() => _puedeVerStock = v),
                    ),
                    _permisoCheck(
                      icono: Icons.arrow_downward_rounded,
                      titulo: 'Puede registrar entradas',
                      valor: _puedeRegistrarEntrada,
                      onChanged: (v) => setState(() => _puedeRegistrarEntrada = v),
                    ),
                    _permisoCheck(
                      icono: Icons.arrow_upward_rounded,
                      titulo: 'Puede registrar salidas',
                      valor: _puedeRegistrarSalida,
                      onChanged: (v) => setState(() => _puedeRegistrarSalida = v),
                    ),
                    _permisoCheck(
                      icono: Icons.add_box_outlined,
                      titulo: 'Puede crear productos nuevos',
                      valor: _puedeCrearProductos,
                      onChanged: (v) => setState(() => _puedeCrearProductos = v),
                    ),
                    _permisoCheck(
                      icono: Icons.receipt_long_outlined,
                      titulo: 'Puede usar facturas',
                      subtitulo: 'Sin esto no puede entrar al módulo de facturas',
                      valor: _puedeVerFacturas,
                      onChanged: (v) => setState(() => _puedeVerFacturas = v),
                    ),
                    _permisoCheck(
                      icono: Icons.delete_outline,
                      titulo: 'Puede eliminar facturas',
                      valor: _puedeEliminarFacturas,
                      onChanged: (v) => setState(() => _puedeEliminarFacturas = v),
                    ),
                    _tituloSeccion(Icons.dashboard_customize_outlined, 'SECCIONES Y CATEGORÍAS'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Marca las secciones que puede ver. Dentro de cada una, si no marcas '
                        'ninguna categoría, verá todas; si marcas categorías específicas, solo verá esas.',
                        style: AppTextStyles.subtitulo(size: 12.5),
                      ),
                    ),
                    ..._secciones.map((s) {
                      final seccionId = s['id'] as int;
                      final activa = _seccionesActivas.contains(seccionId);
                      final categoriasDisp = _categoriasDisponibles[seccionId] ?? [];
                      final cargandoCategorias = _cargandoCategoriasDe.contains(seccionId);
                      final categoriasElegidas = _categoriasSeleccionadas[seccionId] ?? [];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.negro2,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: activa ? AppColors.acento : AppColors.grisLinea, width: activa ? 1.6 : 1),
                          boxShadow: activa
                              ? [BoxShadow(color: AppColors.acento.withValues(alpha: 0.14), blurRadius: 14, spreadRadius: -4, offset: const Offset(0, 6))]
                              : [],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              secondary: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: activa ? AppColors.acentoSuave : AppColors.negro,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(Icons.folder_outlined, size: 17, color: activa ? AppColors.acento : AppColors.gris),
                              ),
                              title: Text(
                                s['nombre'],
                                style: AppTextStyles.cuerpo(size: 14, peso: FontWeight.w700, color: activa ? AppColors.acento : AppColors.blanco),
                              ),
                              value: activa,
                              activeColor: AppColors.acento,
                              onChanged: (v) => _toggleSeccion(seccionId, v ?? false),
                            ),
                            if (activa)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: cargandoCategorias
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.acento)),
                                      )
                                    : categoriasDisp.isEmpty
                                        ? Text(
                                            'Esta sección no tiene categorías definidas (verá todo).',
                                            style: AppTextStyles.subtitulo(size: 12),
                                          )
                                        : Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: categoriasDisp.map((c) {
                                              final nombre = _nombreCategoria(c);
                                              final elegida = categoriasElegidas.contains(nombre);
                                              return FilterChip(
                                                label: Text(nombre, style: const TextStyle(fontSize: 12.5)),
                                                selected: elegida,
                                                backgroundColor: AppColors.negro,
                                                selectedColor: AppColors.acentoSuave,
                                                checkmarkColor: AppColors.acento,
                                                labelStyle: TextStyle(color: elegida ? AppColors.acento : AppColors.blanco, fontWeight: elegida ? FontWeight.w700 : FontWeight.normal),
                                                side: BorderSide(color: elegida ? AppColors.acento : AppColors.grisLinea, width: elegida ? 1.4 : 1),
                                                onSelected: (v) => _toggleCategoria(seccionId, nombre, v),
                                              );
                                            }).toList(),
                                          ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                   const SizedBox(height: 10),
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
                          onTap: _guardando ? null : _guardarUsuario,
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
                                        Text('Crear usuario', style: AppTextStyles.cuerpo(size: 13.5, color: Colors.white, peso: FontWeight.w700)),
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
