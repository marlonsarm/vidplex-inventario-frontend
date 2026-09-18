ruta2 = "lib/screens/crear_producto_screen.dart"
with open(ruta2, "r", encoding="utf-8") as f:
    c2 = f.read()

viejo2a = """ int? _seccionSeleccionada;
  List<dynamic> _secciones = [];
  bool _cargandoSecciones = true;
  bool _guardando = false;"""
nuevo2a = """ int? _seccionSeleccionada;
  List<dynamic> _secciones = [];
  bool _cargandoSecciones = true;
  bool _guardando = false;

  Map<String, dynamic>? _proveedorSeleccionado;
  List<dynamic> _proveedores = [];
  final _precioController = TextEditingController();"""
assert c2.count(viejo2a) == 1, f"2a: aparecio {c2.count(viejo2a)} veces"
c2 = c2.replace(viejo2a, nuevo2a, 1)

with open(ruta2, "w", encoding="utf-8") as f:
    f.write(c2)
print("Paso 2a aplicado.")
