import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config.dart';

MediaType _tipoDeImagen(String nombreArchivo) {
  final ext = nombreArchivo.toLowerCase().split('.').last;
  if (ext == 'png') return MediaType('image', 'png');
  if (ext == 'webp') return MediaType('image', 'webp');
  return MediaType('image', 'jpeg'); // jpg/jpeg por defecto
}

class ApiService {
// Inicia sesión y devuelve el token + datos del usuario
  static Future<Map<String, dynamic>> login(String cedula, String password) async {
    final url = Uri.parse('${AppConfig.baseUrl}/auth/login');

    final respuesta = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'cedula': cedula, 'password': password}),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al iniciar sesión');
    }
  }
// Trae productos por bloques (paginado), con búsqueda opcional del lado del servidor
 static Future<Map<String, dynamic>> getProductos(
    String token, {
    int? seccionId,
    String? categoria,
    String? buscar,
    int pagina = 1,
    int porPagina = 50,
  }) async {
    final params = <String, String>{
      'pagina': '$pagina',
      'por_pagina': '$porPagina',
    };
    if (seccionId != null) params['seccion_id'] = '$seccionId';
    if (categoria != null) params['categoria'] = categoria;
    if (buscar != null && buscar.isNotEmpty) params['buscar'] = buscar;

    final url = Uri.parse('${AppConfig.baseUrl}/productos/').replace(queryParameters: params);

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body); // { "total": N, "productos": [...] }
    } else {
      throw Exception('No se pudieron cargar los productos');
    }
  }
  // Busca un producto por su código escaneado
  static Future<Map<String, dynamic>> buscarPorCodigo(String token, String codigo) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/buscar/$codigo');

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Producto no encontrado');
    }
  }

  // Busca un producto existente por nombre exacto (sin distinguir mayúsculas/tildes).
  // Devuelve null si no existe ninguno con ese nombre.
  static Future<Map<String, dynamic>?> buscarProductoPorNombre(String token, String nombre) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/buscar-por-nombre')
        .replace(queryParameters: {'nombre': nombre});

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else if (respuesta.statusCode == 404) {
      return null;
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al buscar el producto por nombre');
    }
  }

  // Busca productos existentes cuyo nombre contenga el texto dado (búsqueda parcial)
  static Future<List<dynamic>> buscarProductosPorNombreParcial(String token, String nombre) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/buscar-por-nombre-parcial')
        .replace(queryParameters: {'nombre': nombre});

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      final data = jsonDecode(respuesta.body);
      return data['productos'];
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al buscar productos');
    }
  }

  // Asigna un código de barras nuevo a un producto que ya existe en el inventario
  static Future<Map<String, dynamic>> asignarCodigoAlterno({
    required String token,
    required int productoId,
    required String codigoBarras,
    int stockIngresado = 0,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/$productoId/asignar-codigo');

    final respuesta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'codigo_barras': codigoBarras,
        'stock_ingresado': stockIngresado,
      }),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al asignar el código al producto');
    }
  }

  // Registra una entrada o salida de stock
  static Future<Map<String, dynamic>> registrarMovimiento({
    required String token,
    String? codigoBarras,
    int? productoId,
    required String tipo,
    required int cantidad,
    String? motivo,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/movimientos/registrar');

    final respuesta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'codigo_barras': codigoBarras,
        'producto_id': productoId,
        'tipo': tipo,
        'cantidad': cantidad,
        'motivo': motivo ?? '',
      }),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al registrar el movimiento');
    }
  }

  // Cuando se escanea un código que no existe: lo asocia a un producto
  // ya existente (buscado por nombre) o crea uno nuevo desde cero
  static Future<Map<String, dynamic>> resolverCodigo({
    required String token,
    required String codigoBarras,
    required String nombre,
    String? categoria,
    required int seccionId,
    required int stockIngresado,
    int stockMinimo = 0,
    String unidadMedida = 'unidad',
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/resolver-codigo');

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
        'stock_ingresado': stockIngresado,
        'stock_minimo': stockMinimo,
        'unidad_medida': unidadMedida,
      }),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al resolver el código escaneado');
    }
  }

  // Crea un producto nuevo
  static Future<Map<String, dynamic>> crearProducto({
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
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al crear el producto');
    }
  }

  // Trae los productos que ya están en o bajo su stock mínimo
  static Future<List<dynamic>> getAlertasStockBajo(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/alertas/stock-bajo');

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudieron cargar las alertas');
    }
  }

  // Trae TODAS las secciones sin filtrar (para elegir destino de un producto nuevo)
  static Future<List<dynamic>> getTodasLasSecciones(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/secciones/todas');
    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudieron cargar las secciones');
    }
  }

  // Trae la lista de secciones
  static Future<List<dynamic>> getSecciones(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/secciones/');

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudieron cargar las secciones');
    }
  }
// Crea un usuario nuevo (solo Super Admin)
 static Future<Map<String, dynamic>> crearUsuario({
    required String token,
    required String nombreCompleto,
    required String cedula,
    required String password,
    required bool esSuperAdmin,
    required bool puedeVerStock,
    required bool puedeRegistrarEntrada,
    required bool puedeRegistrarSalida,
    required bool puedeCrearProductos,
    bool puedeEliminarFacturas = false,
    bool puedeVerFacturas = false,
    String? cargo,
    List<Map<String, dynamic>> secciones = const [],
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/');

    final respuesta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'nombre_completo': nombreCompleto,
        'cedula': cedula,
        'password': password,
        'es_super_admin': esSuperAdmin,
        'puede_ver_stock': puedeVerStock,
        'puede_registrar_entrada': puedeRegistrarEntrada,
        'puede_registrar_salida': puedeRegistrarSalida,
        'puede_crear_productos': puedeCrearProductos,
        'puede_eliminar_facturas': puedeEliminarFacturas,
        'puede_ver_facturas': puedeVerFacturas,
        'cargo': cargo,
        'secciones': secciones,
      }),
    );
    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al crear el usuario');
    }
  }

  // Verifica manualmente un usuario pendiente desde el panel (pide la contraseña del admin)
  static Future<Map<String, dynamic>> verificarUsuarioPendiente({
    required String token,
    required int pendienteId,
    required String password,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/pendientes/$pendienteId/verificar');

    final respuesta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'password': password}),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al verificar el usuario');
    }
  }

  // Trae los usuarios que aún no han verificado su correo
  static Future<List<dynamic>> getUsuariosPendientes(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/pendientes');
    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudo cargar la lista de usuarios pendientes');
    }
  }

  // Trae la lista de todos los usuarios (solo Super Admin)
  static Future<List<dynamic>> getUsuarios(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/');

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudo cargar la lista de usuarios');
    }
  }

  // Activa o desactiva un usuario
  static Future<void> cambiarEstadoUsuario(String token, int usuarioId, bool activo) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/$usuarioId/estado?activo=$activo');

    final respuesta = await http.patch(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode != 200) {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al cambiar el estado del usuario');
    }
  }

  // Edita nombre, correo, contraseña y/o permisos de un usuario
  static Future<Map<String, dynamic>> editarUsuario({
    required String token,
    required int usuarioId,
    String? nombreCompleto,
    String? cedula,
    String? password,
    bool? puedeVerStock,
    bool? puedeRegistrarEntrada,
    bool? puedeRegistrarSalida,
    bool? puedeCrearProductos,
    bool? puedeEliminarFacturas,
    bool? puedeVerFacturas,
    String? cargo,
    int? seccionId,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/$usuarioId');

    final Map<String, dynamic> body = {};
    if (nombreCompleto != null) body['nombre_completo'] = nombreCompleto;
    if (cedula != null) body['cedula'] = cedula;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (puedeVerStock != null) body['puede_ver_stock'] = puedeVerStock;
    if (puedeRegistrarEntrada != null) body['puede_registrar_entrada'] = puedeRegistrarEntrada;
    if (puedeRegistrarSalida != null) body['puede_registrar_salida'] = puedeRegistrarSalida;
    if (puedeCrearProductos != null) body['puede_crear_productos'] = puedeCrearProductos;
    if (puedeEliminarFacturas != null) body['puede_eliminar_facturas'] = puedeEliminarFacturas;
    if (puedeVerFacturas != null) body['puede_ver_facturas'] = puedeVerFacturas;
    if (cargo != null) body['cargo'] = cargo;
    if (seccionId != null) body['seccion_id'] = seccionId;

    final respuesta = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al editar el usuario');
    }
  }
// Trae el historial de movimientos de un producto
 static Future<List<dynamic>> getHistorial(String token, int productoId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/movimientos/historial/$productoId');

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudo cargar el historial');
    }
  }

  // Trae el historial de movimientos hechos POR un usuario (su actividad)
  static Future<List<dynamic>> getHistorialUsuario(String token, int usuarioId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/movimientos/historial-usuario/$usuarioId');

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudo cargar el historial del usuario');
    }
  }
// Sube la foto de un producto (sin comprimir, calidad completa)
  static Future<Map<String, dynamic>> subirFotoProducto(
    String token,
    int productoId,
    Uint8List bytes,
    String nombreArchivo,
  ) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/$productoId/foto');

    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'archivo',
        bytes,
        filename: nombreArchivo,
        contentType: _tipoDeImagen(nombreArchivo),
      ));

    final streamedResponse = await request.send();
    final respuesta = await http.Response.fromStream(streamedResponse);

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al subir la foto');
    }
  }// Sube la foto de perfil de un usuario
  static Future<Map<String, dynamic>> subirFotoUsuario(
    String token,
    int usuarioId,
    Uint8List bytes,
    String nombreArchivo,
  ) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/$usuarioId/foto');

    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'archivo',
        bytes,
        filename: nombreArchivo,
        contentType: _tipoDeImagen(nombreArchivo),
      ));

    final streamedResponse = await request.send();
    final respuesta = await http.Response.fromStream(streamedResponse);

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al subir la foto');
    }
  }// Verifica si un token guardado sigue siendo válido (para no pedir login de nuevo)
  static Future<Map<String, dynamic>> obtenerPerfil(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/yo');
    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('Sesión expirada');
    }
  }

  // Edita los datos de un producto (el stock actual no se toca aquí)
  static Future<Map<String, dynamic>> editarProducto({
    required String token,
    required int productoId,
    String? codigoBarras,
    String? nombre,
    String? categoria,
    int? stockMinimo,
    String? unidadMedida,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/$productoId');

    final Map<String, dynamic> body = {};
    if (codigoBarras != null) body['codigo_barras'] = codigoBarras;
    if (nombre != null) body['nombre'] = nombre;
    if (categoria != null) body['categoria'] = categoria;
    if (stockMinimo != null) body['stock_minimo'] = stockMinimo;
    if (unidadMedida != null) body['unidad_medida'] = unidadMedida;

    final respuesta = await http.patch(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al editar el producto');
    }
  }

 // Elimina (desactiva) un producto
  static Future<void> eliminarProducto(String token, int productoId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/$productoId');
    final respuesta = await http.delete(url, headers: {'Authorization': 'Bearer $token'});

    if (respuesta.statusCode != 200) {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al eliminar el producto');
    }
  }// Descarga el inventario como archivo Excel
  static Future<Uint8List> exportarExcel(String token, {int? seccionId}) async {
    final params = <String, String>{};
    if (seccionId != null) params['seccion_id'] = '$seccionId';
    final url = Uri.parse('${AppConfig.baseUrl}/productos/exportar-excel')
        .replace(queryParameters: params.isEmpty ? null : params);

    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (respuesta.statusCode == 200) {
      return respuesta.bodyBytes;
    } else {
      throw Exception('No se pudo exportar el inventario');
    }
  }
// Transfiere un producto de una sección a otra
  static Future<Map<String, dynamic>> transferirProducto({
    required String token,
    required String codigoBarras,
    required int seccionDestinoId,
    required int cantidad,
    String? motivo,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/movimientos/transferir');

    final respuesta = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'codigo_barras': codigoBarras,
        'seccion_destino_id': seccionDestinoId,
        'cantidad': cantidad,
        'motivo': motivo ?? '',
      }),
    );
    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al transferir el producto');
    }
  }
// Asigna las secciones (y categorías dentro de cada una) que un usuario puede ver
  static Future<Map<String, dynamic>> asignarSecciones({
    required String token,
    required int usuarioId,
    required List<Map<String, dynamic>> secciones,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/$usuarioId/secciones');

    final respuesta = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'secciones': secciones}),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al asignar las secciones');
    }
  }

  // Averigua cuántas facturas/movimientos tiene un usuario, antes de eliminarlo
  static Future<Map<String, dynamic>> verImpactoEliminarUsuario(String token, int usuarioId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/$usuarioId/impacto-eliminar');
    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'No se pudo calcular el impacto');
    }
  }

  // Elimina un usuario definitivamente. modo: "conservar" o "borrar_todo"
  static Future<void> eliminarUsuario({
    required String token,
    required int usuarioId,
    required String password,
    required String modo,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/usuarios/$usuarioId');
    final respuesta = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'password': password, 'modo': modo}),
    );

    if (respuesta.statusCode != 200) {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al eliminar el usuario');
    }
  }
// Crea un proveedor nuevo rápido (usado desde la pantalla de facturas)
  static Future<Map<String, dynamic>> crearProveedor({
    required String token,
    required String nombre,
    String? contacto,
    String? telefono,
    String? email,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/proveedores/');

    final respuesta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'nombre': nombre,
        'contacto': contacto,
        'telefono': telefono,
        'email': email,
      }),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al crear el proveedor');
    }
  }

  static double? _tasaCacheada;
  static DateTime? _tasaCacheadaHora;

  // Trae el valor del dólar en pesos colombianos (cacheado 30 min en la app)
  static Future<double> getTasaCambio(String token) async {
    if (_tasaCacheada != null &&
        _tasaCacheadaHora != null &&
        DateTime.now().difference(_tasaCacheadaHora!) < const Duration(minutes: 30)) {
      return _tasaCacheada!;
    }
    final url = Uri.parse('${AppConfig.baseUrl}/facturas/tasa-cambio');
    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (respuesta.statusCode == 200) {
      final data = jsonDecode(respuesta.body);
      _tasaCacheada = (data['usd_a_cop'] as num).toDouble();
      _tasaCacheadaHora = DateTime.now();
      return _tasaCacheada!;
    } else {
      throw Exception('No se pudo obtener la tasa de cambio');
    }
  }
// Averigua qué va a pasar si se elimina una factura (para mostrar el aviso antes de confirmar)
  static Future<Map<String, dynamic>> verImpactoEliminarFactura(String token, int facturaId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas/$facturaId/impacto-eliminar');
    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'No se pudo calcular el impacto');
    }
  }

  // Elimina una factura (si estaba confirmada, descuenta del stock lo que quedaba)
  static Future<void> eliminarFactura(String token, int facturaId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas/$facturaId');
    final respuesta = await http.delete(url, headers: {'Authorization': 'Bearer $token'});
    if (respuesta.statusCode != 200) {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al eliminar la factura');
    }
  }

  // Trae el resumen global: total facturado, consumido y lo que queda
  static Future<Map<String, dynamic>> getResumenFacturas(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas/resumen');
    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudo cargar el resumen de facturas');
    }
  }

  // Trae las facturas que ya se agotaron (historial temporal de 7 días)
  static Future<List<dynamic>> getFacturasAgotadas(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas/agotadas');
    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudieron cargar las facturas agotadas');
    }
  }

  // Trae las subcategorías (carpetas) de una sección, con su conteo
  static Future<List<dynamic>> getCategorias(String token, int seccionId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/categorias')
        .replace(queryParameters: {'seccion_id': '$seccionId'});
    final respuesta = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudieron cargar las categorías');
    }
  }

  // Trae la lista de proveedores
  static Future<List<dynamic>> getProveedores(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/proveedores/');

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudieron cargar los proveedores');
    }
  }

  // Crea una factura nueva en estado borrador
  static Future<Map<String, dynamic>> crearFactura({
    required String token,
    required String numeroFactura,
    required int proveedorId,
    int? seccionId,
    required String fechaFactura,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas');

    final respuesta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'numero_factura': numeroFactura,
        'proveedor_id': proveedorId,
        'seccion_id': seccionId,
        'fecha_factura': fechaFactura,
      }),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al crear la factura');
    }
  }

  // Agrega un producto (con cantidad y precio de esa compra) a una factura en borrador
  static Future<Map<String, dynamic>> agregarDetalleFactura({
    required String token,
    required int facturaId,
    required int productoId,
    required int cantidad,
    required double precioUnitario,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas/$facturaId/detalles');

    final respuesta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'producto_id': productoId,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
      }),
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al agregar el producto a la factura');
    }
  }

  // Quita un producto de una factura en borrador
  static Future<void> eliminarDetalleFactura({
    required String token,
    required int facturaId,
    required int detalleId,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas/$facturaId/detalles/$detalleId');

    final respuesta = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode != 200) {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al quitar el producto de la factura');
    }
  }

  // Confirma la factura: mueve el stock de todos los productos agregados
  static Future<Map<String, dynamic>> confirmarFactura({
    required String token,
    required int facturaId,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas/$facturaId/confirmar');

    final respuesta = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      final error = jsonDecode(respuesta.body);
      throw Exception(error['detail'] ?? 'Error al confirmar la factura');
    }
  }

  // Trae la lista de facturas (filtradas por sección si el usuario no es super admin)
  static Future<List<dynamic>> getFacturas(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas');

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudieron cargar las facturas');
    }
  }

  // Trae el detalle completo de una factura (encabezado + productos agregados)
  static Future<Map<String, dynamic>> getFactura(String token, int facturaId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/facturas/$facturaId');

    final respuesta = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    } else {
      throw Exception('No se pudo cargar el detalle de la factura');
    }
  }
}