ruta2 = "lib/screens/crear_producto_screen.dart"
with open(ruta2, "r", encoding="utf-8") as f:
    c2 = f.read()

viejo2f = """      final creado = await ApiService.crearProducto(
        token: widget.token,
        codigoBarras: _codigoController.text.trim().isEmpty ? null : _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        categoria: _categoriaController.text.trim(),
        seccionId: _seccionSeleccionada!,
        stockActual: int.parse(_stockActualController.text),
        stockMinimo: int.parse(_stockMinimoController.text),
        unidadMedida: _unidadController.text.trim().isEmpty ? 'unidad' : _unidadController.text.trim(),
      );"""
nuevo2f = """      final creado = await ApiService.crearProducto(
        token: widget.token,
        codigoBarras: _codigoController.text.trim().isEmpty ? null : _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        categoria: _categoriaController.text.trim(),
        seccionId: _seccionSeleccionada!,
        stockActual: int.parse(_stockActualController.text),
        stockMinimo: int.parse(_stockMinimoController.text),
        unidadMedida: _unidadController.text.trim().isEmpty ? 'unidad' : _unidadController.text.trim(),
        proveedorId: _proveedorSeleccionado?['id'] as int?,
        precioUnitario: double.tryParse(_precioController.text.trim().replaceAll(',', '.')),
      );"""
assert c2.count(viejo2f) == 1, f"2f: aparecio {c2.count(viejo2f)} veces"
c2 = c2.replace(viejo2f, nuevo2f, 1)

with open(ruta2, "w", encoding="utf-8") as f:
    f.write(c2)
print("Paso 2f aplicado. Todos los cambios completos.")
