import 'dart:async';
import 'package:flutter/material.dart';
import '../models/compra_model.dart';
import '../utils/app_theme.dart';

/// Vista de Geolocalización, Mapa de Entrega y Rastreo en Tiempo Real
class MapaGeolocalizacionView extends StatefulWidget {
  final Compra compra;

  const MapaGeolocalizacionView({
    super.key,
    required this.compra,
  });

  @override
  State<MapaGeolocalizacionView> createState() => _MapaGeolocalizacionViewState();
}

class _MapaGeolocalizacionViewState extends State<MapaGeolocalizacionView> {
  double _progresoRuta = 0.35; // 0.0 a 1.0
  Timer? _timer;
  int _minutosEstimados = 18;

  @override
  void initState() {
    super.initState();
    // Simular avance del repartidor en tiempo real
    _timer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) return;
      setState(() {
        if (_progresoRuta < 0.95) {
          _progresoRuta += 0.08;
          if (_minutosEstimados > 2) _minutosEstimados -= 2;
        } else {
          _progresoRuta = 1.0;
          _minutosEstimados = 0;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Rastreo del Pedido #${widget.compra.id ?? 1}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Volver al Inicio',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner de Estado del Envío
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: AppTheme.primaryExtraLight,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _progresoRuta >= 1.0 ? '¡Pedido Entregado!' : 'Pedido en Camino',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _progresoRuta >= 1.0
                              ? 'Tu paquete ha sido entregado en la dirección.'
                              : 'Tiempo estimado de llegada: ~$_minutosEstimados min',
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Visualización Interactiva del Mapa mediante Canvas / Painter Customizado
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECEF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryLight, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 6)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Fondo de mapa sintético con painter
                      Positioned.fill(
                        child: CustomPaint(
                          painter: MapRoutePainter(progreso: _progresoRuta),
                        ),
                      ),

                      // Marcador de la Tienda (Origen)
                      Positioned(
                        top: 40,
                        left: 40,
                        child: Column(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 38, color: AppTheme.primaryPurple),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(8))),
                              child: const Text('Tiendita Central', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),

                      // Marcador del Cliente (Destino)
                      Positioned(
                        bottom: 50,
                        right: 40,
                        child: Column(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 42, color: AppTheme.errorColor),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(8))),
                              child: Text(widget.compra.usuarioNombre, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),

                      // Marcador del Repartidor en Movimiento (Animación en Tiempo Real)
                      AnimatedPositioned(
                        duration: const Duration(seconds: 1),
                        top: 40 + (MediaQuery.of(context).size.height * 0.35) * _progresoRuta,
                        left: 40 + (MediaQuery.of(context).size.width * 0.55) * _progresoRuta,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.deepPurple,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Color(0x407E57C2), blurRadius: 10, spreadRadius: 2),
                            ],
                          ),
                          child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Detalle de la Dirección de Entrega y Folio con Botón de Regreso al Menú
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.my_location_rounded, color: AppTheme.primaryPurple, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.compra.direccionEntrega,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Método de Pago: ${widget.compra.metodoPago}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      Text(
                        'Total: \$${widget.compra.total.toStringAsFixed(2)} MXN',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.deepPurple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'Volver al Menú Principal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter para dibujar las calles y ruta en el Mapa de Entrega
class MapRoutePainter extends CustomPainter {
  final double progreso;

  MapRoutePainter({required this.progreso});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFD4DADF)
      ..strokeWidth = 1.0;

    // Dibujar cuadricula de calles
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Ruta trazada
    final routePaint = Paint()
      ..color = AppTheme.primaryLight
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = AppTheme.primaryPurple
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(60, 60);
    path.lineTo(size.width * 0.7, size.height * 0.7);

    canvas.drawPath(path, routePaint);

    final progressPath = Path();
    progressPath.moveTo(60, 60);
    progressPath.lineTo(
      60 + (size.width * 0.7 - 60) * progreso,
      60 + (size.height * 0.7 - 60) * progreso,
    );
    canvas.drawPath(progressPath, progressPaint);
  }

  @override
  bool shouldRepaint(covariant MapRoutePainter oldDelegate) =>
      oldDelegate.progreso != progreso;
}
