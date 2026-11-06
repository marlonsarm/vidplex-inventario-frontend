import 'package:flutter/material.dart';
import '../services/excel_download_web.dart' if (dart.library.io) '../services/excel_download_stub.dart';
import '../services/api_service.dart';
import '../theme.dart';

const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Igual al formato de la pantalla de facturas: $1.234.567
String _formatoCOP(num valor) {
  final entero = valor.round();
  final texto = entero.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < texto.length; i++) {
    if (i != 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return '${entero < 0 ? '-' : ''}\$$buffer';
}

DateTime _soloDia(DateTime f) => DateTime(f.year, f.month, f.day);
DateTime _inicioMes(DateTime f) => DateTime(f.year, f.month, 1);
DateTime _finMes(DateTime f) => DateTime(f.year, f.month + 1, 0);

String _fechaLarga(DateTime f) => '${_dias[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]} de ${f.year}';

String _mesLargo(DateTime f) {
  final mes = _meses[f.month - 1];
  return '${mes[0].toUpperCase()}${mes.substring(1)} de ${f.year}';
}

String _fechaApi(DateTime f) =>
    '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

/// El backend manda la hora de Colombia sin zona (ej. "2026-10-05T14:30:00"),
/// así que se muestra tal cual, sin convertir.
DateTime? _leerFecha(String? iso) {
  if (iso == null) return null;
  try {
    return DateTime.parse(iso);
  } catch (e) {
    return null;
  }
}

String _hora(DateTime? f) {
  if (f == null) return '';
  final h12 = f.hour % 12 == 0 ? 12 : f.hour % 12;
  final ampm = f.hour < 12 ? 'a. m.' : 'p. m.';
  return '$h12:${f.minute.toString().padLeft(2, '0')} $ampm';
}

double _valor(dynamic v) => v == null ? 0 : (v as num).toDouble();

enum _Periodo { dia, mes }

class HistorialGeneralScreen extends StatefulWidget {
  final String token;
  const HistorialGeneralScreen({super.key, required this.token});

  @override
  State<HistorialGeneralScreen> createState() => _HistorialGeneralScreenState();
}

class _HistorialGeneralScreenState extends State<HistorialGeneralScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  _Periodo _periodo = _Periodo.dia;
  DateTime _fecha = _soloDia(DateTime.now());
  List<dynamic> _movimientos = [];
  bool _cargando = true;
  bool _descargando = false;
  String? _error;
  String? _consultaCargada;

  String get _tipo => _tabs.index == 0 ? 'entrada' : 'salida';
  bool get _esMes => _periodo == _Periodo.mes;
  DateTime get _hoy => _soloDia(DateTime.now());

  /// Rango que se está viendo: el día elegido, o el mes completo (hasta hoy si es el mes actual).
  DateTime get _desde => _esMes ? _inicioMes(_fecha) : _fecha;
  DateTime get _hasta {
    if (!_esMes) return _fecha;
    final fin = _finMes(_fecha);
    return fin.isAfter(_hoy) ? _hoy : fin;
  }

  bool get _esActual => _esMes ? _inicioMes(_fecha) == _inicioMes(_hoy) : _fecha == _hoy;

  String get _claveConsulta => '$_tipo|${_fechaApi(_desde)}|${_fechaApi(_hasta)}';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      if (_consultaCargada != _claveConsulta) _cargar();
    });
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final clave = _claveConsulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await ApiService.getMovimientosPeriodo(
        widget.token,
        desde: _fechaApi(_desde),
        hasta: _fechaApi(_hasta),
        tipo: _tipo,
      );
      if (!mounted || clave != _claveConsulta) return;
      setState(() {
        _movimientos = datos;
        _consultaCargada = clave;
      });
    } catch (e) {
      if (!mounted || clave != _claveConsulta) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      // Si mientras cargaba se cambió de día/mes, la carga nueva se encarga.
      if (mounted && clave == _claveConsulta) setState(() => _cargando = false);
    }
  }

  void _cambiarPeriodo(_Periodo periodo) {
    if (periodo == _periodo) return;
    setState(() => _periodo = periodo);
    _cargar();
  }

  void _mover(int pasos) {
    final DateTime nueva;
    if (_esMes) {
      nueva = DateTime(_fecha.year, _fecha.month + pasos, 1);
      if (nueva.isAfter(_hoy)) return;
    } else {
      nueva = _soloDia(_fecha.add(Duration(days: pasos)));
      if (nueva.isAfter(_hoy)) return;
    }
    setState(() => _fecha = nueva);
    _cargar();
  }

  void _irAHoy() {
    setState(() => _fecha = _hoy);
    _cargar();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha.isAfter(_hoy) ? _hoy : _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: _esMes ? 'Elige cualquier día del mes' : 'Elige el día',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (elegida != null) {
      setState(() => _fecha = _soloDia(elegida));
      _cargar();
    }
  }

  Future<void> _descargarExcel() async {
    setState(() => _descargando = true);
    try {
      final desde = _fechaApi(_desde);
      final hasta = _fechaApi(_hasta);
      final bytes = await ApiService.exportarMovimientosExcel(widget.token, desde: desde, hasta: hasta);
      final nombre = _esMes
          ? 'movimientos_${_meses[_fecha.month - 1]}_${_fecha.year}.xlsx'
          : 'movimientos_$desde.xlsx';
      await descargarExcelWeb(bytes, nombre);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.rojoAlerta,
        ),
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  Widget _selectorPeriodo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_Periodo>(
          segments: const [
            ButtonSegment(value: _Periodo.dia, label: Text('Por día'), icon: Icon(Icons.today_outlined)),
            ButtonSegment(value: _Periodo.mes, label: Text('Mes completo'), icon: Icon(Icons.calendar_month_outlined)),
          ],
          selected: {_periodo},
          showSelectedIcon: false,
          onSelectionChanged: (seleccion) => _cambiarPeriodo(seleccion.first),
        ),
      ),
    );
  }

  Widget _selectorFecha() {
    final texto = _esMes ? _mesLargo(_fecha) : _fechaLarga(_fecha);
    final etiquetaActual = _esMes ? 'ESTE MES' : 'HOY';
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
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
            tooltip: _esMes ? 'Mes anterior' : 'Día anterior',
            onPressed: () => _mover(-1),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _elegirFecha,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (_esActual)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.acento,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(etiquetaActual, style: AppTextStyles.etiqueta(size: 10, color: Colors.white)),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_esMes ? Icons.calendar_month_outlined : Icons.event_outlined,
                            size: 16, color: AppColors.acento),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            texto,
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
          if (!_esActual)
            TextButton(
              onPressed: _irAHoy,
              child: Text(_esMes ? 'Este mes' : 'Hoy'),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: _esMes ? 'Mes siguiente' : 'Día siguiente',
            onPressed: _esActual ? null : () => _mover(1),
          ),
        ],
      ),
    );
  }

  Widget _resumen() {
    final unidades = _movimientos.fold<int>(0, (s, m) => s + (m['cantidad'] as int));
    final valor = _movimientos.fold<double>(0, (s, m) => s + _valor(m['valor_total']));
    final esEntrada = _tipo == 'entrada';
    final color = esEntrada ? AppColors.verdeOk : AppColors.rojoAlerta;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_movimientos.length} ${esEntrada ? 'ingresos' : 'retiros'} · $unidades unidades',
              style: AppTextStyles.subtitulo(size: 12.5, color: AppColors.blanco),
            ),
          ),
          if (valor > 0)
            Text(
              _formatoCOP(valor),
              style: AppTextStyles.cuerpo(size: 14, peso: FontWeight.w800, color: color),
            ),
        ],
      ),
    );
  }

  Widget _encabezadoDia(DateTime dia, List<dynamic> delDia) {
    final unidades = delDia.fold<int>(0, (s, m) => s + (m['cantidad'] as int));
    final valor = delDia.fold<double>(0, (s, m) => s + _valor(m['valor_total']));
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _fechaLarga(dia),
              style: AppTextStyles.cuerpo(size: 12.5, peso: FontWeight.w700, color: AppColors.acento),
            ),
          ),
          Text(
            '$unidades u.${valor > 0 ? ' · ${_formatoCOP(valor)}' : ''}',
            style: AppTextStyles.subtitulo(size: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Map mov) {
    final esEntrada = mov['tipo'] == 'entrada';
    final color = esEntrada ? AppColors.verdeOk : AppColors.rojoAlerta;
    final factura = mov['factura_numero']?.toString();
    final proveedor = mov['proveedor_nombre']?.toString();
    final motivo = mov['motivo']?.toString() ?? '';
    final seccion = mov['seccion_nombre']?.toString() ?? '';
    final valorTotal = mov['valor_total'];
    final esTransferencia = mov['es_transferencia'] == true;

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
                if (seccion.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    esTransferencia ? '$seccion · transferencia' : seccion,
                    style: AppTextStyles.subtitulo(size: 11.5, color: AppColors.acento),
                  ),
                ],
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
              Text(_hora(_leerFecha(mov['fecha']?.toString())), style: AppTextStyles.cuerpo(size: 12, peso: FontWeight.w600)),
              if (valorTotal != null) ...[
                const SizedBox(height: 3),
                Text(_formatoCOP(_valor(valorTotal)), style: AppTextStyles.cuerpo(size: 12, peso: FontWeight.w700)),
              ],
              const SizedBox(height: 3),
              Text('Stock: ${mov['stock_resultante']}', style: AppTextStyles.subtitulo(size: 11, color: AppColors.gris)),
            ],
          ),
        ],
      ),
    );
  }

  /// En "Mes completo" la lista va agrupada por día, con el total de cada día.
  List<Widget> _filasLista() {
    if (!_esMes) {
      return _movimientos.map<Widget>((m) => _tarjeta(m as Map)).toList();
    }
    final grupos = <DateTime, List<dynamic>>{};
    for (final m in _movimientos) {
      final f = _leerFecha(m['fecha']?.toString());
      final dia = f == null ? _desde : _soloDia(f);
      grupos.putIfAbsent(dia, () => []).add(m);
    }
    final dias = grupos.keys.toList()..sort((a, b) => b.compareTo(a));
    final filas = <Widget>[];
    for (final dia in dias) {
      filas.add(_encabezadoDia(dia, grupos[dia]!));
      filas.addAll(grupos[dia]!.map<Widget>((m) => _tarjeta(m as Map)));
    }
    return filas;
  }

  @override
  Widget build(BuildContext context) {
    final esEntrada = _tipo == 'entrada';
    final vacio = esEntrada
        ? (_esMes ? 'No hubo ingresos este mes' : 'No hubo ingresos este día')
        : (_esMes ? 'No hubo retiros este mes' : 'No hubo retiros este día');

    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(
        title: Text('Historial', style: AppTextStyles.titulo(size: 18)),
        actions: [
          IconButton(
            tooltip: _esMes ? 'Descargar Excel del mes' : 'Descargar Excel del día',
            onPressed: _descargando ? null : _descargarExcel,
            icon: _descargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.acento),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ],
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
          _selectorPeriodo(),
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
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.cuerpo(color: AppColors.rojoAlerta),
                              ),
                            ),
                          ],
                        )
                      : _movimientos.isEmpty
                          ? ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 80),
                                  child: Center(
                                    child: Text(vacio, style: AppTextStyles.cuerpo(color: AppColors.gris)),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                              children: _filasLista(),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
