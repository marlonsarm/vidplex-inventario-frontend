ruta = "lib/screens/dashboard_screen.dart"

with open(ruta, "r", encoding="utf-8") as f:
    contenido = f.read()

ancla = "body: RefreshIndicator("
idx = contenido.find(ancla)
if idx == -1:
    raise SystemExit("No se encontro el ancla - no se aplico ningun cambio.")

antes = contenido[:idx]

nuevo_body = """body: Column(
        children: [
          RepaintBoundary(child: _bannerBienvenida()),
          if (_categoriaSeleccionada != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: InkWell(
                onTap: _volverACarpetas,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.acento),
                    const SizedBox(width: 6),
                    Text(
                      _categoriaSeleccionada == '__sin_categoria__' ? 'Sin categor\u00eda' : _categoriaSeleccionada!,
                      style: AppTextStyles.cuerpo(size: 13, peso: FontWeight.w700, color: AppColors.acento),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.md, 12),
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
                  tooltip: _vistaLista ? 'Ver en cuadr\u00edcula' : 'Ver en lista',
                  onPressed: () => setState(() => _vistaLista = !_vistaLista),
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.acento,
              backgroundColor: AppColors.negro2,
              onRefresh: _cargarProductos,
              child: Scrollbar(
                controller: _scrollController,
                child: CustomScrollView(
                  controller: _scrollController,
                  cacheExtent: 300,
                  slivers: [
                    ..._sliversDeContenido(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
"""

contenido_nuevo = antes + nuevo_body

with open(ruta, "w", encoding="utf-8") as f:
    f.write(contenido_nuevo)

print("Cambio aplicado correctamente.")
