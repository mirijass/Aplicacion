import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usuarios/controllers/saldo_proveedor_controller.dart';
import 'package:usuarios/models/producto_xml_model.dart';
import 'package:usuarios/services/gestopago_service.dart';
import 'package:usuarios/models/gestopago_tx_response.dart';
import 'package:usuarios/views/gestopago_ticket_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GestoPagoService y Secciones Oficiales', () {
    test('Filtra correctamente por sección de Recargas, Pagos y Tarjetas', () async {
      final recargas = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.recargas,
      );
      expect(recargas.isNotEmpty, isTrue);
      expect(
        recargas.any((p) =>
            p.servicio.toLowerCase().contains('telcel') ||
            p.servicio.toLowerCase().contains('movistar') ||
            p.servicio.toLowerCase().contains('abib')),
        isTrue,
      );

      final pagos = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.pagos,
      );
      expect(pagos.isNotEmpty, isTrue);
      expect(
        pagos.any((p) =>
            p.servicio.toLowerCase().contains('cfe') ||
            p.servicio.toLowerCase().contains('telmex') ||
            p.servicio.toLowerCase().contains('agua')),
        isTrue,
      );

      final tarjetas = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.tarjetas,
      );
      expect(tarjetas.isNotEmpty, isTrue);
      expect(
        tarjetas.any((p) =>
            p.servicio.toLowerCase().contains('amazon') ||
            p.servicio.toLowerCase().contains('netflix')),
        isTrue,
      );
    });

    test('Valida formato de número telefónico (10 dígitos incluyendo números de prueba GestoPago)', () {
      expect(GestoPagoService.validarNumeroTelefonico('1111111111'), isTrue);
      expect(GestoPagoService.validarNumeroTelefonico('5555555551'), isTrue);
      expect(GestoPagoService.validarNumeroTelefonico('5512345678'), isTrue);
      expect(GestoPagoService.validarNumeroTelefonico('12345'), isFalse);
      expect(GestoPagoService.validarNumeroTelefonico('55123abcde'), isFalse);
    });

    test('Construye y firma el payload JSON para sendTx.do según especificación Postman', () {
      final telcel10 = ProductoXml(
        idProducto: 582,
        servicio: 'Telcel',
        producto: 'Telcel 10',
        idServicio: 133,
        idCatTipoServicio: 2,
        tipoFront: 1,
        precio: 10.0,
      );

      final payloadRecarga = GestoPagoService.construirPayloadSendTx(
        servicio: telcel10,
        referencia: '1111111111',
        monto: 10.0,
        horaLocalPersonalizada: '20261028191635',
        upcPersonalizado: 'test_UPC_83_605',
      );

      expect(payloadRecarga['idProducto'], equals(582));
      expect(payloadRecarga['idServicio'], equals(133));
      expect(payloadRecarga['telefono'], equals('1111111111'));
      expect(payloadRecarga['horaLocal'], equals('20261028191635'));
      expect(payloadRecarga['upc'], equals('test_UPC_83_605'));
      expect(payloadRecarga['unidad'], equals('083'));

      final jsonStr = jsonEncode(payloadRecarga);
      final signed = GestoPagoService.cifrarPayloadAes(jsonStr);
      expect(signed.isNotEmpty, isTrue);

      final descifrado = GestoPagoService.descifrarPayloadAes(signed);
      expect(descifrado, equals(jsonStr));
    });

    test('Construye payload JSON para Pagos de Servicios (tipoFront 2) y Pines (idCatTipoServicio 11)', () {
      final telmex = ProductoXml(
        idProducto: 205,
        servicio: 'Telmex',
        producto: 'Pago de Recibo Telmex',
        idServicio: 76,
        idCatTipoServicio: 5,
        tipoFront: 2,
        precio: 10.0,
      );

      final payloadServicio = GestoPagoService.construirPayloadSendTx(
        servicio: telmex,
        referencia: '25720381',
        monto: 366.99,
      );
      expect(payloadServicio['idProducto'], equals(205));
      expect(payloadServicio['idServicio'], equals(76));
      expect(payloadServicio['telefono'], equals('1111111111'));
      expect(payloadServicio['referencia'], equals('25720381'));
      expect(payloadServicio['montoPago'], equals(366.99));
      expect(payloadServicio['unidad'], equals('083'));

      final netflix = ProductoXml(
        idProducto: 7030,
        servicio: 'Netflix',
        producto: 'Netflix 300',
        idServicio: 178,
        idCatTipoServicio: 11,
        tipoFront: 1,
        precio: 300.0,
      );

      final payloadPin = GestoPagoService.construirPayloadSendTx(
        servicio: netflix,
        referencia: 'cliente@correo.com',
        monto: 300.0,
      );
      expect(payloadPin['idProducto'], equals(7030));
      expect(payloadPin['idServicio'], equals(178));
      expect(payloadPin['telefono'], equals('#1111111111'));
    });
  });

  group('SaldoProveedorController', () {
    test('Sincroniza saldo real del servidor y registra cargos con saldo posterior de GestoPago', () async {
      final controller = SaldoProveedorController();
      await controller.sincronizarSaldoDesdeServidor(43009.89);
      expect(controller.saldo, equals(43009.89));

      await controller.registrarCargoConSaldoServidor(
        monto: 10.0,
        saldoServidorPosterior: 42999.89,
        comisionProveedor: 7.0,
        concepto: 'Recarga Telcel - Telcel 10',
        folio: '949515254',
        fechaServidor: '28/Oct/2026 19:16:35',
      );

      expect(controller.saldo, equals(42999.89));
      expect(controller.comisionesGanadas, greaterThanOrEqualTo(7.0));
    });
  });

  group('GestoPagoService - Rotación y Validación de Token (24 Horas)', () {
    test('Rotar token actualiza token y establece vigencia exacta de 24h', () async {
      SharedPreferences.setMockInitialValues({});

      const nuevoTokenPrueba = 'nuevo_token_prueba_jwt_rotado_2026';
      final resultado = await GestoPagoService.rotarToken(
        nuevoToken: nuevoTokenPrueba,
        motivo: 'Rotación por prueba unitaria',
      );

      expect(resultado, equals(nuevoTokenPrueba));

      final tokenActivo = await GestoPagoService.obtenerTokenValido();
      expect(tokenActivo, equals(nuevoTokenPrueba));
      expect(await GestoPagoService.esTokenExpirado(), isFalse);

      final tiempoRestante = await GestoPagoService.tiempoRestanteToken();
      expect(tiempoRestante.inHours, greaterThanOrEqualTo(23));

      final estado = await GestoPagoService.consultarEstadoToken();
      expect(estado['token'], equals(nuevoTokenPrueba));
      expect(estado['esExpirado'], isFalse);
    });

    test('Detecta correctamente token expirado (> 24 horas)', () async {
      SharedPreferences.setMockInitialValues({});
      await GestoPagoService.rotarToken(
        nuevoToken: 'token_vigente_prueba',
        motivo: 'Inicio',
      );

      await GestoPagoService.forzarExpiracionParaPruebas();

      final expirado = await GestoPagoService.esTokenExpirado();
      expect(expirado, isTrue);

      final tiempoRestante = await GestoPagoService.tiempoRestanteToken();
      expect(tiempoRestante, equals(Duration.zero));
    });

    test('Usa X-API-Key oficial de GestoPago por defecto y corrige hashes antiguos', () async {
      SharedPreferences.setMockInitialValues({
        'gestopago_certificado_dispositivo_v1':
            'c795d77ca00267baa9c258024b159f35bbaef4855ccb24c2c7929c4afc41ec9e',
      });

      final cert = await GestoPagoService.obtenerCertificadoActivo();
      expect(cert, equals('YSX1HpAFum4TpCecyFBxs4eIjAlbhKqK6fpcSQp8'));
    });
  });

  group('GestoPagoTxResponse - XML Oficial de Transacción (<RESPONSE>)', () {
    test('Parsea exactamente el XML oficial devuelto por GestoPago', () {
      const xmlOficialGestoPago = '''<?xml version='1.0' encoding='UTF-8'?>
<RESPONSE>
    <ID_TX>949515254</ID_TX>
    <NUM_AUTORIZACION>100020492</NUM_AUTORIZACION>
    <SALDO>42999.89</SALDO>
    <COMISION>7.0</COMISION>
    <SALDO_F>42,999.89</SALDO_F>
    <COMISION_F>7.0</COMISION_F>
    <FECHA>28/Oct/2026 19:16:35</FECHA>
    <MONTO>10.0</MONTO>
    <MENSAJE>
        <CODIGO>01</CODIGO>
        <TEXTO>Operacion realizada con exito</TEXTO>
        <REFERENCIA>1111111111</REFERENCIA>
    </MENSAJE>
</RESPONSE>''';

      final tx = GestoPagoTxResponse.fromXmlString(xmlOficialGestoPago);

      expect(tx.idTx, equals('949515254'));
      expect(tx.numAutorizacion, equals('100020492'));
      expect(tx.saldo, equals(42999.89));
      expect(tx.comision, equals(7.0));
      expect(tx.saldoFormateado, equals('42,999.89'));
      expect(tx.comisionFormateada, equals('7.0'));
      expect(tx.fecha, equals('28/Oct/2026 19:16:35'));
      expect(tx.monto, equals(10.0));
      expect(tx.codigoMensaje, equals('01'));
      expect(tx.textoMensaje, equals('Operacion realizada con exito'));
      expect(tx.referencia, equals('1111111111'));
      expect(tx.esExitosa, isTrue);
    });
  });

  group('GestoPagoTicketDialog UI (Comprobante de pago)', () {
    testWidgets('Renderiza exactamente los elementos visuales solicitados (Comprobante de pago)', (WidgetTester tester) async {
      final datosPrueba = {
        'exito': true,
        'idTx': '949515254',
        'numeroAutorizacion': '100020492',
        'servicio': 'Telcel',
        'producto': 'Telcel 10',
        'referencia': '1111111111',
        'esRecarga': true,
        'fechaGestoPago': '28/Oct/2026 19:16:35',
        'comisionProveedorXml': 7.0,
        'saldoProveedorXml': 42999.89,
        'monto': 10.0,
        'xmlOficial': '<RESPONSE><ID_TX>949515254</ID_TX></RESPONSE>',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: GestoPagoTicketDialog(datosTicket: datosPrueba),
        ),
      );

      expect(find.text('Comprobante de pago'), findsOneWidget);
      expect(find.text('¡Pago exitoso!'), findsOneWidget);
      expect(find.text('Folio: 949515254'), findsOneWidget);
      expect(find.text('Servicio'), findsOneWidget);
      expect(find.text('Telcel'), findsOneWidget);
      expect(find.text('Producto'), findsOneWidget);
      expect(find.text('Telcel 10'), findsOneWidget);
      expect(find.text('Teléfono'), findsOneWidget);
      expect(find.text('1111111111'), findsOneWidget);
      expect(find.text('Fecha'), findsOneWidget);
      expect(find.text('28/Oct/2026 19:16:35'), findsOneWidget);
      expect(find.text('Autorización'), findsOneWidget);
      expect(find.text('100020492'), findsOneWidget);
      expect(find.text('Comisión'), findsOneWidget);
      expect(find.text('\$7.00'), findsOneWidget);
      expect(find.text('Saldo restante'), findsOneWidget);
      expect(find.text('\$42999.89'), findsOneWidget);
      expect(find.text('Total pagado'), findsOneWidget);
      expect(find.text('\$10.00'), findsOneWidget);
      expect(find.text('VOLVER AL CATÁLOGO'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
