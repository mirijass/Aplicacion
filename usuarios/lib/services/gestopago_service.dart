import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/producto_xml_model.dart';
import '../data/gestopago_catalog_data.dart';
import 'xml_parser_service.dart';
import '../controllers/saldo_proveedor_controller.dart';

/// Secciones principales requeridas para la interfaz
enum SeccionGestoPago {
  recargas, // Telefonía, tiempo aire, paquetes
  pagos, // Servicios (CFE, agua, gas, peaje, AFORE, etc.)
  tarjetas, // Tarjetas electrónicas, pines, entretenimiento, cine
  saldoProveedor, // Manejo de saldo con el proveedor
}

/// Servicio especializado para la integración con la API de GestoPago
/// (GESTO PAGO DE SERVICIOS, S.A.P.I. DE C.V.)
class GestoPagoService {
  /// URL oficial del Endpoint de obtención de productos según documentación Postman
  static const String endpointProductList =
      'https://gestopago.portalventas.net/sistema/service/getProductList.do';

  /// Token Bearer oficial proporcionado en la documentación
  static const String defaultBearerToken =
      'qmzAAEYFmqQbIT/Ktxme8Akih4Md6cXf9hTHKjfO626aEN8GrvSLaA9CJP3Q1UI5bL6/tDk+nsTwmGoUwm3VR+LPbGaB13DSSR2d+wUdceSs/epdqLgDU3oXf7bBGg4eM3zedv28wAfcldkQHxSzFw==';

  /// Categorías asignadas a cada sección
  static const List<String> categoriasRecargas = ['13', '3'];
  static const List<String> categoriasPagos = ['5', '15', '8', '9', '18', '19'];
  static const List<String> categoriasTarjetas = ['10', '11', '16'];

  /// Sincroniza el catálogo de productos consultando el Endpoint online de GestoPago.
  /// Si el token está expirado o falla la red, recurre automáticamente al catálogo
  /// completo para permitir simulaciones y pruebas 100% funcionales.
  static Future<Map<String, dynamic>> sincronizarConApiOnline({
    String? tokenPersonalizado,
  }) async {
    final token = tokenPersonalizado ?? defaultBearerToken;

    try {
      final response = await http.get(
        Uri.parse(endpointProductList),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 8));

      // Verificar si la respuesta es XML válida
      if (response.statusCode == 200 && response.body.contains('<PRODUCTOS>')) {
        final respuesta = await XmlParserService.procesarYGuardarXml(response.body);
        return {
          'exito': true,
          'mensaje': 'Catálogo actualizado directamente desde la API de GestoPago.',
          'totalProductos': respuesta.productos.length,
          'esSimulado': false,
        };
      } else {
        // En caso de token expirado o respuesta JSON de error del servidor
        String errorMsg = 'El servidor devolvió status ${response.statusCode}';
        if (response.body.contains('token') || response.body.contains('EXPIRED')) {
          errorMsg = 'Token de autorización expirado (validez 24h).';
        }
        debugPrint('Aviso GestoPago API: $errorMsg. Activando catálogo simulado de respaldo.');

        // Cargar catálogo completo de respaldo en SQLite / memoria
        await XmlParserService.guardarProductosXmlBatch(GestoPagoCatalogData.catalogoCompleto);

        return {
          'exito': true,
          'mensaje': '$errorMsg Se activó el catálogo oficial en modo pruebas simuladas.',
          'totalProductos': GestoPagoCatalogData.catalogoCompleto.length,
          'esSimulado': true,
        };
      }
    } catch (e) {
      debugPrint('Excepción al conectar con GestoPago API: $e. Usando catálogo local.');
      await XmlParserService.guardarProductosXmlBatch(GestoPagoCatalogData.catalogoCompleto);

      return {
        'exito': true,
        'mensaje': 'Modo de pruebas simuladas activo. Catálogo oficial cargado.',
        'totalProductos': GestoPagoCatalogData.catalogoCompleto.length,
        'esSimulado': true,
      };
    }
  }

  /// Obtiene todos los productos del catálogo XML (para la vista "Productos (XML)")
  static Future<List<ProductoXml>> obtenerTodosLosProductos({String? query}) async {
    List<ProductoXml> productos = [];
    try {
      productos = await XmlParserService.obtenerProductosXml();
    } catch (_) {}

    if (productos.isEmpty) {
      await XmlParserService.guardarProductosXmlBatch(GestoPagoCatalogData.catalogoCompleto);
      productos = List<ProductoXml>.from(GestoPagoCatalogData.catalogoCompleto);
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      productos = productos.where((p) {
        return p.servicio.toLowerCase().contains(q) ||
            p.producto.toLowerCase().contains(q) ||
            p.legend.toLowerCase().contains(q);
      }).toList();
    }

    return productos;
  }

  /// Obtiene los productos filtrados por sección (Recargas, Pagos, Tarjetas)
  static Future<List<ProductoXml>> obtenerServiciosPorSeccion({
    required SeccionGestoPago seccion,
    String? subfiltro,
    String? query,
  }) async {
    List<ProductoXml> productos = [];
    try {
      productos = await XmlParserService.obtenerProductosXml();
    } catch (_) {}

    // Si la base de datos está vacía, cargar el catálogo base
    if (productos.isEmpty) {
      await XmlParserService.guardarProductosXmlBatch(GestoPagoCatalogData.catalogoCompleto);
      productos = List<ProductoXml>.from(GestoPagoCatalogData.catalogoCompleto);
    }

    // 1. Filtrar por Sección principal
    switch (seccion) {
      case SeccionGestoPago.recargas:
        productos = productos.where((p) {
          final cat = p.idCatTipoServicio?.toString() ?? '';
          return categoriasRecargas.contains(cat);
        }).toList();
        break;

      case SeccionGestoPago.pagos:
        productos = productos.where((p) {
          final cat = p.idCatTipoServicio?.toString() ?? '';
          return categoriasPagos.contains(cat);
        }).toList();
        break;

      case SeccionGestoPago.tarjetas:
        productos = productos.where((p) {
          final cat = p.idCatTipoServicio?.toString() ?? '';
          return categoriasTarjetas.contains(cat);
        }).toList();
        break;

      case SeccionGestoPago.saldoProveedor:
        // No requiere filtrado de catálogo
        break;
    }

    // 2. Filtrar por subfiltro (marca / tipo de servicio)
    if (subfiltro != null && subfiltro != 'todos' && subfiltro.isNotEmpty) {
      final sub = subfiltro.toLowerCase();
      productos = productos.where((p) {
        return p.servicio.toLowerCase().contains(sub) ||
            p.producto.toLowerCase().contains(sub);
      }).toList();
    }

    // 3. Filtrar por texto de búsqueda
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      productos = productos.where((p) {
        return p.servicio.toLowerCase().contains(q) ||
            p.producto.toLowerCase().contains(q) ||
            p.legend.toLowerCase().contains(q);
      }).toList();
    }

    return productos;
  }

  /// Simula la consulta de recibo / verificación de referencia ante el proveedor
  static Future<Map<String, dynamic>> consultarReferencia(
    ProductoXml servicio,
    String referencia,
  ) async {
    await Future.delayed(const Duration(milliseconds: 650));

    if (referencia.trim().length < 4) {
      return {
        'exito': false,
        'mensaje': 'La referencia ingresada es demasiado corta (mínimo 4 caracteres).',
      };
    }

    // Generar monto simulado razonable si el precio es 0.0 (recibo con monto libre)
    final montoCalculado = servicio.precio > 0
        ? servicio.precio
        : (servicio.servicio.contains('CFE')
            ? 348.0
            : servicio.servicio.contains('Agua')
                ? 185.0
                : 150.0);

    const comisionProveedor = 12.0;

    return {
      'exito': true,
      'referencia': referencia.trim(),
      'servicio': servicio.servicio,
      'producto': servicio.producto,
      'titularSimulado': 'TITULAR REGISTRADO - CONTRATO ${referencia.trim()}',
      'fechaVencimiento': DateTime.now().add(const Duration(days: 7)).toString().split(' ')[0],
      'monto': montoCalculado,
      'comision': comisionProveedor,
      'totalConComision': montoCalculado + comisionProveedor,
      'leyendaGestoPago': servicio.legend.isNotEmpty
          ? servicio.legend
          : 'Servicio provisto por GESTO PAGO DE SERVICIOS, S.A.P.I. DE C.V.',
    };
  }

  /// Procesa el pago de servicio, recarga telefónica o emisión de PIN de tarjeta de regalo
  static Future<Map<String, dynamic>> procesarTransaccion({
    required ProductoXml servicio,
    required String referencia,
    required double monto,
    required String metodoPago,
    required bool usarSaldoProveedor,
    String? correoDestino,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final folioGestoPago = 'GP-AUTH-$nowMs';
    const comisionComercio = 2.50; // Comisión ganada por el negocio

    // Si se paga con el saldo con el proveedor, descontar del saldo local
    if (usarSaldoProveedor) {
      final saldoController = SaldoProveedorController();
      final ok = await saldoController.descontarSaldo(
        monto: monto,
        concepto: '${servicio.servicio} - ${servicio.producto} (Ref: $referencia)',
        folio: folioGestoPago,
        comisionGanada: comisionComercio,
        detalles: {
          'idProducto': servicio.idProducto,
          'servicio': servicio.servicio,
          'referencia': referencia,
          'monto': monto,
        },
      );

      if (!ok) {
        return {
          'exito': false,
          'mensaje': 'Saldo insuficiente con el proveedor GestoPago para cubrir el monto.',
        };
      }
    }

    // Si es tarjeta de regalo o pin, generar código de canje simulado
    String? pinGenerado;
    final esTarjeta = categoriasTarjetas.contains(servicio.idCatTipoServicio?.toString());
    if (esTarjeta) {
      pinGenerado = _generarPinDigital(servicio.servicio);
    }

    return {
      'exito': true,
      'folioGestoPago': folioGestoPago,
      'servicio': servicio.servicio,
      'producto': servicio.producto,
      'referencia': referencia,
      'monto': monto,
      'metodoPago': metodoPago,
      'usarSaldoProveedor': usarSaldoProveedor,
      'fechaHora': DateTime.now().toString().split('.')[0],
      'pinDigital': pinGenerado,
      'correoDestino': correoDestino,
      'proveedor': 'GESTO PAGO DE SERVICIOS, S.A.P.I. DE C.V.',
      'leyenda': servicio.legend,
      'comisionGanada': usarSaldoProveedor ? comisionComercio : 0.0,
    };
  }

  /// Genera un PIN o código de canje digital para tarjetas electrónicas
  static String _generarPinDigital(String marca) {
    final rand = DateTime.now().millisecondsSinceEpoch.toString();
    final prefijo = marca.toUpperCase().replaceAll(' ', '').takeChars(3);
    return '$prefijo-${rand.substring(rand.length - 4)}-${rand.substring(rand.length - 8, rand.length - 4)}';
  }

  /// Método de compatibilidad para código existente
  static Future<List<ProductoXml>> obtenerServicios({
    String? categoriaId,
    String? query,
  }) async {
    return obtenerServiciosPorSeccion(
      seccion: SeccionGestoPago.pagos,
      query: query,
    );
  }

  /// Método de compatibilidad para procesar pagos
  static Future<Map<String, dynamic>> procesarPagoGestoPago({
    required ProductoXml servicio,
    required String referencia,
    required double monto,
    required String metodoPago,
  }) async {
    return procesarTransaccion(
      servicio: servicio,
      referencia: referencia,
      monto: monto,
      metodoPago: metodoPago,
      usarSaldoProveedor: metodoPago.contains('Saldo'),
    );
  }
}

extension on String {
  String takeChars(int n) {
    if (length <= n) return this;
    return substring(0, n);
  }
}
