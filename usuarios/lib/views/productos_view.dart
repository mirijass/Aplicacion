import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/auth_controller.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/producto_controller.dart';
import '../controllers/compra_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/producto_model.dart';
import '../utils/app_theme.dart';
import 'widgets/role_badge.dart';
import 'widgets/app_drawer.dart';
import 'widgets/product_image_widget.dart';
import 'producto_form_dialog.dart';
import 'carrito_dialog.dart';
import 'historial_compras_view.dart';
import 'configuracion_view.dart';

/// Vista Principal del Catálogo y Gestión de Productos (MVC)
class ProductosView extends StatefulWidget {
  final AuthController authController;
  final ProductoController productoController;
  final CompraController? compraController;
  final ThemeController? themeController;
  final UsuarioController? usuarioController;

  const ProductosView({
    super.key,
    required this.authController,
    required this.productoController,
    this.compraController,
    this.themeController,
    this.usuarioController,
  });

  @override
  State<ProductosView> createState() => _ProductosViewState();
}

class _ProductosViewState extends State<ProductosView> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final CompraController _compraCtrl;
  late final ThemeController _themeCtrl;
  late final UsuarioController _usuarioCtrl;

  @override
  void initState() {
    super.initState();
    _compraCtrl = widget.compraController ?? CompraController();
    _themeCtrl = widget.themeController ?? ThemeController();
    _usuarioCtrl = widget.usuarioController ?? UsuarioController();
    widget.productoController.setActiveUser(widget.authController.currentUser);
    // Cargar productos locales al iniciar si aún no están en memoria
    if (widget.productoController.productos.isEmpty) {
      widget.productoController.cargarProductos();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _abrirFormulario({Producto? producto}) {
    if (widget.authController.esLector) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los usuarios con perfil "Lector" no tienen permiso para modificar productos.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    ProductoFormDialog.show(
      context,
      widget.productoController,
      producto: producto,
      usuarioLogeado: widget.authController.currentUser,
    );
  }

  void _confirmarEliminacion(Producto prod) {
    if (!widget.authController.puedeEliminar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo los Administradores tienen permiso para eliminar productos.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Eliminar Producto', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text('¿Deseas eliminar "${prod.nombre}" del catálogo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(ctx);
              if (prod.id != null) {
                final ok = await widget.productoController.eliminarProducto(
                  prod.id!,
                  usuarioLogeado: widget.authController.currentUser,
                );
                if (mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Producto eliminado'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _abrirSelectorCantidad(Producto prod) {
    final quantityCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Comprar ${prod.nombre}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Precio: \$${prod.precio.toStringAsFixed(2)} MXN'),
            Text('Stock disponible: ${prod.cantidad}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 14),
            TextField(
              controller: quantityCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'Cantidad a comprar',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              int cantidad = int.tryParse(quantityCtrl.text.trim()) ?? 1;
              if (cantidad <= 0) return;
              final ok = widget.productoController.agregarAlCarrito(prod, cantidad);
              Navigator.pop(ctx);
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${prod.nombre} agregado al carrito (x$cantidad)'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.productoController.errorMessage ?? 'No hay suficiente stock disponible',
                    ),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('Agregar al Carrito'),
          ),
        ],
      ),
    );
  }

  void _compartirProducto(Producto prod) {
    Share.share(
      '¡Mira este producto en Mi Tiendita!\n\n'
      'Producto: ${prod.nombre}\n'
      'Precio: \$${prod.precio.toStringAsFixed(2)} MXN\n'
      'Stock: ${prod.cantidad} disponibles\n\n'
      '¡Consíguelo ahora en la app!',
      subject: 'Producto: ${prod.nombre}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final curUser = widget.authController.currentUser;
    final esLector = widget.authController.esLector;
    final compraCtrl = _compraCtrl;
    final themeCtrl = _themeCtrl;
    final usrCtrl = _usuarioCtrl;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.getScaffoldBg(context),
      drawer: AppDrawer(
        authController: widget.authController,
        usuarioController: usrCtrl,
        productoController: widget.productoController,
        compraController: compraCtrl,
        themeController: themeCtrl,
        currentRoute: 'productos',
      ),
      appBar: AppBar(
        title: const Text('Tiendita de Productos'),
        actions: [
          // Botón Ajustes y Personalización
          IconButton(
            tooltip: 'Ajustes y Tema',
            icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryPurple),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConfiguracionView(
                    themeController: themeCtrl,
                    authController: widget.authController,
                  ),
                ),
              );
            },
          ),

          // Botón Historial de Compras y Reportes
          IconButton(
            tooltip: 'Historial y Reportes',
            icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryPurple),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistorialComprasView(
                    authController: widget.authController,
                    compraController: compraCtrl,
                  ),
                ),
              );
            },
          ),

          // Botón Sincronizar API Online (Admin y Editor)
          if (!esLector)
            IconButton(
              tooltip: 'Sincronizar Online (FakeStore)',
              icon: AnimatedBuilder(
                animation: widget.productoController,
                builder: (context, _) {
                  return widget.productoController.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple),
                        )
                      : const Icon(Icons.cloud_download_rounded, color: AppTheme.primaryPurple);
                },
              ),
              onPressed: () async {
                final ok = await widget.productoController.sincronizarOnline(
                  usuarioLogeado: widget.authController.currentUser,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.productoController.successMessage ??
                            widget.productoController.errorMessage ??
                            'Sincronización completada',
                      ),
                      backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  );
                }
              },
            ),

          // Botón Carrito de Compras con Badge Contador
          AnimatedBuilder(
            animation: widget.productoController,
            builder: (context, _) {
              final count = widget.productoController.cantidadItemsCarrito;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Ver Carrito',
                    icon: const Icon(Icons.shopping_cart_rounded, color: AppTheme.primaryPurple),
                    onPressed: () => CarritoDialog.show(
                      context,
                      widget.productoController,
                      authController: widget.authController,
                      compraController: compraCtrl,
                      usuarioEmail: curUser?.correo,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: widget.authController.puedeCrear
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Nuevo Producto', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: AnimatedBuilder(
        animation: widget.productoController,
        builder: (context, _) {
          final controller = widget.productoController;

          return RefreshIndicator(
            onRefresh: () async {
              await controller.cargarProductos();
            },
            color: AppTheme.primaryPurple,
            child: CustomScrollView(
              slivers: [
                // Banner de Alertas en Tiempo Real / Ofertas
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryExtraLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryLight),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.campaign_rounded, color: AppTheme.primaryPurple, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '⚡ ¡Alertas en tiempo real: Descuentos in-app y envíos gratis activados!',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepPurple),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 1. Tarjeta de Sesión / Perfil Activo
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xE67E57C2), AppTheme.deepPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    curUser?.iniciales ?? 'U',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.deepPurple,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        curUser?.nombre ?? 'Usuario',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Catálogo & Gestión de Productos',
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(200),
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          RoleBadge(
                            rol: curUser?.rolTexto,
                            roleId: curUser?.roleId,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Barra de Búsqueda
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => controller.setSearchQuery(val),
                      decoration: InputDecoration(
                        hintText: 'Buscar producto por nombre...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryPurple),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  controller.setSearchQuery('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // 3. Contenido de Productos (Usando SliverToBoxAdapter para evitar conflictos de GlobalKey en SliverFillRemaining)
                if (controller.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                      ),
                    ),
                  )
                else if (controller.productos.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 90),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final prod = controller.productos[index];
                          return RepaintBoundary(
                            child: _buildProductCard(prod),
                          );
                        },
                        childCount: controller.productos.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }

  /// Tarjeta moderna de producto
  Widget _buildProductCard(Producto prod) {
    final puedeEditar = widget.authController.puedeEditar;
    final puedeEliminar = widget.authController.puedeEliminar;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceCard(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryExtraLight, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A7E57C2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Imagen con fallback
            ProductImageWidget(
              imageUrl: prod.imagen,
              width: 90,
              height: 90,
              borderRadius: BorderRadius.circular(14),
            ),
            const SizedBox(width: 12),

            // Información del Producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prod.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${prod.precio.toStringAsFixed(2)} MXN',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryExtraLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Stock: ${prod.cantidad}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Columna de Acciones: Comprar, Compartir, Editar / Eliminar
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                  label: const Text('Comprar', style: TextStyle(fontSize: 12)),
                  onPressed: () => _abrirSelectorCantidad(prod),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Compartir',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      icon: const Icon(Icons.share_rounded, size: 18, color: AppTheme.primaryPurple),
                      onPressed: () => _compartirProducto(prod),
                    ),
                    if (puedeEditar)
                      IconButton(
                        tooltip: 'Editar',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primaryPurple),
                        onPressed: () => _abrirFormulario(producto: prod),
                      ),
                    if (puedeEliminar)
                      IconButton(
                        tooltip: 'Eliminar',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.errorColor),
                        onPressed: () => _confirmarEliminacion(prod),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Estado vacío
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryExtraLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 54,
                color: AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron productos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchCtrl.text.isNotEmpty
                  ? 'No hay coincidencias para "${_searchCtrl.text}".'
                  : 'Presiona el botón de abajo para recargar el catálogo de productos.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _searchCtrl.clear();
                widget.productoController.setSearchQuery('');
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Recargar Catálogo'),
            ),
          ],
        ),
      ),
    );
  }
}
