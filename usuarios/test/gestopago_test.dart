import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usuarios/controllers/saldo_proveedor_controller.dart';
import 'package:usuarios/services/gestopago_service.dart';
import 'package:usuarios/models/gestopago_tx_response.dart';
import 'package:usuarios/views/gestopago_ticket_dialog.dart';

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
      expect(resultado['folioGestoPago'], isNotEmpty);
    });

    test('Valida restricciones de número telefónico (10 dígitos) y bloqueo por saldo insuficiente', () async {
      expect(GestoPagoService.validarNumeroTelefonico('5512345678'), isTrue);
      expect(GestoPagoService.validarNumeroTelefonico('12345'), isFalse);
      expect(GestoPagoService.validarNumeroTelefonico('0012345678'), isFalse);
      expect(GestoPagoService.validarNumeroTelefonico('55123abcde'), isFalse);

      final recargas = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.recargas,
      );
      final recarga = recargas.first;

      // Rechazar recarga con número inválido
      final telInvalido = await GestoPagoService.procesarTransaccion(
        servicio: recarga,
        referencia: '12345',
        monto: 50.0,
        metodoPago: 'Saldo con Proveedor',
        usarSaldoProveedor: true,
      );
      expect(telInvalido['exito'], isFalse);

      // Rechazar compra cuando el saldo es insuficiente ($0.00)
      final saldoCtrl = SaldoProveedorController();
      await saldoCtrl.reiniciarSaldoPruebas(nuevoSaldo: 0.0);

      final sinSaldo = await GestoPagoService.procesarTransaccion(
        servicio: recarga,
        referencia: '5512345678',
        monto: 50.0,
        metodoPago: 'Saldo con Proveedor',
        usarSaldoProveedor: true,
      );
      expect(sinSaldo['exito'], isFalse);
      expect(sinSaldo['mensaje'], contains('Saldo insuficiente'));
    });

    test('Procesa recarga telefónica exitosa generando número de autorización oficial', () async {
      final saldoCtrl = SaldoProveedorController();
      await saldoCtrl.reiniciarSaldoPruebas(nuevoSaldo: 1000.0);

      final recargas = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.recargas,
      );
      final recarga = recargas.first;

      final resultado = await GestoPagoService.procesarTransaccion(
        servicio: recarga,
        referencia: '5512345678',
        monto: 50.0,
        metodoPago: 'Saldo con Proveedor',
        usarSaldoProveedor: true,
      );

      expect(resultado['exito'], isTrue);
      expect(resultado['numeroAutorizacion'], isNotNull);
      final aut = resultado['numeroAutorizacion'] as String;
      expect(aut.length, equals(10));
      expect(int.tryParse(aut), isNotNull);
      expect(resultado['esRecarga'], isTrue);
      expect(resultado['folioGestoPago'], isNotEmpty);
    });

    test('formatearNumeroAutorizacion garantiza exactamente 10 dígitos', () {
      // 10 dígitos exactos se mantienen
      expect(GestoPagoService.formatearNumeroAutorizacion('1234567890'), equals('1234567890'));

      // Menos de 10 dígitos se rellenan con ceros a la izquierda a 10 dígitos
      expect(GestoPagoService.formatearNumeroAutorizacion('45678'), equals('0000045678'));

      // Más de 10 dígitos o con prefijos de texto extraen los 10 dígitos
      expect(GestoPagoService.formatearNumeroAutorizacion('AUT-9876543210'), equals('9876543210'));
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

  group('GestoPagoService - Rotación y Validación de Token (24 Horas)', () {
    test('Obtiene token inicial y establece periodo de vigencia de 24 horas', () async {
      SharedPreferences.setMockInitialValues({});

      final token = await GestoPagoService.obtenerTokenValido();
      expect(token, equals(GestoPagoService.defaultBearerToken));

      final expirado = await GestoPagoService.esTokenExpirado();
      expect(expirado, isFalse);

      final tiempoRestante = await GestoPagoService.tiempoRestanteToken();
      expect(tiempoRestante.inHours, greaterThanOrEqualTo(23));
      expect(tiempoRestante.inMinutes, greaterThan(0));
    });

    test('Detecta correctamente token expirado (> 24 horas)', () async {
      SharedPreferences.setMockInitialValues({});
      await GestoPagoService.obtenerTokenValido();

      // Forzar expiración simulando más de 24 horas transcurridas
      await GestoPagoService.forzarExpiracionParaPruebas();

      final expirado = await GestoPagoService.esTokenExpirado();
      expect(expirado, isTrue);

      final tiempoRestante = await GestoPagoService.tiempoRestanteToken();
      expect(tiempoRestante, equals(Duration.zero));
    });

    test('obtenerTokenValido() rota automáticamente si el token está expirado', () async {
      SharedPreferences.setMockInitialValues({});
      await GestoPagoService.obtenerTokenValido();

      // Simular expiración (>24h)
      await GestoPagoService.forzarExpiracionParaPruebas();
      expect(await GestoPagoService.esTokenExpirado(), isTrue);

      // Al solicitar token válido, debe rotar automáticamente
      final tokenValido = await GestoPagoService.obtenerTokenValido();
      expect(tokenValido, isNotEmpty);

      // Ahora debe estar nuevamente vigente por 24 horas
      expect(await GestoPagoService.esTokenExpirado(), isFalse);
      final nuevoRestante = await GestoPagoService.tiempoRestanteToken();
      expect(nuevoRestante.inHours, greaterThanOrEqualTo(23));
    });

    test('Rotar token manualmente actualiza token y reinicia vigencia de 24h', () async {
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

      final estado = await GestoPagoService.consultarEstadoToken();
      expect(estado['token'], equals(nuevoTokenPrueba));
      expect(estado['esExpirado'], isFalse);
      expect(estado['tokenEnmascarado'], contains('...'));
      expect((estado['historial'] as List).isNotEmpty, isTrue);
    });

    test('Sincronización online detecta token y reporta estado de rotación', () async {
      SharedPreferences.setMockInitialValues({});
      final resultado = await GestoPagoService.sincronizarConApiOnline();

      expect(resultado['exito'], isTrue);
      expect(resultado['totalProductos'], greaterThan(0));
      expect(resultado['tokenRotado'], isA<bool>());
    });

    test('Gestiona y almacena el Certificado oficial de comercio (X-API-Key)', () async {
      SharedPreferences.setMockInitialValues({});

      // Certificado por defecto provisto por el usuario
      final cert = await GestoPagoService.obtenerCertificadoActivo();
      expect(cert, equals('c795d77ca00267baa9c258024b159f35bbaef4855ccb24c2c7929c4afc41ec9e'));

      // Modificación de certificado
      await GestoPagoService.guardarCertificado('nuevo_certificado_99999999');
      final certModificado = await GestoPagoService.obtenerCertificadoActivo();
      expect(certModificado, equals('nuevo_certificado_99999999'));

      final estado = await GestoPagoService.consultarEstadoToken();
      expect(estado['certificado'], equals('nuevo_certificado_99999999'));
    });
  });

  group('GestoPagoTxResponse - XML Oficial de Transacción (<RESPONSE>)', () {
    test('Parsea exactamente el XML oficial devuelto por GestoPago', () {
      const xmlOficialGestoPago = '''<?xml version='1.0' encoding='UTF-8'?>
<RESPONSE>
    <ID_TX>291437188</ID_TX>
    <NUM_AUTORIZACION>100024988</NUM_AUTORIZACION>
    <SALDO>157731.83</SALDO>
    <COMISION>0.7</COMISION>
    <SALDO_F>157,731.83</SALDO_F>
    <COMISION_F>0.7</COMISION_F>
    <FECHA>25/Feb/2022 18:15:25</FECHA>
    <MONTO>10.0</MONTO>
    <MENSAJE>
        <CODIGO>01</CODIGO>
        <TEXTO>Operacion realizada con exito</TEXTO>
        <REFERENCIA></REFERENCIA>
    </MENSAJE>
</RESPONSE>''';

      final tx = GestoPagoTxResponse.fromXmlString(xmlOficialGestoPago);

      expect(tx.idTx, equals('291437188'));
      expect(tx.numAutorizacion, equals('100024988'));
      expect(tx.saldo, equals(157731.83));
      expect(tx.comision, equals(0.7));
      expect(tx.saldoFormateado, equals('157,731.83'));
      expect(tx.comisionFormateada, equals('0.7'));
      expect(tx.fecha, equals('25/Feb/2022 18:15:25'));
      expect(tx.monto, equals(10.0));
      expect(tx.codigoMensaje, equals('01'));
      expect(tx.textoMensaje, equals('Operacion realizada con exito'));
      expect(tx.esExitosa, isTrue);
    });

    test('procesarTransaccion incluye xmlOficial con la estructura exacta <RESPONSE>', () async {
      final saldoCtrl = SaldoProveedorController();
      await saldoCtrl.reiniciarSaldoPruebas(nuevoSaldo: 1000.0);

      final recargas = await GestoPagoService.obtenerServiciosPorSeccion(
        seccion: SeccionGestoPago.recargas,
      );
      final recarga = recargas.first;

      final res = await GestoPagoService.procesarTransaccion(
        servicio: recarga,
        referencia: '5512345678',
        monto: 20.0,
        metodoPago: 'Saldo con Proveedor',
        usarSaldoProveedor: true,
      );

      expect(res['exito'], isTrue);
      expect(res['xmlOficial'], isNotNull);
      final xml = res['xmlOficial'] as String;
      expect(xml, contains('<RESPONSE>'));
      expect(xml, contains('<ID_TX>'));
      expect(xml, contains('<NUM_AUTORIZACION>'));
      expect(xml, contains('<SALDO>'));
      expect(xml, contains('<COMISION>'));
      expect(xml, contains('<FECHA>'));
      expect(xml, contains('<MONTO>'));
      expect(xml, contains('<MENSAJE>'));
      expect(xml, contains('<CODIGO>01</CODIGO>'));
      expect(xml, contains('<TEXTO>Operacion realizada con exito</TEXTO>'));

      // Validación de 10 dígitos obligatorios en NUM_AUTORIZACION según exigencia del docente
      final aut = res['numeroAutorizacion'] as String;
      expect(aut.length, equals(10));
      expect(xml, contains('<NUM_AUTORIZACION>$aut</NUM_AUTORIZACION>'));
    });

    test('cifrarPayloadAes genera payload cifrado en AES-256-CBC compatible con sendTx.do', () {
      const payload = '{"idProducto":582,"idServicio":133,"telefono":"5555555551"}';
      final cifrado = GestoPagoService.cifrarPayloadAes(payload);
      expect(cifrado.isNotEmpty, isTrue);
    });
  });

  group('GestoPagoTicketDialog UI (Comprobante de pago)', () {
    testWidgets('Renderiza exactamente los elementos visuales solicitados (Comprobante de pago)', (WidgetTester tester) async {
      final datosPrueba = {
        'exito': true,
        'idTx': '949515254',
        'numeroAutorizacion': '1000204920',
        'servicio': 'Telcel',
        'producto': 'Telcel 10',
        'referencia': '1111111111',
        'esRecarga': true,
        'fechaGestoPago': '28/Oct/2026 19:16:35',
        'comisionFormateadaXml': '7.00',
        'saldoFormateadoXml': '42999.89',
        'monto': 10.0,
        'xmlOficial': '<RESPONSE><ID_TX>949515254</ID_TX></RESPONSE>',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: GestoPagoTicketDialog(datosTicket: datosPrueba),
        ),
      );

      // Verificación de elementos clave
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
      expect(find.text('1000204920'), findsOneWidget);
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

