import 'dart:async';
import '../services/excel_download_web.dart' if (dart.library.io) '../services/excel_download_stub.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/beep.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'scan_screen.dart';
import 'crear_producto_screen.dart';
import 'crear_usuario_screen.dart';
import 'lista_usuarios_screen.dart';
import 'ver_producto_screen.dart';
import 'facturas_screen.dart';
import 'perfil_usuario_screen.dart';
class DashboardScreen extends StatefulWidget {
  final String token;
  final String nombre;
  final String? fotoUrl;
  final bool esSuperAdmin;
  final bool puedeCrearProductos;
  final bool puedeRegistrarEntrada;
  final bool puedeRegistrarSalida;
  final bool puedeTransferir;
  final bool puedeEliminarFacturas;
  final bool puedeVerFacturas;
  final String cargo;
  final String cedula;

  const DashboardScreen({
    super.key,
    required this.token,
    required this.nombre,
    this.fotoUrl,
    required this.esSuperAdmin,
    required this.puedeCrearProductos,
    required this.puedeRegistrarEntrada,
    required this.puedeRegistrarSalida,
    this.puedeTransferir = false,
    this.puedeEliminarFacturas = false,
    this.puedeVerFacturas = false,
    this.cargo = '',
    this.cedula = '',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}



class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _productos = [];
  List<dynamic> _secciones = [];
  int? _seccionSeleccionada;
  List<dynamic> _categorias = [];
  String? _categoriaSeleccionada;
  bool _cargandoCategorias = false;
  int _alertasStockBajo = 0;
  bool _alertaMostrada = false;
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;
  final _busquedaController = TextEditingController();
  String _textoBusqueda = '';
  int _paginaActual = 1;
  int _totalProductos = 0;
  Timer? _debounce;
  final _scrollController = ScrollController();
  bool _vistaLista = false;
  bool _busquedaAbierta = false;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.imageCache.maximumSize = 300;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20; // 150 MB
    _cargarSecciones();
    _cargarProductos();
    _scrollController.addListener(_onScroll);
  }
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _cargarMasProductos();
    }
  }

  void _buscarConRetraso(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _textoBusqueda = valor);
      _cargarProductos();
    });
  }

 Future<void> _cargarSecciones() async {
    try {
      final secciones = await ApiService.getSecciones(widget.token);
      setState(() => _secciones = secciones);
    } catch (e) {
      // no bloquea el resto del dashboard
    }
  }

  Future<void> _seleccionarSeccion(int? seccionId) async {
    setState(() {
      _seccionSeleccionada = seccionId;
      _categoriaSeleccionada = null;
      _categorias = [];
    });

    if (seccionId == null) {
      _cargarProductos();
      return;
    }

    setState(() => _cargandoCategorias = true);
    try {
      final categorias = await ApiService.getCategorias(widget.token, seccionId);
      setState(() => _categorias = categorias);
      if (categorias.isEmpty) {
        _cargarProductos();
      }
    } catch (e) {
      // si falla, se comporta como sección sin categorías
      _cargarProductos();
    } finally {
      setState(() => _cargandoCategorias = false);
    }
  }

  void _seleccionarCategoria(String categoria) {
    setState(() => _categoriaSeleccionada = categoria);
    _cargarProductos();
  }

  void _volverACarpetas() {
    setState(() {
      _categoriaSeleccionada = null;
      _productos = [];
    });
  }

  Future<void> _cargarProductos() async {
    setState(() {
      _cargando = true;
      _error = null;
      _paginaActual = 1;
      _productos = [];
    });
    try {
      final resultado = await ApiService.getProductos(
        widget.token,
        seccionId: _seccionSeleccionada,
        categoria: _categoriaSeleccionada,
        buscar: _textoBusqueda.isEmpty ? null : _textoBusqueda,
        pagina: 1,
      );
      final alertas = await ApiService.getAlertasStockBajo(widget.token);
      setState(() {
        _productos = resultado['productos'];
        _totalProductos = resultado['total'];
        _alertasStockBajo = alertas.length;
      });
      if (widget.esSuperAdmin && _alertasStockBajo > 0 && !_alertaMostrada) {
        _alertaMostrada = true;
        _mostrarAlertaStockBajo();
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  Future<void> _cargarMasProductos() async {
    if (_cargandoMas || _productos.length >= _totalProductos) return;

    setState(() => _cargandoMas = true);
    try {
      final siguientePagina = _paginaActual + 1;
      final resultado = await ApiService.getProductos(
        widget.token,
        seccionId: _seccionSeleccionada,
        categoria: _categoriaSeleccionada,
        buscar: _textoBusqueda.isEmpty ? null : _textoBusqueda,
        pagina: siguientePagina,
      );
      setState(() {
        _productos.addAll(resultado['productos']);
        _paginaActual = siguientePagina;
      });
      if (mounted) {
        for (final p in resultado['productos']) {
          final String? fotoUrl = p['foto_url'];
          if (fotoUrl != null) {
            precacheImage(
              CachedNetworkImageProvider(_urlFoto(fotoUrl, width: 220)),
              context,
            );
          }
        }
      }
    } catch (e) {
      // silencioso, no interrumpe lo ya cargado
    } finally {
      setState(() => _cargandoMas = false);
    }
  }

  Future<void> _mostrarAlertaStockBajo() async {
    reproducirBeep();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
     icon: const Icon(Icons.warning_amber_rounded, color: AppColors.ambarBajo, size: 48),
        title: Text('Stock bajo', style: AppTextStyles.titulo(size: 18)),
        content: Text(
          _alertasStockBajo == 1
              ? 'Hay 1 producto con stock por debajo del mínimo.'
              : 'Hay $_alertasStockBajo productos con stock por debajo del mínimo.',
          textAlign: TextAlign.center,
          style: AppTextStyles.cuerpo(color: AppColors.gris),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido', style: TextStyle(color: AppColors.acento)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _moverStock(Map producto, String tipo) async {
    int cantidad = 1;
    final cantidadController = TextEditingController(text: '1');
    final motivoController = TextEditingController();
    final esEntrada = tipo == 'entrada';
    final colorTema = esEntrada ? AppColors.verdeOk : AppColors.rojoAlerta;
    final String? fotoUrl = producto['foto_url'];

    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.negro2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.grisLinea)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grisLinea,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: AppColors.negro3,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.grisLinea),
                      image: fotoUrl != null
                          ? DecorationImage(
                              image: NetworkImage('${AppConfig.baseUrl}$fotoUrl'),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: fotoUrl == null
                        ? const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.gris)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    producto['nombre'],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titulo(size: 18),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.negro3,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Stock actual: ${producto['stock_actual']} ${producto['unidad_medida']}',
                      style: AppTextStyles.subtitulo(size: 13),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: colorTema.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      esEntrada ? 'ENTRADA' : 'SALIDA',
                      style: AppTextStyles.etiqueta(size: 12, color: colorTema),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                           Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: colorTema.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (cantidad > 1) {
                              setModalState(() {
                                cantidad--;
                                cantidadController.text = '$cantidad';
                              });
                            }
                          },
                          icon: const Icon(Icons.remove),
                          iconSize: 26,
                          color: colorTema,
                          splashRadius: 24,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: cantidadController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.titulo(size: 32),
                          decoration: const InputDecoration(border: InputBorder.none),
                          onChanged: (valor) {
                            final n = int.tryParse(valor);
                            if (n != null && n >= 1) {
                              setModalState(() => cantidad = n);
                            }
                          },
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: colorTema.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () {
                            setModalState(() {
                              cantidad++;
                              cantidadController.text = '$cantidad';
                            });
                          },
                          icon: const Icon(Icons.add),
                          iconSize: 26,
                          color: colorTema,
                          splashRadius: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: motivoController,
                    style: AppTextStyles.cuerpo(),
                    decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                                   Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.boton),
                      boxShadow: [
                        BoxShadow(
                          color: colorTema.withValues(alpha: 0.40),
                          blurRadius: 18,
                          spreadRadius: -4,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorTema,
                        elevation: 0,
                      ),
                      child: Text(esEntrada ? 'Confirmar entrada' : 'Confirmar salida'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancelar', style: AppTextStyles.cuerpo(color: AppColors.gris)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmar != true) return;

    try {
      final resultado = await ApiService.registrarMovimiento(
        token: widget.token,
        codigoBarras: producto['codigo_barras'],
        productoId: producto['id'] as int?,
        tipo: tipo,
        cantidad: cantidad,
        motivo: motivoController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listo, nuevo stock: ${resultado['stock_resultante']}')),
      );
      _cargarProductos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.rojoAlerta,
        ),
      );
    }
  }

  Future<void> _exportarExcel({int? seccionId, String? nombreArchivo}) async {
    try {
      final bytes = await ApiService.exportarExcel(widget.token, seccionId: seccionId);
      await descargarExcelWeb(bytes, nombreArchivo ?? 'inventario.xlsx');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.rojoAlerta,
        ),
      );
    }
  }

 Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _accionCirculo({
    required IconData icono,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = AppColors.gris,
    Color fondo = Colors.transparent,
  }) {
    return Tooltip(
      message: tooltip,
  child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: fondo == Colors.transparent ? Colors.white.withValues(alpha: 0.18) : fondo,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icono, size: 22, color: color),
          ),
        ),
      ),
    );
  }
  String _saludoSegunHora() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _fraseMotivacional() {
    const frases = [
      'Cada producto en su lugar, cada movimiento bajo control.',
      'Con Vidplex, tu inventario nunca te toma por sorpresa.',
      'Orden hoy, tranquilidad mañana.',
      'Un inventario claro es una empresa más fuerte.',
      'Sigamos construyendo precisión, un producto a la vez.',
    ];
    return frases[DateTime.now().day % frases.length];
  }
  String _urlFoto(String url, {int width = 220}) {
    if (url.startsWith('http')) {
      final partes = url.split('/upload/');
      if (partes.length == 2) {
        return '${partes[0]}/upload/w_$width,q_auto,f_auto/${partes[1]}';
      }
      return url;
    }
    return '${AppConfig.baseUrl}$url';
  }

Widget _bannerBienvenida() {
  final tieneFoto = widget.fotoUrl != null && widget.fotoUrl!.isNotEmpty;

  const fondoOscuro = Color(0xFF161618);
  const plataClaro = Color(0xFFE4E4E7);
  const plataMedio = Color(0xFF8E8E93);
  const pildoraFondo = Color(0x14FFFFFF);

  return ClipRRect(
    borderRadius: const BorderRadius.only(
      bottomLeft: Radius.circular(24),
      bottomRight: Radius.circular(24),
    ),
   child: Container(
     decoration: BoxDecoration(
        color: const Color(0xFF0E0E10),
        image: DecorationImage(
          image: const AssetImage('assets/images/fachada_vidplex.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),

            BlendMode.srcOver,
          ),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE4E4E7), Color(0xFF6E6E73)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.acento.withValues(alpha: 0.35), Colors.transparent],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 14, 8),
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.esSuperAdmin || widget.puedeCrearProductos || widget.puedeVerFacturas)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: pildoraFondo,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (widget.esSuperAdmin || widget.puedeCrearProductos)
                                _accionCirculo(
                                  icono: Icons.add_box_outlined,
                                  tooltip: 'Nuevo producto',
                                  color: plataClaro,
                                  onPressed: () async {
                                    final creado = await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => CrearProductoScreen(token: widget.token)),
                                    );
                                    if (creado == true) _cargarProductos();
                                  },
                                ),

                              if (widget.esSuperAdmin || widget.puedeVerFacturas)
                                _accionCirculo(
                                  icono: Icons.receipt_long_outlined,
                                  tooltip: 'Facturas',
                                  color: plataMedio,
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FacturasScreen(
                                          token: widget.token,
                                          puedeEliminar: widget.esSuperAdmin || widget.puedeEliminarFacturas,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              if (widget.esSuperAdmin)
                                _accionCirculo(
                                  icono: Icons.group_outlined,
                                  tooltip: 'Ver usuarios',
                                  color: plataMedio,
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => ListaUsuariosScreen(token: widget.token)),
                                    );
                                  },
                                ),
                              if (widget.esSuperAdmin)
                                _accionCirculo(
                                  icono: Icons.group_add_outlined,
                                  tooltip: 'Nuevo usuario',
                                  color: plataMedio,
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => CrearUsuarioScreen(token: widget.token)),
                                    );
                                  },
                                ),
                          if (widget.esSuperAdmin)
                                Container(
                                  width: 46,
                                  height: 46,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: PopupMenuButton<int?>(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.file_download_outlined, size: 20, color: plataMedio),
                                    tooltip: 'Exportar a Excel',
                                    color: AppColors.negro2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    onSelected: (seccionId) {
                                      final nombre = seccionId == null
                                          ? 'inventario_completo.xlsx'
                                          : 'inventario_${_secciones.firstWhere((s) => s['id'] == seccionId)['nombre'].toString().replaceAll(' ', '_')}.xlsx';
                                      _exportarExcel(seccionId: seccionId, nombreArchivo: nombre);
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(value: null, child: Text('Todo el inventario', style: AppTextStyles.cuerpo())),
                                      const PopupMenuDivider(),
                                      ..._secciones.map((s) => PopupMenuItem(value: s['id'] as int, child: Text(s['nombre'], style: AppTextStyles.cuerpo()))),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        const Spacer(),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: pildoraFondo,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _accionCirculo(
                              icono: Icons.person_outline,
                              tooltip: 'Mi perfil',
                              color: plataClaro,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => PerfilUsuarioScreen(token: widget.token)),
                                );
                              },
                            ),
                            _accionCirculo(
                              icono: Icons.logout,
                              tooltip: 'Cerrar sesión',
                              color: AppColors.rojoAlerta,
                              onPressed: _cerrarSesion,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.12)),
                      const SizedBox(width: 10),
                      Image.asset('assets/images/logo_vidplex.png', height: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [plataClaro.withValues(alpha: 0.9), plataMedio.withValues(alpha: 0.4)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5)),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: fondoOscuro),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                    image: tieneFoto
                                        ? DecorationImage(
                                            image: NetworkImage('${AppConfig.baseUrl}${widget.fotoUrl}'),
                                            fit: BoxFit.cover,
                                            alignment: Alignment.center,
                                          )
                                        : null,
                                  ),
                                  child: !tieneFoto
                                      ? Center(
                                          child: Text(
                                            widget.nombre.isNotEmpty ? widget.nombre[0].toUpperCase() : '?',
                                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 23),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.verdeOk,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: fondoOscuro, width: 2.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: 0.1),
                        ),
                        if (widget.cargo.isNotEmpty || widget.cedula.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(color: plataClaro, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  [
                                    if (widget.cargo.isNotEmpty) widget.cargo.toUpperCase(),
                                    if (widget.cedula.isNotEmpty) 'C.C. ${widget.cedula}',
                                  ].join('   ·   '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: plataMedio, fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                 const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 15, color: plataClaro.withValues(alpha: 0.7)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${_saludoSegunHora()}, ${widget.nombre.split(' ').first} — ${_fraseMotivacional()}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: plataClaro.withValues(alpha: 0.95), fontSize: 14, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  List<Widget> _sliversDeContenido() {
    final bool mostrarCategorias = _seccionSeleccionada != null &&
        _categoriaSeleccionada == null &&
        (_categorias.isNotEmpty || _cargandoCategorias);

    if (mostrarCategorias) {
      if (_cargandoCategorias) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: AppColors.acento)),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.1,
            ),
            itemCount: _categorias.length,
            itemBuilder: (context, index) {
              final cat = _categorias[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.negro2,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.grisLinea),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: -4, offset: const Offset(0, 5)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () => _seleccionarCategoria(cat['categoria']),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.acento.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            cat['categoria'] == '__sin_categoria__' ? Icons.inventory_2_outlined : Icons.folder_outlined,
                            size: 32,
                            color: AppColors.acento,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          cat['categoria'] == '__sin_categoria__' ? 'Sin categoría' : cat['categoria'],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cuerpo(peso: FontWeight.w700, size: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${cat['total']} productos',
                          style: AppTextStyles.subtitulo(size: 11.5, color: AppColors.gris),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ];
    }

    if (_cargando) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: AppColors.acento)),
        ),
      ];
    }

    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text(_error!, style: AppTextStyles.cuerpo(color: AppColors.rojoAlerta))),
        ),
      ];
    }

    if (_productos.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              _textoBusqueda.isEmpty ? 'No hay productos todavía' : 'Sin resultados para "$_textoBusqueda"',
              style: AppTextStyles.cuerpo(color: AppColors.gris),
            ),
          ),
        ),
      ];
    }

    if (_vistaLista) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _productos.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(color: AppColors.acento)),
                  );
                }
                final producto = _productos[index];
                final bool stockBajo = producto['stock_actual'] <= producto['stock_minimo'];
                return InkWell(
                  onTap: () async {
                    final actualizado = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VerProductoScreen(
                          token: widget.token,
                          producto: producto,
                          puedeEditar: widget.esSuperAdmin || widget.puedeCrearProductos,
                          puedeRegistrarEntrada: widget.esSuperAdmin || widget.puedeRegistrarEntrada,
                          puedeRegistrarSalida: widget.esSuperAdmin || widget.puedeRegistrarSalida,
                        ),
                      ),
                    );
                    if (actualizado == true) _cargarProductos();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.negro2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: stockBajo ? AppColors.ambarBajo.withValues(alpha: 0.5) : AppColors.grisLinea,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (stockBajo)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(color: AppColors.ambarBajo, shape: BoxShape.circle),
                          ),
                        Expanded(
                          child: Text(
                            producto['nombre'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cuerpo(size: 13, peso: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${producto['stock_actual']} ${producto['unidad_medida']}',
                          style: AppTextStyles.subtitulo(
                            size: 12,
                            color: stockBajo ? AppColors.rojoAlerta : AppColors.gris,
                          ),
                        ),
                        if (widget.esSuperAdmin || widget.puedeRegistrarEntrada)
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.verdeOk),
                            onPressed: () => _moverStock(producto, 'entrada'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        if (widget.esSuperAdmin || widget.puedeRegistrarSalida)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.rojoAlerta),
                            onPressed: () => _moverStock(producto, 'salida'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                );
              },
              childCount: _productos.length + (_cargandoMas ? 1 : 0),
              addAutomaticKeepAlives: false,
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, 100),
        sliver: SliverGrid.builder(
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          addSemanticIndexes: false,
         gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
            childAspectRatio: 0.68,
          ),
          itemCount: _productos.length + (_cargandoMas ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _productos.length) {
              return const Center(child: CircularProgressIndicator(color: AppColors.acento));
            }

            const List<String> fotosPrueba = [
              'https://res.cloudinary.com/sla80nsi/image/upload/v1787171587/ii3_nrtox3.jpg',
              'https://res.cloudinary.com/sla80nsi/image/upload/v1787171587/ii2_pfwf2u.jpg',
              'https://res.cloudinary.com/sla80nsi/image/upload/v1787171571/ii1_cj6nc0.jpg',
            ];
            final producto = _productos[index];
            final bool stockBajo = producto['stock_actual'] <= producto['stock_minimo'];
            final String? fotoUrl = producto['foto_url'] ?? fotosPrueba[index % 3];
            return RepaintBoundary(
              child: Container(
              decoration: BoxDecoration(
                color: AppColors.negro2,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: stockBajo ? AppColors.ambarBajo.withValues(alpha: 0.5) : AppColors.grisLinea,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
             child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  onTap: () async {
                    final actualizado = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VerProductoScreen(
                          token: widget.token,
                          producto: producto,
                          puedeEditar: widget.esSuperAdmin || widget.puedeCrearProductos,
                          puedeRegistrarEntrada: widget.esSuperAdmin || widget.puedeRegistrarEntrada,
                          puedeRegistrarSalida: widget.esSuperAdmin || widget.puedeRegistrarSalida,
                        ),
                      ),
                    );
                    if (actualizado == true) _cargarProductos();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.negro3, AppColors.negro2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: fotoUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: _urlFoto(fotoUrl, width: 220),
                                        fit: BoxFit.cover,
                                        memCacheWidth: 220,
                                        fadeInDuration: const Duration(milliseconds: 150),
                                        placeholder: (context, url) => const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.acento),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Center(
                                          child: Icon(Icons.broken_image_outlined, size: 34, color: AppColors.gris.withValues(alpha: 0.5)),
                                        ),
                                      )
                                    : Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.04),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.inventory_2_outlined, size: 30, color: AppColors.gris.withValues(alpha: 0.6)),
                                        ),
                                      ),
                              ),
                            ),
                            if (stockBajo)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.ambarBajo,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(color: AppColors.ambarBajo.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Text('BAJO', style: AppTextStyles.etiqueta(size: 9, color: Colors.white)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              producto['nombre'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.cuerpo(peso: FontWeight.w700, size: 12.5),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${producto['stock_actual']} ${producto['unidad_medida']}',
                                  style: AppTextStyles.subtitulo(
                                    size: 11.5,
                                    color: stockBajo ? AppColors.rojoAlerta : AppColors.gris,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.esSuperAdmin || widget.puedeRegistrarEntrada)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.verdeOk,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: InkWell(
                                          onTap: () => _moverStock(producto, 'entrada'),
                                          borderRadius: BorderRadius.circular(8),
                                          child: const Padding(
                                            padding: EdgeInsets.all(7),
                                            child: Icon(Icons.add, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                   if (widget.esSuperAdmin || widget.puedeRegistrarSalida)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.rojoAlerta,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: InkWell(
                                          onTap: () => _moverStock(producto, 'salida'),
                                          borderRadius: BorderRadius.circular(8),
                                          child: const Padding(
                                            padding: EdgeInsets.all(7),
                                            child: Icon(Icons.remove, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                   ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8DEE8),
  
        floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.boton),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ScanScreen(
                  token: widget.token,
                  puedeCrearProductos: widget.esSuperAdmin || widget.puedeCrearProductos,
                ),
              ),
            );
            _cargarProductos();
          },
          backgroundColor: AppColors.acento,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear'),
        ),
      ),
   body: RefreshIndicator(
        color: AppColors.acento,
        backgroundColor: AppColors.negro2,
        onRefresh: _cargarProductos,
        child: Scrollbar(
          controller: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            cacheExtent: 300,
            slivers: [
              SliverToBoxAdapter(child: RepaintBoundary(child: _bannerBienvenida())),
 
              if (_categoriaSeleccionada != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    child: InkWell(
                      onTap: _volverACarpetas,
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.acento),
                          const SizedBox(width: 6),
                          Text(
                            _categoriaSeleccionada == '__sin_categoria__' ? 'Sin categoría' : _categoriaSeleccionada!,
                            style: AppTextStyles.cuerpo(size: 13, peso: FontWeight.w700, color: AppColors.acento),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, 0),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.md, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 22, spreadRadius: -4, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: _busquedaAbierta ? 260 : 185,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A5F), Color(0xFF2C5282)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF2C5282).withValues(alpha: 0.35), blurRadius: 10, spreadRadius: -2, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: _busquedaAbierta
                            ? TextField(
                                controller: _busquedaController,
                                autofocus: true,
                                style: AppTextStyles.cuerpo(size: 13.5, color: const Color(0xFF1E3A5F)),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Buscar...',
                                  hintStyle: TextStyle(fontSize: 13, color: const Color(0xFF1E3A5F).withValues(alpha: 0.5)),
                                  prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A5F), size: 20),
                                  suffixIcon: IconButton(
                                  icon: Icon(Icons.close, size: 18, color: const Color(0xFF1E3A5F).withValues(alpha: 0.8)),
                                    onPressed: () {
                                      _busquedaController.clear();
                                      setState(() {
                                        _textoBusqueda = '';
                                        _busquedaAbierta = false;
                                      });
                                      _cargarProductos();
                                    },
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onChanged: _buscarConRetraso,
                              )
                            : InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() => _busquedaAbierta = true),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.search, color: Colors.white, size: 17),
                                      const SizedBox(width: 6),
                                      Text('Buscar', style: AppTextStyles.subtitulo(size: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      if (_secciones.isNotEmpty)
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Todas'),
                                  selected: _seccionSeleccionada == null,
                                  onSelected: (_) => _seleccionarSeccion(null),
                                  backgroundColor: const Color(0xFFF1F3F7),
                                  selectedColor: const Color(0xFF2C5282),
                                  showCheckmark: false,
                                  elevation: 0,
                                  pressElevation: 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  side: BorderSide(
                                    color: _seccionSeleccionada == null ? Colors.transparent : AppColors.grisLinea,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                                  labelStyle: AppTextStyles.cuerpo(
                                    size: 13,
                                    peso: FontWeight.w700,
                                    color: _seccionSeleccionada == null ? Colors.white : AppColors.gris,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ..._secciones.map((s) => Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: ChoiceChip(
                                        label: Text(s['nombre']),
                                        selected: _seccionSeleccionada == s['id'],
                                        onSelected: (_) => _seleccionarSeccion(s['id']),
                                        backgroundColor: const Color(0xFFF1F3F7),
                                        selectedColor: const Color(0xFF2C5282),
                                        showCheckmark: false,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        side: BorderSide(
                                          color: _seccionSeleccionada == s['id'] ? Colors.transparent : AppColors.grisLinea,
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                                        labelStyle: AppTextStyles.cuerpo(
                                          size: 13.5,
                                          peso: FontWeight.w700,
                                          color: _seccionSeleccionada == s['id'] ? Colors.white : AppColors.gris,
                                        ),
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(color: AppColors.negro2, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(_vistaLista ? Icons.grid_view_rounded : Icons.view_list_rounded, color: AppColors.acento, size: 20),
                          tooltip: _vistaLista ? 'Ver en cuadrícula' : 'Ver en lista',
                          onPressed: () => setState(() => _vistaLista = !_vistaLista),
                          iconSize: 20,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
              ..._sliversDeContenido(),
            ],
          ),
        ),
      ),
    );
  }
}