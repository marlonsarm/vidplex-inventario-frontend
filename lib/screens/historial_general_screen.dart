import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

DateTime _soloDia(DateTime f) => DateTime(f.year, f.month, f.day);

String _fechaLarga(DateTime f) => '${_dias[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]} de ${f.year}';

String _fechaApi(DateTime f) =>
    '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

String _hora(String? iso) {
  if (iso == null) return '';
  try {
    final f = DateTime.parse(iso);
    final h12 = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final ampm = f.hour < 12 ? 'a. m.' : 'p. m.';
    return '$h12:${f.minute.toString().padLeft(2, '0')} $ampm';
  } catch (e) {
    return '';
  }
}

class HistorialGeneralScreen extends StatefulWidget {
  final String token;
  const HistorialGeneralScreen({super.key, required this.token});

  @override
  State<HistorialGeneralScreen> createState() => _HistorialGeneralScreenState();
}

class _HistorialGeneralScreenState extends State<HistorialGeneralScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  DateTime _fecha = _soloDia(DateTime.now());
  List<dynamic> _movimientos = [];
  bool _cargando = true;
  String? _error;
  String? _tipoCargado;

  String get _tipo => _tabs.index == 0 ? 'entrada' : 'salida';
  bool get _esHoy => _fecha == _soloDia(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      if (_tipoCargado != _tipo) _cargar();
    });
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final tipo = _tipo;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await ApiService.getHistorialGeneral(widget.token, _fechaApi(_fecha), tipo);
      if (!mounted) return;
      setState(() {
        _movimientos = datos;
        _tipoCargado = tipo;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarDia(int dias) {
    final nueva = _fecha.add(Duration(days: dias));
    if (nueva.isAfter(_soloDia(DateTime.now()))) return;
    setState(() => _fecha = _soloDia(nueva));
    _cargar();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Elige el día',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (elegida != null) {
      setState(() => _fecha = _soloDia(elegida));
      _cargar();
    }
  }

  Widget _selectorFecha() {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.grisLinea),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Día anterior',
            onPressed: () => _cambiarDia(-1),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _elegirFecha,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (_esHoy)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.acento,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('HOY', style: AppTextStyles.etiqueta(size: 10, color: Colors.white)),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_outlined, size: 16, color: AppColors.acento),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _fechaLarga(_fecha),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.cuerpo(size: 13.5, peso: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_esHoy)
            TextButton(
              onPressed: () {
                setState(() => _fecha = _soloDia(DateTime.now()));
                _cargar();
              },
              child: const Text('Hoy'),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Día siguiente',
            onPressed: _esHoy ? null : () => _cambiarDia(1),
          ),
        ],
      ),
    );
  }

  Widget _resumen() {
    final unidades = _movimientos.fold<int>(0, (s, m) => s + (m['cantidad'] as int));
    final esEntrada = _tipo == 'entrada';
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${_movimientos.length} ${esEntrada ? 'ingresos' : 'retiros'} · $unidades unidades',
          style: AppTextStyles.subtitulo(size: 12, color: AppColors.gris),
        ),
      ),
    );
  }

  Widget _tarjeta(Map mov) {
    final esEntrada = mov['tipo'] == 'entrada';
    final color = esEntrada ? AppColors.verdeOk : AppColors.rojoAlerta;
    final factura = mov['factura_numero']?.toString();
    final proveedor = mov['proveedor_nombre']?.toString();
    final motivo = mov['motivo']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.negro2,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.grisLinea),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${esEntrada ? '+' : '-'}${mov['cantidad']}',
              style: AppTextStyles.cuerpo(size: 15, peso: FontWeight.w800, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mov['producto_nombre']?.toString() ?? 'Producto',
                  style: AppTextStyles.cuerpo(size: 13.5, peso: FontWeight.w700),
                ),
                if (factura != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Factura $factura${proveedor != null ? ' · $proveedor' : ''}',
                    style: AppTextStyles.subtitulo(size: 12),
                  ),
                ] else if (motivo.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    motivo,
                    style: AppTextStyles.subtitulo(size: 12).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 3),
                Text('Por: ${mov['usuario_nombre']}', style: AppTextStyles.subtitulo(size: 11.5, color: AppColors.gris)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_hora(mov['fecha']?.toString()), style: AppTextStyles.cuerpo(size: 12, peso: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Stock: ${mov['stock_resultante']}', style: AppTextStyles.subtitulo(size: 11, color: AppColors.gris)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEntrada = _tipo == 'entrada';
    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(
        title: Text('Historial', style: AppTextStyles.titulo(size: 18)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.acento,
          labelColor: AppColors.acento,
          unselectedLabelColor: AppColors.gris,
          tabs: const [Tab(text: 'Ingresos'), Tab(text: 'Retiros')],
        ),
      ),
      body: Column(
        children: [
          _selectorFecha(),
          if (!_cargando && _error == null) _resumen(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.acento,
              backgroundColor: AppColors.negro2,
              onRefresh: _cargar,
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: AppColors.acento))
                  : _error != null
                      ? Center(child: Text(_error!, style: AppTextStyles.cuerpo(color: AppColors.rojoAlerta)))
                      : _movimientos.isEmpty
                          ? ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 80),
                                  child: Center(
                                    child: Text(
                                      esEntrada ? 'No hubo ingresos este día' : 'No hubo retiros este día',
                                      style: AppTextStyles.cuerpo(color: AppColors.gris),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                              itemCount: _movimientos.length,
                              itemBuilder: (context, index) => _tarjeta(_movimientos[index]),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}