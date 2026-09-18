ruta2 = "lib/screens/crear_producto_screen.dart"
with open(ruta2, "r", encoding="utf-8") as f:
    c2 = f.read()

viejo2e = """                      onChanged: (valor) => setState(() => _seccionSeleccionada = valor),
                    ),
            ),
            _tituloSeccion(Icons.numbers_rounded, 'STOCK'),"""
nuevo2e = """                      onChanged: (valor) => setState(() => _seccionSeleccionada = valor),
                    ),
            ),
            _tituloSeccion(Icons.local_shipping_outlined, 'PRECIO Y PROVEEDOR'),
            _tarjeta(
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final elegido = await _elegirProveedor(_proveedores);
                      if (elegido != null) setState(() => _proveedorSeleccionado = elegido);
                    },
                    child: InputDecorator(
                      decoration: _decoracion('Proveedor (opcional)', icono: Icons.local_shipping_outlined),
                      child: Text(
                        _proveedorSeleccionado?['nombre'] ?? 'Sin proveedor',
                        style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _precioController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTextStyles.cuerpo(size: 14.5, peso: FontWeight.w700),
                    decoration: _decoracion('Precio unitario (opcional)', icono: Icons.attach_money),
                  ),
                ],
              ),
            ),
            _tituloSeccion(Icons.numbers_rounded, 'STOCK'),"""
assert c2.count(viejo2e) == 1, f"2e: aparecio {c2.count(viejo2e)} veces"
c2 = c2.replace(viejo2e, nuevo2e, 1)

with open(ruta2, "w", encoding="utf-8") as f:
    f.write(c2)
print("Paso 2e aplicado.")
