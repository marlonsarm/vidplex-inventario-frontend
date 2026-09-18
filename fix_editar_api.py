ruta = "lib/services/api_service.dart"
with open(ruta, "r", encoding="utf-8") as f:
    c = f.read()

viejo = """  static Future<Map<String, dynamic>> editarProducto({
    required String token,
    required int productoId,
    String? codigoBarras,
    String? nombre,
    String? categoria,
    String? responsable,
    String? ubicacion,
    int? seccionId,
    int? stockMinimo,
    String? unidadMedida,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/$productoId');

    final Map<String, dynamic> body = {};
    if (codigoBarras != null) body['codigo_barras'] = codigoBarras;
    if (nombre != null) body['nombre'] = nombre;
    if (categoria != null) body['categoria'] = categoria;
    if (responsable != null) body['responsable'] = responsable;
    if (ubicacion != null) body['ubicacion'] = ubicacion;
    if (seccionId != null) body['seccion_id'] = seccionId;
    if (stockMinimo != null) body['stock_minimo'] = stockMinimo;
    if (unidadMedida != null) body['unidad_medida'] = unidadMedida;"""

nuevo = """  static Future<Map<String, dynamic>> editarProducto({
    required String token,
    required int productoId,
    String? codigoBarras,
    String? nombre,
    String? categoria,
    String? responsable,
    String? ubicacion,
    int? seccionId,
    int? stockMinimo,
    String? unidadMedida,
    int? proveedorId,
    double? precioUnitario,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/productos/$productoId');

    final Map<String, dynamic> body = {};
    if (codigoBarras != null) body['codigo_barras'] = codigoBarras;
    if (nombre != null) body['nombre'] = nombre;
    if (categoria != null) body['categoria'] = categoria;
    if (responsable != null) body['responsable'] = responsable;
    if (ubicacion != null) body['ubicacion'] = ubicacion;
    if (seccionId != null) body['seccion_id'] = seccionId;
    if (stockMinimo != null) body['stock_minimo'] = stockMinimo;
    if (unidadMedida != null) body['unidad_medida'] = unidadMedida;
    if (proveedorId != null) body['proveedor_id'] = proveedorId;
    if (precioUnitario != null) body['precio_unitario'] = precioUnitario;"""

assert c.count(viejo) == 1, f"aparecio {c.count(viejo)} veces"
c = c.replace(viejo, nuevo, 1)

with open(ruta, "w", encoding="utf-8") as f:
    f.write(c)
print("api_service.dart (editarProducto): OK")
