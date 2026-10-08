import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/producto_controller.dart';
import '../controllers/compra_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/usuario_model.dart';
import '../utils/app_theme.dart';
import 'widgets/role_badge.dart';
import 'widgets/app_drawer.dart';
import 'registro_view.dart';
import 'usuario_detalle_dialog.dart';
import 'cambiar_contrasena_dialog.dart';
import 'login_view.dart';
import 'productos_view.dart';
import 'lector_home_view.dart';

/// Vista Principal de Gestión y Listado de Usuarios (MVC)
class UsuariosListView extends StatefulWidget {
  final AuthController authController;
  final UsuarioController usuarioController;
  final ProductoController? productoController;
  final CompraController? compraController;
  final ThemeController? themeController;

  const UsuariosListView({
    super.key,
    required this.authController,
    required this.usuarioController,
    this.productoController,
    this.compraController,
    this.themeController,
  });

  @override
  State<UsuariosListView> createState() => _UsuariosListViewState();
}

class _UsuariosListViewState extends State<UsuariosListView> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isTableView = false; // Alternar entre vista de tarjetas y tabla

  @override
  void initState() {
    super.initState();
    // Cargar datos al iniciar
    widget.usuarioController.cargarUsuarios();
    widget.productoController?.setActiveUser(widget.authController.currentUser);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _abrirProductos() {
    final prodCtrl = widget.productoController ?? ProductoController();
    prodCtrl.setActiveUser(widget.authController.currentUser);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductosView(
          authController: widget.authController,
          productoController: prodCtrl,
          compraController: widget.compraController,
          themeController: widget.themeController,
        ),
      ),
    );
  }

  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Deseas salir de la sesión actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.productoController?.resetCart();
              widget.authController.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginView(
                    authController: widget.authController,
                    usuarioController: widget.usuarioController,
                  ),
                ),
              );
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _abrirRegistro() async {
    if (widget.authController.esLector) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los usuarios con perfil "Lector" no tienen permiso para registrar usuarios.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistroView(
          usuarioController: widget.usuarioController,
          authController: widget.authController,
          productoController: widget.productoController,
          compraController: widget.compraController,
        ),
      ),
    );
    if (result == true) {
      widget.usuarioController.cargarUsuarios();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.authController.esLector) {
      final prodCtrl = widget.productoController ?? ProductoController();
      return LectorHomeView(
        authController: widget.authController,
        usuarioController: widget.usuarioController,
        productoController: prodCtrl,
        compraController: widget.compraController,
        themeController: widget.themeController,
      );
    }

    final curUser = widget.authController.currentUser;
    final prodCtrl = widget.productoController ?? ProductoController();

    return Scaffold(
      backgroundColor: AppTheme.getScaffoldBg(context),
      drawer: AppDrawer(
        authController: widget.authController,
        usuarioController: widget.usuarioController,
        productoController: prodCtrl,
        compraController: widget.compraController,
        themeController: widget.themeController,
        currentRoute: 'usuarios',
      ),
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          // Botón Ver Catálogo de Productos
          IconButton(
            tooltip: 'Ver Productos',
            icon: const Icon(Icons.storefront_rounded, color: AppTheme.primaryPurple),
            onPressed: _abrirProductos,
          ),
          // Etiqueta de Perfil del Usuario Logeado
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryExtraLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_circle_rounded,
                  size: 16,
                  color: AppTheme.primaryPurple,
                ),
                const SizedBox(width: 4),
                Text(
                  'Perfil: ${curUser?.rolTexto ?? "Lector"}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          // Alternar vista Tarjeta / Tabla
          IconButton(
            tooltip: _isTableView ? 'Ver en tarjetas' : 'Ver en tabla',
            icon: Icon(
              _isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded,
              color: AppTheme.primaryPurple,
            ),
            onPressed: () {
              setState(() {
                _isTableView = !_isTableView;
              });
            },
          ),
          // Botón Cerrar Sesión
          IconButton(
            tooltip: 'Cerrar Sesión',
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      floatingActionButton: widget.authController.puedeCrear
          ? FloatingActionButton.extended(
              onPressed: _abrirRegistro,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'Nuevo Usuario',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: AnimatedBuilder(
        animation: widget.usuarioController,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: () async {
              await widget.usuarioController.cargarUsuarios();
            },
            color: AppTheme.primaryPurple,
            child: CustomScrollView(
              slivers: [
                // 1. Tarjeta de Usuario Activo / Sesión
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: _buildSessionCard(),
                  ),
                ),

                // 2. Tarjetas de Métricas Estadísticas
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildMetricCards(),
                  ),
                ),

                // 3. Barra de Búsqueda y Filtros
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildSearchAndFilters(),
                  ),
                ),

                // 4. Lista o Tabla de Usuarios
                if (widget.usuarioController.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  )
                else if (widget.usuarioController.usuarios.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                else if (_isTableView)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildTableView(widget.usuarioController.usuarios),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      bottom: 90.0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final user =
                              widget.usuarioController.usuarios[index];
                          return _buildUserCard(user);
                        },
                        childCount: widget.usuarioController.usuarios.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Tarjeta con información del usuario autenticado
  Widget _buildSessionCard() {
    final curUser = widget.authController.currentUser;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xE67E57C2),
            AppTheme.deepPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D7E57C2),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              curUser?.iniciales ?? 'U',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.deepPurple,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sesión Activa',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  curUser?.nombre ?? 'Usuario',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  curUser?.correo ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              curUser?.rolTexto ?? 'Admin',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.key_rounded, color: Colors.white, size: 20),
            tooltip: 'Cambiar mi contraseña',
            onPressed: () => CambiarContrasenaDialog.show(context, widget.authController),
          ),
        ],
      ),
    );
  }

  /// Tarjetas de métricas estadísticas (Total, Admins, Editores, Lectores)
  Widget _buildMetricCards() {
    final ctrl = widget.usuarioController;
    return Row(
      children: [
        Expanded(
          child: _metricTile(
            title: 'Total',
            count: ctrl.totalUsuarios,
            color: AppTheme.primaryPurple,
            bgColor: AppTheme.primaryExtraLight,
            icon: Icons.people_alt_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            title: 'Admins',
            count: ctrl.totalAdmins,
            color: AppTheme.roleAdminText,
            bgColor: AppTheme.roleAdminBg,
            icon: Icons.admin_panel_settings_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            title: 'Editores',
            count: ctrl.totalEditores,
            color: AppTheme.roleEditorText,
            bgColor: AppTheme.roleEditorBg,
            icon: Icons.edit_note_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            title: 'Lectores',
            count: ctrl.totalLectores,
            color: AppTheme.roleLectorText,
            bgColor: AppTheme.roleLectorBg,
            icon: Icons.visibility_rounded,
          ),
        ),
      ],
    );
  }

  Widget _metricTile({
    required String title,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withAlpha(220),
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de búsqueda y chips de filtro por rol
  Widget _buildSearchAndFilters() {
    final ctrl = widget.usuarioController;
    return Column(
      children: [
        // Input de búsqueda
        TextField(
          controller: _searchCtrl,
          onChanged: (val) => ctrl.setSearchQuery(val),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o correo...',
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppTheme.primaryPurple),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      ctrl.setSearchQuery('');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),

        // Filtro por Rol en chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(label: 'Todos', roleId: null),
              const SizedBox(width: 8),
              _filterChip(label: '👑 Admins', roleId: 1),
              const SizedBox(width: 8),
              _filterChip(label: '✏️ Editores', roleId: 2),
              const SizedBox(width: 8),
              _filterChip(label: '👁️ Lectores', roleId: 3),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip({required String label, required int? roleId}) {
    final isSelected = widget.usuarioController.selectedRoleId == roleId;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.textMain,
      ),
      backgroundColor: AppTheme.surfaceCard,
      selectedColor: AppTheme.primaryPurple,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryPurple : AppTheme.primaryLight,
        ),
      ),
      onSelected: (_) {
        widget.usuarioController.setFilterRole(roleId);
      },
    );
  }

  /// Tarjeta moderna para un usuario individual
  Widget _buildUserCard(Usuario user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceCard(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryExtraLight,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A7E57C2),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => UsuarioDetalleDialog.show(
          context,
          user,
          widget.usuarioController,
          authController: widget.authController,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              // Avatar con iniciales
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryExtraLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryLight),
                ),
                child: Center(
                  child: Text(
                    user.iniciales,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepPurple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Datos del usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${user.id ?? ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            user.nombre,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMain,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.correo,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Rol Badge
              RoleBadge(
                rol: user.rolNombre,
                roleId: user.roleId,
                compact: true,
              ),

              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vista estructurada en formato Tabla (cumpliendo la especificación: ID | Nombre | Email | Rol)
  Widget _buildTableView(List<Usuario> usuarios) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryExtraLight),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(AppTheme.primaryExtraLight),
          columnSpacing: 20,
          horizontalMargin: 16,
          columns: const [
            DataColumn(
              label: Text(
                'ID',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
            ),
            DataColumn(
              label: Text(
                'Nombre',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
            ),
            DataColumn(
              label: Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
            ),
            DataColumn(
              label: Text(
                'Rol',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
            ),
            DataColumn(
              label: Text(
                'Acciones',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
            ),
          ],
          rows: usuarios.map((u) {
            return DataRow(
              cells: [
                DataCell(Text('${u.id ?? ""}')),
                DataCell(
                  Text(
                    u.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(u.correo)),
                DataCell(
                  RoleBadge(
                    rol: u.rolNombre,
                    roleId: u.roleId,
                    compact: true,
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppTheme.primaryPurple,
                      size: 20,
                    ),
                    onPressed: () => UsuarioDetalleDialog.show(
                      context,
                      u,
                      widget.usuarioController,
                      authController: widget.authController,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Estado vacío
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryExtraLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 54,
                color: AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron usuarios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Intenta con otro término de búsqueda o agrega un nuevo usuario con el botón (+)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
