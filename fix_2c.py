ruta2 = "lib/screens/crear_producto_screen.dart"
with open(ruta2, "r", encoding="utf-8") as f:
    c2 = f.read()

viejo2c = """  Future<void> _cargarSecciones() async {
    try {
      final secciones = await ApiService.getSecciones(widget.token);
      setState(() {
        _secciones = secciones;
        if (secciones.isNotEmpty) _seccionSeleccionada = secciones[0]['id'];
      });
    } catch (e) {
      // si falla, se puede reintentar guardando el producto igual
   } finally {
      setState(() => _cargandoSecciones = false);
    }
  }"""

nuevo2c = viejo2c + """

  Future<void> _cargarProveedores() async {
    try {
      final proveedores = await ApiService.getProveedores(widget.token);
      if (mounted) setState(() => _proveedores = proveedores);
    } catch (e) {
      // si falla, el usuario puede seguir sin elegir proveedor
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
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.rojoAlerta),
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

  Future<Map<String, dynamic>?> _elegirProveedor(List<dynamic> proveedores) async {
    final busquedaCtrl = TextEditingController();

    return showModalBottomSheet<Map<String, dynamic>?>(
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
  }"""
assert c2.count(viejo2c) == 1, f"2c: aparecio {c2.count(viejo2c)} veces"
c2 = c2.replace(viejo2c, nuevo2c, 1)

with open(ruta2, "w", encoding="utf-8") as f:
    f.write(c2)
print("Paso 2c aplicado.")
