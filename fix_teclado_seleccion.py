ruta = "lib/screens/dashboard_screen.dart"
with open(ruta, "r", encoding="utf-8") as f:
    c = f.read()

viejo1 = """import 'dart:async';
import '../services/excel_download_web.dart' if (dart.library.io) '../services/excel_download_stub.dart';
import 'package:flutter/material.dart';"""
nuevo1 = """import 'dart:async';
import '../services/excel_download_web.dart' if (dart.library.io) '../services/excel_download_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';"""
assert c.count(viejo1) == 1, f"1: aparecio {c.count(viejo1)} veces"
c = c.replace(viejo1, nuevo1, 1)

viejo2 = """  bool _vistaLista = false;
  bool _busquedaAbierta = false;"""
nuevo2 = """  bool _vistaLista = false;
  bool _busquedaAbierta = false;
  int _indiceSeleccionado = -1;
  final FocusNode _teclasFocusNode = FocusNode();"""
assert c.count(viejo2) == 1, f"2: aparecio {c.count(viejo2)} veces"
c = c.replace(viejo2, nuevo2, 1)

viejo3 = """  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _cargarMasProductos();
    }
  }"""
nuevo3 = viejo3 + """

  void _manejarTeclado(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_productos.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _indiceSeleccionado = (_indiceSeleccionado + 1).clamp(0, _productos.length - 1);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _indiceSeleccionado = (_indiceSeleccionado - 1).clamp(0, _productos.length - 1);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_indiceSeleccionado >= 0 && _indiceSeleccionado < _productos.length) {
        _abrirProducto(_productos[_indiceSeleccionado]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _indiceSeleccionado = -1);
    }
  }

  Future<void> _abrirProducto(dynamic producto) async {
    final actualizado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerProductoScreen(
          token: widget.token,
          producto: producto,
          puedeEditar: widget.esSuperAdmin || widget.puedeCrearProductos,
          puedeRegistrarEntrada: widget.esSuperAdmin || widget.puedeRegistrarEntrada,
          puedeRegistrarSalida: widget.esSuperAdmin || widget.puedeRegistrarSalida,
        ),
      ),
    );
    if (actualizado == true) _cargarProductos();
  }"""
assert c.count(viejo3) == 1, f"3: aparecio {c.count(viejo3)} veces"
c = c.replace(viejo3, nuevo3, 1)

viejo4 = """  @override
  void dispose() {
    _busquedaController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }"""
nuevo4 = """  @override
  void dispose() {
    _busquedaController.dispose();
    _scrollController.dispose();
    _teclasFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }"""
assert c.count(viejo4) == 1, f"4: aparecio {c.count(viejo4)} veces"
c = c.replace(viejo4, nuevo4, 1)

viejo5 = """                final producto = _productos[index];
                final bool stockBajo = producto['stock_actual'] <= producto['stock_minimo'];
                return InkWell(
                  onTap: () async {
                    final actualizado = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VerProductoScreen(
                          token: widget.token,
                          producto: producto,
                          puedeEditar: widget.esSuperAdmin || widget.puedeCrearProductos,
                          puedeRegistrarEntrada: widget.esSuperAdmin || widget.puedeRegistrarEntrada,
                          puedeRegistrarSalida: widget.esSuperAdmin || widget.puedeRegistrarSalida,
                        ),
                      ),
                    );
                    if (actualizado == true) _cargarProductos();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.negro2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: stockBajo ? AppColors.ambarBajo.withValues(alpha: 0.5) : AppColors.grisLinea,
                      ),
                    ),"""
nuevo5 = """                final producto = _productos[index];
                final bool stockBajo = producto['stock_actual'] <= producto['stock_minimo'];
                final bool seleccionado = index == _indiceSeleccionado;
                return InkWell(
                  onTap: () {
                    setState(() => _indiceSeleccionado = index);
                    _abrirProducto(producto);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: seleccionado ? AppColors.acento.withValues(alpha: 0.14) : AppColors.negro2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: seleccionado
                            ? AppColors.acento
                            : (stockBajo ? AppColors.ambarBajo.withValues(alpha: 0.5) : AppColors.grisLinea),
                        width: seleccionado ? 2 : 1,
                      ),
                    ),"""
assert c.count(viejo5) == 1, f"5: aparecio {c.count(viejo5)} veces"
c = c.replace(viejo5, nuevo5, 1)

viejo6a = """   body: Column(
        children: [
          RepaintBoundary(child: _bannerBienvenida()),"""
nuevo6a = """   body: KeyboardListener(
        focusNode: _teclasFocusNode,
        autofocus: true,
        onKeyEvent: _manejarTeclado,
        child: Column(
        children: [
          RepaintBoundary(child: _bannerBienvenida()),"""
assert c.count(viejo6a) == 1, f"6a: aparecio {c.count(viejo6a)} veces"
c = c.replace(viejo6a, nuevo6a, 1)

viejo6b = """                    ..._sliversDeContenido(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}"""
nuevo6b = """                    ..._sliversDeContenido(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}"""
assert c.count(viejo6b) == 1, f"6b: aparecio {c.count(viejo6b)} veces"
c = c.replace(viejo6b, nuevo6b, 1)

with open(ruta, "w", encoding="utf-8") as f:
    f.write(c)
print("Los 6 cambios se aplicaron correctamente.")
