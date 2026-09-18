ruta2 = "lib/screens/crear_producto_screen.dart"
with open(ruta2, "r", encoding="utf-8") as f:
    c2 = f.read()

viejo2d = """  @override
  void dispose() {
    _debounce?.cancel();
    _codigoController.dispose();
    _nombreController.dispose();
    _categoriaController.dispose();
    _stockActualController.dispose();
    _stockMinimoController.dispose();
    _unidadController.dispose();
    super.dispose();
  }"""
nuevo2d = """  @override
  void dispose() {
    _debounce?.cancel();
    _codigoController.dispose();
    _nombreController.dispose();
    _categoriaController.dispose();
    _stockActualController.dispose();
    _stockMinimoController.dispose();
    _unidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }"""
assert c2.count(viejo2d) == 1, f"2d: aparecio {c2.count(viejo2d)} veces"
c2 = c2.replace(viejo2d, nuevo2d, 1)

with open(ruta2, "w", encoding="utf-8") as f:
    f.write(c2)
print("Paso 2d aplicado.")
