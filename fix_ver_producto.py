ruta = "lib/screens/ver_producto_screen.dart"
with open(ruta, "r", encoding="utf-8") as f:
    c = f.read()

# Cambio A: agregar los metodos nuevos justo despues de _editarUbicacionRapido
viejoA = """  Future<void> _registrarMovimiento(String tipo) async {"""

nuevoA = """  Future<void> _editarPrecioRapido() async {
    final controller = TextEditingController(
      text: _producto['precio_unitario'] != null ? _formatearPrecio(_producto['precio_unitario']).replaceAll('\$', '').replaceAll('.', '') : '',
    );

    final nuevoPrecio = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Precio unitario'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Ej: 15000', border: OutlineInputBorder()),
          onSubmitted: (valor) => Navigator.of(context).pop(valor.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );

    if (nuevoPrecio == null || !context.mounted) return;
    final valorNumerico = double.tryParse(nuevoPrecio.replaceAll(',', '.'));
    if (valorNumerico == null) return;

    try {
      final actualizado = await ApiService.editarProducto(
        token: widget.token,
        productoId: _producto['id'],
        precioUnitario: valorNumerico,
      );
      if (!context.mounted) return;
      setState(() {
        _producto = {..._producto, 'precio_unitario': actualizado['precio_unitario']};
        _huboCambios = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precio actualizado'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<Map<String, dynamic>?> _crearProveedorRapido() async {
    final nombreCtrl = TextEditingController();
    final contactoCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo proveedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre *')),
            const SizedBox(height: 8),
            TextField(controller: contactoCtrl, decoration: const InputDecoration(labelText: 'Contacto')),
            const SizedBox(height: 8),
            TextField(controller: telefonoCtrl, decoration: const InputDecoration(labelText: 'Telefono')),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              try {
                final creado = await ApiService.crearProveedor(
                  token: widget.token,
                  nombre: nombreCtrl.text.trim(),
                  contacto: contactoCtrl.text.trim().isEmpty ? null : contactoCtrl.text.trim(),
                  telefono: telefonoCtrl.text.trim().isEmpty ? null : telefonoCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop(creado);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _editarProveedorRapido() async {
    List<dynamic> proveedores = [];
    try {
      proveedores = await ApiService.getProveedores(widget.token);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
      return;
    }
    if (!context.mounted) return;

    final busquedaCtrl = TextEditingController();
    final elegido = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtrados = busquedaCtrl.text.trim().isEmpty
                ? proveedores
                : proveedores.where((p) {
                    final nombre = (p['nombre'] ?? '').toString().toLowerCase();
                    return nombre.contains(busquedaCtrl.text.trim().toLowerCase());
                  }).toList();

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.negro2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Elegir proveedor', style: AppTextStyles.titulo(size: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.acento),
                        tooltip: 'Nuevo proveedor',
                        onPressed: () async {
                          final nuevo = await _crearProveedorRapido();
                          if (nuevo != null && context.mounted) Navigator.of(context).pop(nuevo);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: busquedaCtrl,
                    autofocus: true,
                    style: AppTextStyles.cuerpo(),
                    decoration: const InputDecoration(
                      hintText: 'Buscar proveedor...',
                      prefixIcon: Icon(Icons.search, color: AppColors.gris),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final p = filtrados[index];
                        return ListTile(
                          title: Text(p['nombre'].toString(), style: AppTextStyles.cuerpo(size: 13.5)),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (elegido == null || !context.mounted) return;

    try {
      final actualizado = await ApiService.editarProducto(
        token: widget.token,
        productoId: _producto['id'],
        proveedorId: elegido['id'] as int,
      );
      if (!context.mounted) return;
      setState(() {
        _producto = {..._producto, 'proveedor_id': actualizado['proveedor_id'], 'proveedor_nombre': actualizado['proveedor_nombre']};
        _huboCambios = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proveedor actualizado a "\${elegido['nombre']}"'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _registrarMovimiento(String tipo) async {"""

assert c.count(viejoA) == 1, f"A: aparecio {c.count(viejoA)} veces"
c = c.replace(viejoA, nuevoA, 1)

# Cambio B: reemplazar las 2 filas condicionales finales por filas siempre visibles y tocables
viejoB = """                if (_producto['precio_unitario'] != null) ...[
                  const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                  _filaDato(Icons.attach_money, 'Precio unitario', _formatearPrecio(_producto['precio_unitario'])),
                ],
                if ((_producto['proveedor_nombre'] ?? '').toString().isNotEmpty) ...[
                  const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                  _filaDato(Icons.local_shipping_outlined, 'Proveedor', _producto['proveedor_nombre']),
                ],"""

nuevoB = """                const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                InkWell(
                  onTap: _editarPrecioRapido,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: _filaDato(Icons.attach_money, 'Precio unitario', _producto['precio_unitario'] != null ? _formatearPrecio(_producto['precio_unitario']) : 'No definido')),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.gris),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.grisLinea, thickness: 1),
                InkWell(
                  onTap: _editarProveedorRapido,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: _filaDato(Icons.local_shipping_outlined, 'Proveedor', (_producto['proveedor_nombre'] ?? '').toString().isEmpty ? 'No definido' : _producto['proveedor_nombre'])),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.gris),
                      ],
                    ),
                  ),
                ),"""

assert c.count(viejoB) == 1, f"B: aparecio {c.count(viejoB)} veces"
c = c.replace(viejoB, nuevoB, 1)

with open(ruta, "w", encoding="utf-8") as f:
    f.write(c)
print("Cambios A y B aplicados correctamente.")
