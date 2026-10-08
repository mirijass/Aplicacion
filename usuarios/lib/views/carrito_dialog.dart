import 'package:flutter/material.dart';
import '../controllers/producto_controller.dart';
import '../controllers/compra_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/compra_model.dart';
import '../services/mail_helper.dart';
import '../utils/app_theme.dart';
import 'metodos_pago_dialog.dart';
import 'widgets/product_image_widget.dart';

/// Modal bottom sheet para consultar y gestionar el Carrito de Compras
class CarritoDialog extends StatelessWidget {
  final ProductoController productoController;
  final AuthController? authController;
  final CompraController? compraController;
  final String? usuarioEmail;

  const CarritoDialog({
    super.key,
    required this.productoController,
    this.authController,
    this.compraController,
    this.usuarioEmail,
  });

  static Future<void> show(
    BuildContext context,
    ProductoController controller, {
    AuthController? authController,
    CompraController? compraController,
    String? usuarioEmail,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CarritoDialog(
        productoController: controller,
        authController: authController,
        compraController: compraController,
        usuarioEmail: usuarioEmail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: AnimatedBuilder(
        animation: productoController,
        builder: (context, _) {
          final cart = productoController.carrito;
          final total = productoController.total;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shopping_cart_rounded, color: AppTheme.primaryPurple),
                      SizedBox(width: 8),
                      Text(
                        'Mi Carrito de Compras',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                        ),
                      ),
                    ],
                  ),
                  if (cart.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: AppTheme.errorColor),
                      label: const Text('Vaciar', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                      onPressed: () {
                        productoController.vaciarCarrito();
                      },
                    ),
                ],
              ),
              const Divider(height: 24, color: AppTheme.primaryExtraLight),

              // Lista de productos en el carrito o estado vacío
              if (cart.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryExtraLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.remove_shopping_cart_outlined,
                          size: 42,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tu carrito está vacío',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Agrega productos usando el botón "Comprar"',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: cart.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        final nombre = item['nombre_product'] as String? ?? 'Producto';
                        final precio = double.tryParse(item['precio'].toString()) ?? 0.0;
                        final cant = (item['cantidad'] as int?) ?? 1;
                        final imagen = item['imagen'] as String? ?? '';
                        final subtotal = precio * cant;

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.inputFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryExtraLight),
                          ),
                          child: Row(
                            children: [
                              ProductImageWidget(
                                imageUrl: imagen,
                                width: 50,
                                height: 50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombre,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textMain,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '\$$precio MXN  (Subtotal: \$${subtotal.toStringAsFixed(2)})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primaryPurple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                    color: AppTheme.primaryPurple,
                                    onPressed: () => productoController.cambiarCantidadCarrito(index, -1),
                                  ),
                                  Text(
                                    '$cant',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                    color: AppTheme.primaryPurple,
                                    onPressed: () {
                                      final ok = productoController.cambiarCantidadCarrito(index, 1);
                                      if (!ok && productoController.errorMessage != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(productoController.errorMessage!),
                                            backgroundColor: AppTheme.errorColor,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.errorColor),
                                    onPressed: () => productoController.eliminarDelCarrito(index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Total y Botón de Pago
              if (cart.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryExtraLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a Pagar:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMain,
                        ),
                      ),
                      Text(
                        '\$${total.toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment_rounded, size: 20),
                  label: const Text('Proceder al Pago / Métodos In-App'),
                  onPressed: () {
                    final itemsComprados = List<Map<String, dynamic>>.from(cart);
                    final totalComprado = total;

                    Navigator.pop(context);

                    // Abrir Pasarela de Métodos de Pago
                    MetodosPagoDialog.show(
                      context,
                      total: totalComprado,
                      onPagoConfirmado: (metodo, direccion) async {
                        await productoController.finalizarCompra();

                        final curUser = authController?.currentUser;
                        final userNombre = curUser?.nombre ?? 'Cliente App';
                        final userEmail = curUser?.correo ?? usuarioEmail ?? 'cliente@ejemplo.com';
                        final userId = curUser?.id ?? 1;

                        // Registrar compra en el historial/reporte
                        final nuevaCompra = Compra(
                          usuarioId: userId,
                          usuarioNombre: userNombre,
                          usuarioCorreo: userEmail,
                          total: totalComprado,
                          fecha: DateTime.now().toString().split('.')[0],
                          metodoPago: metodo,
                          estado: 'En camino',
                          items: itemsComprados,
                          direccionEntrega: direccion,
                        );

                        if (compraController != null) {
                          await compraController!.registrarNuevaCompra(nuevaCompra);
                        }

                        // Intentar enviar recibo por correo
                        try {
                          await MailHelper.sendPurchaseSummaryEmail(
                            userEmail,
                            itemsComprados,
                            totalComprado,
                          );
                        } catch (e) {
                          debugPrint('Resumen de compra enviado en modo simulado: $e');
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '¡Pago con $metodo exitoso! Se envió tu recibo a $userEmail.',
                              ),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
