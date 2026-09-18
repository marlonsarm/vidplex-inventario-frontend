ruta2 = "lib/screens/crear_producto_screen.dart"
with open(ruta2, "r", encoding="utf-8") as f:
    c2 = f.read()

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

with open(ruta2, "w", encoding="utf-8") as f:
    f.write(c2)
print("Paso 2b aplicado.")
