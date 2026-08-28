import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config.dart';
import '../theme.dart';
import 'editar_usuario_screen.dart';

class ListaUsuariosScreen extends StatefulWidget {
  final String token;

  const ListaUsuariosScreen({super.key, required this.token});

  @override
  State<ListaUsuariosScreen> createState() => _ListaUsuariosScreenState();
}

class _ListaUsuariosScreenState extends State<ListaUsuariosScreen> {
  List<dynamic> _usuarios = [];
  List<dynamic> _pendientes = [];
  bool _cargando = true;
  String? _error;
  final _busquedaController = TextEditingController();
  String _textoBusqueda = '';

  List<dynamic> get _usuariosFiltrados {
    if (_textoBusqueda.trim().isEmpty) return _usuarios;
    final query = _textoBusqueda.trim().toLowerCase();
    return _usuarios.where((u) {
      final nombre = (u['nombre_completo'] ?? '').toString().toLowerCase();
      final correo = (u['email'] ?? '').toString().toLowerCase();
      return nombre.contains(query) || correo.contains(query);
    }).toList();
  }

  List<dynamic> get _pendientesFiltrados {
    if (_textoBusqueda.trim().isEmpty) return _pendientes;
    final query = _textoBusqueda.trim().toLowerCase();
    return _pendientes.where((u) {
      final nombre = (u['nombre_completo'] ?? '').toString().toLowerCase();
      final correo = (u['email'] ?? '').toString().toLowerCase();
      return nombre.contains(query) || correo.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final usuarios = await ApiService.getUsuarios(widget.token);
      List<dynamic> pendientes = [];
      try {
        pendientes = await ApiService.getUsuariosPendientes(widget.token);
      } catch (e) {
        // si falla traer pendientes, no bloquea el resto de la lista
      }
      setState(() {
        _usuarios = usuarios;
        _pendientes = pendientes;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarEstado(int usuarioId, bool nuevoEstado) async {
    try {
      await ApiService.cambiarEstadoUsuario(widget.token, usuarioId, nuevoEstado);
      _cargarUsuarios();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nuevoEstado ? 'Usuario activado' : 'Usuario desactivado'),
          backgroundColor: nuevoEstado ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  String _resumenPermisos(Map usuario) {
    if (usuario['es_super_admin'] == true) return 'Super Admin';
    final permisos = <String>[];
    if (usuario['puede_ver_stock'] == true) permisos.add('Ver');
    if (usuario['puede_registrar_entrada'] == true) permisos.add('Entrada');
    if (usuario['puede_registrar_salida'] == true) permisos.add('Salida');
    if (usuario['puede_crear_productos'] == true) permisos.add('Crear productos');
    return permisos.isEmpty ? 'Sin permisos' : permisos.join(' · ');
  }
Future<void> _verificarPendiente(Map pendiente) async {
    final passwordController = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verificar a ${pendiente['nombre_completo']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresa tu contraseña de administrador para confirmar.'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Verificar')),
        ],
      ),
    );

    if (confirmado != true) return;
    if (!mounted) return;

    try {
      await ApiService.verificarUsuarioPendiente(
        token: widget.token,
        pendienteId: pendiente['id'],
        password: passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario verificado correctamente'), backgroundColor: Colors.green),
      );
      _cargarUsuarios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Widget _tarjetaPendiente(Map usuario) {
    return Opacity(
      opacity: 0.6,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.hourglass_top, color: Colors.grey),
          ),
          title: Text(
            usuario['nombre_completo'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          subtitle: Text(usuario['email'] ?? ''),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pendiente',
                  style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline, color: AppColors.acento),
                tooltip: 'Verificar ahora',
                onPressed: () => _verificarPendiente(usuario),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _pendientesFiltrados;
    final usuarios = _usuariosFiltrados;

    return Scaffold(
      backgroundColor: AppColors.negro,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.negro,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.blanco,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, AppColors.acento, Colors.transparent]),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.acentoSuave, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.group_outlined, size: 17, color: AppColors.acento),
            ),
            const SizedBox(width: 10),
            Text('Usuarios', style: AppTextStyles.cuerpo(size: 16, peso: FontWeight.w800)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _busquedaController,
              style: AppTextStyles.cuerpo(),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o correo...',
                prefixIcon: const Icon(Icons.search, color: AppColors.gris),
                suffixIcon: _textoBusqueda.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.gris),
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() => _textoBusqueda = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.negro2,
              ),
              onChanged: (valor) => setState(() => _textoBusqueda = valor),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargarUsuarios,
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : (usuarios.isEmpty && pendientes.isEmpty)
                          ? Center(child: Text(_textoBusqueda.isEmpty ? 'No hay usuarios todavía' : 'Sin resultados para "$_textoBusqueda"'))
                          : ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                if (pendientes.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                                    child: Text(
                                      'Pendientes por verificar (${pendientes.length})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                  ),
                                  ...pendientes.map((p) => _tarjetaPendiente(p)),
                                  const SizedBox(height: 12),
                                ],
                                if (usuarios.isNotEmpty)
                                  ...usuarios.map((usuario) {
                                    final bool activo = usuario['activo'];
                                    final String? fotoUrl = usuario['foto_url'];

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.negro2,
                                        borderRadius: BorderRadius.circular(AppRadius.card),
                                        border: Border.all(color: AppColors.grisLinea),
                                      ),
                                      child: ListTile(
                                        onTap: () async {
                                          final actualizado = await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => EditarUsuarioScreen(token: widget.token, usuario: usuario),
                                            ),
                                          );
                                          if (actualizado == true) _cargarUsuarios();
                                        },
                                        leading: CircleAvatar(
                                          backgroundColor: activo ? Colors.green[100] : Colors.grey[300],
                                          backgroundImage: fotoUrl != null ? NetworkImage('${AppConfig.baseUrl}$fotoUrl') : null,
                                          child: fotoUrl != null
                                              ? null
                                              : Icon(
                                                  usuario['es_super_admin'] == true ? Icons.shield : Icons.person,
                                                  color: activo ? Colors.green[700] : Colors.grey,
                                                ),
                                        ),
                                        title: Text(
                                          usuario['nombre_completo'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: activo ? Colors.black87 : Colors.grey,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '@${usuario['usuario']}\n${_resumenPermisos(usuario)}',
                                        ),
                                        isThreeLine: true,
                                        trailing: Switch(
                                          value: activo,
                                          activeThumbColor: AppColors.verdeOk,
                                          onChanged: (nuevoValor) => _cambiarEstado(usuario['id'], nuevoValor),
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }
}