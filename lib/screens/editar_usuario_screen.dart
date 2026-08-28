import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme.dart';

class EditarUsuarioScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> usuario;

  const EditarUsuarioScreen({super.key, required this.token, required this.usuario});

  @override
  State<EditarUsuarioScreen> createState() => _EditarUsuarioScreenState();
}

class _EditarUsuarioScreenState extends State<EditarUsuarioScreen> {
  static const Color _azul = AppColors.acento;

  late final TextEditingController _nombreController;
  late final TextEditingController _cedulaController;
  late final TextEditingController _cargoController;
  final _passwordController = TextEditingController();

  late bool _puedeVerStock;
  late bool _puedeRegistrarEntrada;
  late bool _puedeRegistrarSalida;
  late bool _puedeCrearProductos;
  late bool _puedeEliminarFacturas;
  late bool _puedeVerFacturas;

  List<dynamic> _secciones = [];
  bool _cargandoSecciones = true;
  bool _guardando = false;
  bool _eliminando = false;

  // Secciones activas para este usuario, y categorías elegidas dentro de cada una.
  // Si una sección está activa pero su lista de categorías está vacía = ve TODAS las
  // categorías de esa sección. Si tiene categorías específicas = solo ve esas.
  final Set<int> _seccionesActivas = {};
  final Map<int, List<String>> _categoriasSeleccionadas = {};
  final Map<int, List<dynamic>> _categoriasDisponibles = {};
  final Set<int> _cargandoCategoriasDe = {};

  Uint8List? _imagenBytes;
  String? _imagenNombre;

  bool get _esSuperAdmin => widget.usuario['es_super_admin'] == true;

  @override
  void initState() {
    super.initState();
  _nombreController = TextEditingController(text: widget.usuario['nombre_completo']);
    _cedulaController = TextEditingController(text: widget.usuario['cedula'] ?? '');
    _cargoController = TextEditingController(text: widget.usuario['cargo'] ?? '');
    _puedeVerStock = widget.usuario['puede_ver_stock'] ?? false;
    _puedeRegistrarEntrada = widget.usuario['puede_registrar_entrada'] ?? false;
    _puedeRegistrarSalida = widget.usuario['puede_registrar_salida'] ?? false;
    _puedeCrearProductos = widget.usuario['puede_crear_productos'] ?? false;
    _puedeEliminarFacturas = widget.usuario['puede_eliminar_facturas'] ?? false;
    _puedeVerFacturas = widget.usuario['puede_ver_facturas'] ?? false;

    final permisos = widget.usuario['secciones_permitidas'] as List<dynamic>? ?? [];
    for (final p in permisos) {
      final seccionId = p['seccion_id'] as int;
      final categorias = (p['categorias'] as List<dynamic>? ?? []).map((c) => c.toString()).toList();
      _seccionesActivas.add(seccionId);
      _categoriasSeleccionadas[seccionId] = categorias;
    }

    _cargarSecciones();
  }

  Future<void> _cargarSecciones() async {
    try {
      final secciones = await ApiService.getSecciones(widget.token);
      setState(() => _secciones = secciones);
      for (final id in _seccionesActivas) {
        _cargarCategoriasDe(id);
      }
    } catch (e) {
      // no bloquea el resto del formulario
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
      final actuales = List<String>.from(_categoriasSeleccionadas[seccionId] ?? []);
      if (activa) {
        if (!actuales.contains(categoria)) actuales.add(categoria);
      } else {
        actuales.remove(categoria);
      }
      _categoriasSeleccionadas[seccionId] = actuales;
    });
  }

  void _marcarTodasLasCategorias(int seccionId, List<dynamic> disponibles) {
    setState(() {
      _categoriasSeleccionadas[seccionId] = disponibles.map((c) => _nombreCategoria(c)).toList();
    });
  }

  void _limpiarCategorias(int seccionId) {
    setState(() => _categoriasSeleccionadas[seccionId] = []);
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

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      if (_imagenBytes != null) {
        await ApiService.subirFotoUsuario(
          widget.token,
          widget.usuario['id'],
          _imagenBytes!,
          _imagenNombre ?? 'foto.jpg',
        );
      }

      await ApiService.editarUsuario(
        token: widget.token,
        usuarioId: widget.usuario['id'],
        nombreCompleto: _nombreController.text.trim(),
        cedula: _cedulaController.text.trim(),
        cargo: _cargoController.text.trim().isEmpty ? null : _cargoController.text.trim(),
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
        puedeVerStock: _esSuperAdmin ? null : _puedeVerStock,
        puedeRegistrarEntrada: _esSuperAdmin ? null : _puedeRegistrarEntrada,
        puedeRegistrarSalida: _esSuperAdmin ? null : _puedeRegistrarSalida,
        puedeCrearProductos: _esSuperAdmin ? null : _puedeCrearProductos,
        puedeEliminarFacturas: _esSuperAdmin ? null : _puedeEliminarFacturas,
        puedeVerFacturas: _esSuperAdmin ? null : _puedeVerFacturas,
      );

      if (!_esSuperAdmin) {
        final seccionesPayload = _seccionesActivas.map((id) {
          return {
            'seccion_id': id,
            'categorias': _categoriasSeleccionadas[id] ?? [],
          };
        }).toList();

        await ApiService.asignarSecciones(
          token: widget.token,
          usuarioId: widget.usuario['id'],
          secciones: seccionesPayload,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario actualizado'), backgroundColor: Colors.green),
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
    Map<String, dynamic>? impacto;
    try {
      impacto = await ApiService.verImpactoEliminarUsuario(widget.token, widget.usuario['id']);
    } catch (e) {
      // si falla, seguimos igual con el diálogo, solo sin el detalle de impacto
    }

    if (!mounted) return;

    String modo = 'conservar';
    final passwordController = TextEditingController();
    final tieneHistorial = impacto?['tiene_historial'] == true;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Eliminar a ${widget.usuario['nombre_completo']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tieneHistorial) ...[
                      Text(
                        'Este usuario tiene ${impacto?['total_facturas'] ?? 0} facturas y '
                        '${impacto?['total_movimientos'] ?? 0} movimientos registrados. ¿Qué hacemos con eso?',
                      ),
                      const SizedBox(height: 12),
                      RadioGroup<String>(
                        groupValue: modo,
                        onChanged: (v) => setDialogState(() => modo = v!),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Conservar todo'),
                              subtitle: const Text('Las facturas y movimientos se quedan, solo se desvinculan de este usuario'),
                              value: 'conservar',
                            ),
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Borrar todo', style: TextStyle(color: Colors.red)),
                              subtitle: const Text('Se eliminan también sus facturas y movimientos'),
                              value: 'borrar_todo',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else
                      const Text('Este usuario no tiene facturas ni movimientos registrados todavía.'),
                    const Text('Ingresa tu contraseña de administrador para confirmar.'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmado != true) return;
    if (!mounted) return;

    setState(() => _eliminando = true);
    try {
      await ApiService.eliminarUsuario(
        token: widget.token,
        usuarioId: widget.usuario['id'],
        password: passwordController.text,
        modo: modo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario eliminado'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _eliminando = false);
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

  Widget _permisoTile({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: valor ? AppColors.acentoSuave : AppColors.negro2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: valor ? _azul : AppColors.grisLinea, width: valor ? 1.4 : 1),
        boxShadow: valor
            ? [BoxShadow(color: _azul.withValues(alpha: 0.12), blurRadius: 10, spreadRadius: -4, offset: const Offset(0, 4))]
            : [],
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icono, color: valor ? _azul : AppColors.gris),
        title: Text(titulo, style: AppTextStyles.cuerpo(size: 14, peso: FontWeight.w700)),
        subtitle: Text(descripcion, style: AppTextStyles.subtitulo(size: 12)),
        value: valor,
        activeThumbColor: _azul,
        onChanged: (v) => onChanged(v),
      ),
    );
  }

  Widget _tarjetaSeccion(dynamic s) {
    final int seccionId = s['id'] as int;
    final bool activa = _seccionesActivas.contains(seccionId);
    final List<dynamic> categoriasDisp = _categoriasDisponibles[seccionId] ?? [];
    final bool cargandoCategorias = _cargandoCategoriasDe.contains(seccionId);
    final List<String> categoriasElegidas = _categoriasSeleccionadas[seccionId] ?? [];

    String subtitulo;
    if (!activa) {
      subtitulo = 'No asignada';
    } else if (categoriasDisp.isEmpty && !cargandoCategorias) {
      subtitulo = 'Sin categorías definidas · verá todo';
    } else if (categoriasElegidas.isEmpty) {
      subtitulo = 'Verá todas las categorías (${categoriasDisp.length})';
    } else {
      subtitulo = '${categoriasElegidas.length} de ${categoriasDisp.length} categorías seleccionadas';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: activa ? _azul : AppColors.grisLinea, width: activa ? 1.6 : 1),
        boxShadow: activa
            ? [BoxShadow(color: _azul.withValues(alpha: 0.14), blurRadius: 14, spreadRadius: -4, offset: const Offset(0, 6))]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: Text(
              s['nombre'],
              style: AppTextStyles.cuerpo(size: 15, peso: FontWeight.w800, color: activa ? AppColors.blanco : AppColors.gris),
            ),
            subtitle: Text(
              subtitulo,
              style: AppTextStyles.subtitulo(size: 12, color: activa ? _azul : AppColors.gris),
            ),
            value: activa,
            activeThumbColor: _azul,
            onChanged: (v) => _toggleSeccion(seccionId, v),
          ),
          if (activa)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: cargandoCategorias
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : categoriasDisp.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'CATEGORÍAS VISIBLES',
                                  style: AppTextStyles.etiqueta(size: 11, color: AppColors.gris),
                                ),
                                const Spacer(),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _marcarTodasLasCategorias(seccionId, categoriasDisp),
                                  child: const Text('Todas', style: TextStyle(fontSize: 12)),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _limpiarCategorias(seccionId),
                                  child: const Text('Ninguna', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
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
                                  checkmarkColor: _azul,
                                  labelStyle: TextStyle(
                                    color: elegida ? _azul : AppColors.blanco,
                                    fontWeight: elegida ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                  side: BorderSide(color: elegida ? _azul : AppColors.grisLinea, width: elegida ? 1.4 : 1),
                                  onSelected: (v) => _toggleCategoria(seccionId, nombre, v),
                                );
                              }).toList(),
                            ),
                          ],
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
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.negro,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.blanco,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, _azul, Colors.transparent]),
            ),
          ),
        ),
        title: Text(
          'Editar: ${widget.usuario['nombre_completo']}',
          style: AppTextStyles.cuerpo(size: 15, peso: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.rojoAlerta),
            tooltip: 'Eliminar usuario',
            onPressed: _eliminando ? null : _confirmarEliminar,
          ),
        ],
      ),
      body: _cargandoSecciones
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
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
                        border: Border.all(color: _azul, width: 2.4),
                        boxShadow: [BoxShadow(color: _azul.withValues(alpha: 0.25), blurRadius: 18, spreadRadius: -4, offset: const Offset(0, 8))],
                        image: _imagenBytes != null
                            ? DecorationImage(image: MemoryImage(_imagenBytes!), fit: BoxFit.cover)
                            : (widget.usuario['foto_url'] != null
                                ? DecorationImage(
                                    image: NetworkImage('http://localhost:8000${widget.usuario['foto_url']}'),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                      ),
                      child: (_imagenBytes == null && widget.usuario['foto_url'] == null)
                          ? Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(color: AppColors.acentoSuave, shape: BoxShape.circle),
                              child: const Icon(Icons.add_a_photo_rounded, size: 24, color: AppColors.acento),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.acentoSuave, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.badge_outlined, size: 16, color: _azul),
                      ),
                      const SizedBox(width: 10),
                      Text('DATOS PERSONALES', style: AppTextStyles.etiqueta(size: 12, color: AppColors.gris)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.negro2,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.grisLinea),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -6, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nombreController,
                        style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: const Icon(Icons.person_outline, size: 19, color: AppColors.gris),
                          filled: true,
                          fillColor: AppColors.negro,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _azul, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _cedulaController,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.cuerpo(size: 14.5),
                        decoration: InputDecoration(
                          labelText: 'Cédula',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 19, color: AppColors.gris),
                          filled: true,
                          fillColor: AppColors.negro,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _azul, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _cargoController,
                        style: AppTextStyles.cuerpo(size: 14.5),
                        decoration: InputDecoration(
                          labelText: 'Cargo',
                          prefixIcon: const Icon(Icons.work_outline, size: 19, color: AppColors.gris),
                          filled: true,
                          fillColor: AppColors.negro,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _azul, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: AppTextStyles.cuerpo(size: 14.5),
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña (deja vacío para no cambiarla)',
                          prefixIcon: const Icon(Icons.lock_outline, size: 19, color: AppColors.gris),
                          filled: true,
                          fillColor: AppColors.negro,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grisLinea)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _azul, width: 2)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_esSuperAdmin) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.acentoSuave, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.tune_rounded, size: 16, color: _azul),
                      ),
                      const SizedBox(width: 10),
                      Text('PERMISOS', style: AppTextStyles.etiqueta(size: 12.5, color: AppColors.gris)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _permisoTile(
                    icono: Icons.visibility_outlined,
                    titulo: 'Ver el stock',
                    descripcion: 'Puede consultar existencias de sus secciones',
                    valor: _puedeVerStock,
                    onChanged: (v) => setState(() => _puedeVerStock = v),
                  ),
                  _permisoTile(
                    icono: Icons.arrow_downward_rounded,
                    titulo: 'Registrar entradas',
                    descripcion: 'Puede sumar unidades al inventario',
                    valor: _puedeRegistrarEntrada,
                    onChanged: (v) => setState(() => _puedeRegistrarEntrada = v),
                  ),
                  _permisoTile(
                    icono: Icons.arrow_upward_rounded,
                    titulo: 'Registrar salidas',
                    descripcion: 'Puede descontar unidades del inventario',
                    valor: _puedeRegistrarSalida,
                    onChanged: (v) => setState(() => _puedeRegistrarSalida = v),
                  ),
                  _permisoTile(
                    icono: Icons.add_box_outlined,
                    titulo: 'Crear productos nuevos',
                    descripcion: 'Puede dar de alta productos en sus secciones',
                    valor: _puedeCrearProductos,
                    onChanged: (v) => setState(() => _puedeCrearProductos = v),
                  ),
                  _permisoTile(
                    icono: Icons.receipt_long_outlined,
                    titulo: 'Usar facturas',
                    descripcion: 'Sin esto no puede entrar al módulo de facturas',
                    valor: _puedeVerFacturas,
                    onChanged: (v) => setState(() => _puedeVerFacturas = v),
                  ),
                  _permisoTile(
                    icono: Icons.delete_outline,
                    titulo: 'Eliminar facturas',
                    descripcion: 'Puede borrar facturas (con reglas de seguridad)',
                    valor: _puedeEliminarFacturas,
                    onChanged: (v) => setState(() => _puedeEliminarFacturas = v),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('SECCIONES Y CATEGORÍAS', style: AppTextStyles.etiqueta(size: 12.5, color: AppColors.gris)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.acentoSuave, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${_seccionesActivas.length} de ${_secciones.length}',
                          style: AppTextStyles.cuerpo(size: 11.5, peso: FontWeight.w800, color: _azul),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Activa las secciones que puede ver. Dentro de cada una, si no eliges '
                    'categorías, verá todas; si eliges algunas, solo verá esas.',
                    style: AppTextStyles.subtitulo(size: 12.5),
                  ),
                  const SizedBox(height: 12),
                  ..._secciones.map(_tarjetaSeccion),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.ambarBajo.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.ambarBajo.withValues(alpha: 0.35), width: 1.4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.ambarBajo),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Este usuario es Super Admin: tiene acceso total y no maneja permisos individuales.',
                            style: AppTextStyles.cuerpo(size: 13, peso: FontWeight.w600, color: AppColors.ambarBajo),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Center(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.boton),
                      gradient: LinearGradient(colors: [_azul, AppColors.acentoOscuro], begin: Alignment.centerLeft, end: Alignment.centerRight),
                      boxShadow: [BoxShadow(color: _azul.withValues(alpha: 0.30), blurRadius: 14, spreadRadius: -4, offset: const Offset(0, 6))],
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
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _eliminando ? null : _confirmarEliminar,
                    icon: _eliminando
                        ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rojoAlerta))
                        : const Icon(Icons.delete_outline, size: 17, color: AppColors.rojoAlerta),
                    label: Text('Eliminar usuario', style: AppTextStyles.cuerpo(size: 13, color: AppColors.rojoAlerta, peso: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.rojoAlerta, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.boton)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}