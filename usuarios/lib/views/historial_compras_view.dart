import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../controllers/compra_controller.dart';
import '../models/compra_model.dart';
import '../utils/app_theme.dart';
import 'mapa_geolocalizacion_view.dart';

/// Vista de Historial de Compras y Panel de Reportes del Administrador (MVC)
class HistorialComprasView extends StatefulWidget {
  final AuthController authController;
  final CompraController compraController;

  const HistorialComprasView({
    super.key,
    required this.authController,
    required this.compraController,
  });

  @override
  State<HistorialComprasView> createState() => _HistorialComprasViewState();
}

class _HistorialComprasViewState extends State<HistorialComprasView> {
  @override
  void initState() {
    super.initState();
    widget.compraController.cargarCompras(
      usuarioLogeado: widget.authController.currentUser,
    );
  }

  @override
  Widget build(BuildContext context) {
    final curUser = widget.authController.currentUser;
    final esAdmin = curUser?.esAdmin ?? false;

    return Scaffold(
      backgroundColor: AppTheme.getScaffoldBg(context),
      appBar: AppBar(
        title: Text(esAdmin ? 'Panel de Reportes y Compras' : 'Mis Compras'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.compraController,
        builder: (context, _) {
          final controller = widget.compraController;

          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Panel de Métricas y Reportes (Solo Admin y Editor)
                if (esAdmin || (curUser?.esEditor ?? false)) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Color(0x207E57C2), blurRadius: 16, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Reporte de Ventas Globales',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    const Text('Ventas Totales', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${controller.totalVentasGlobales.toStringAsFixed(2)} MXN',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    const Text('Transacciones', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${controller.totalOrdenes}',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 2. Encabezado de Lista
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      esAdmin ? 'Historial de Compras de Todos los Usuarios' : 'Historial de Pedidos',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryPurple),
                      onPressed: () => controller.cargarCompras(usuarioLogeado: curUser),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Lista de Compras
                if (controller.compras.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.history_rounded, size: 50, color: AppTheme.primaryLight),
                        SizedBox(height: 10),
                        Text('No se registran compras previas', style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.compras.length,
                    itemBuilder: (context, index) {
                      final compra = controller.compras[index];
                      return _buildCompraCard(compra);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompraCard(Compra compra) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryExtraLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folio #${compra.id ?? 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryExtraLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  compra.estado,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Cliente: ${compra.usuarioNombre} (${compra.usuarioCorreo})', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Text('Fecha: ${compra.fecha}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          const Divider(height: 18),
          
          // Artículos
          Column(
            children: compra.items.map((item) {
              final nombre = item['nombre_product'] ?? item['nombre'] ?? 'Producto';
              final cant = item['cantidad'] ?? 1;
              final precio = double.tryParse(item['precio'].toString()) ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('• $nombre (x$cant)', style: const TextStyle(fontSize: 12.5)),
                    Text('\$${(precio * cant).toStringAsFixed(2)} MXN', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.map_rounded, size: 16),
                label: const Text('Rastrear en Mapa', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MapaGeolocalizacionView(compra: compra),
                    ),
                  );
                },
              ),
              Text(
                'Total: \$${compra.total.toStringAsFixed(2)} MXN',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.deepPurple),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
