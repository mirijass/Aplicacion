import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usuarios/controllers/saldo_proveedor_controller.dart';
import 'package:usuarios/models/producto_xml_model.dart';
import 'package:usuarios/services/gestopago_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GestoPagoService y Secciones', () {
    test('Filtra correctamente por sección de Recargas, Pagos y Tarjetas', () async {
      final recargas = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.recargas,
      );
      expect(recargas.isNotEmpty, isTrue);
      expect(
        recargas.any((p) => p.servicio.toLowerCase().contains('telcel') || p.servicio.toLowerCase().contains('abib')),
        isTrue,
      );

      final pagos = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.pagos,
      );
      expect(pagos.isNotEmpty, isTrue);
      expect(
        pagos.any((p) => p.servicio.toLowerCase().contains('cfe') || p.servicio.toLowerCase().contains('agua')),
        isTrue,
      );

      final tarjetas = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.tarjetas,
      );
      expect(tarjetas.isNotEmpty, isTrue);
      expect(
        tarjetas.any((p) => p.servicio.toLowerCase().contains('amazon') || p.servicio.toLowerCase().contains('netflix')),
        isTrue,
      );
    });

    test('Consulta referencia y valida longitud', () async {
      final servicios = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.pagos,
      );
      final prod = servicios.first;

      final corta = await GestoPagoService.consultarReferencia(prod, '12');
      expect(corta['exito'], isFalse);

      final valida = await GestoPagoService.consultarReferencia(prod, '012345678901');
      expect(valida['exito'], isTrue);
      expect(valida['referencia'], equals('012345678901'));
      expect(valida['titularSimulado'], contains('012345678901'));
    });

    test('Procesa transacción de tarjeta digital generando PIN', () async {
      final tarjetas = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.tarjetas,
      );
      final giftCard = tarjetas.firstWhere(
        (p) => p.servicio.toLowerCase().contains('amazon'),
        orElse: () => tarjetas.first,
      );

      final resultado = await GestoPagoService.procesarTransaccion(
        servicio: giftCard,
        referencia: 'cliente@gmail.com',
        monto: giftCard.precio > 0 ? giftCard.precio : 100.0,
        metodoPago: 'Saldo Proveedor',
        usarSaldoProveedor: false,
        correoDestino: 'cliente@gmail.com',
      );

      expect(resultado['exito'], isTrue);
      expect(resultado['pinDigital'], isNotNull);
      expect(resultado['folioGestoPago'], startsWith('GP-AUTH-'));
    });
  });

  group('SaldoProveedorController', () {
    test('Gestiona saldo, abonos, cargos y comisiones', () async {
      final controller = SaldoProveedorController();
      await controller.reiniciarSaldoPruebas(nuevoSaldo: 500.0);

      expect(controller.saldo, equals(500.0));
      expect(controller.comisionesGanadas, equals(0.0));

      // Recargar saldo
      await controller.recargarSaldo(monto: 200.0, metodoPago: 'SPEI');
      expect(controller.saldo, equals(700.0));

      // Descontar saldo con comisión
      final cobroExitoso = await controller.descontarSaldo(
        monto: 150.0,
        concepto: 'Pago de CFE',
        folio: 'TEST-FOLIO-1',
        comisionGanada: 2.50,
      );
      expect(cobroExitoso, isTrue);
      expect(controller.saldo, equals(550.0));
      expect(controller.comisionesGanadas, equals(2.50));

      // Intentar descontar más de lo disponible
      final cobroFallido = await controller.descontarSaldo(
        monto: 1000.0,
        concepto: 'Pago excesivo',
        folio: 'TEST-FOLIO-2',
      );
      expect(cobroFallido, isFalse);
      expect(controller.saldo, equals(550.0));
    });
  });
}
