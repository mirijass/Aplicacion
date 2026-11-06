import 'package:xml/xml.dart';

/// Modelo oficial de la respuesta XML de transacción de GestoPago (`<RESPONSE>`)
/// Basado en la especificación oficial de GESTO PAGO DE SERVICIOS / PUNTORED
class GestoPagoTxResponse {
  final String idTx;
  final String numAutorizacion;
  final double saldo;
  final double comision;
  final String saldoFormateado;
  final String comisionFormateada;
  final String fecha;
  final double monto;
  final String codigoMensaje;
  final String textoMensaje;
  final String referencia;
  final String pin;
  final String legend;
  final String xmlRaw;

  GestoPagoTxResponse({
    required this.idTx,
    required this.numAutorizacion,
    required this.saldo,
    required this.comision,
    required this.saldoFormateado,
    required this.comisionFormateada,
    required this.fecha,
    required this.monto,
    required this.codigoMensaje,
    required this.textoMensaje,
    required this.referencia,
    this.pin = '',
    this.legend = '',
    required this.xmlRaw,
  });

  bool get esExitosa =>
      codigoMensaje == '01' || codigoMensaje == '1' || codigoMensaje == '00';

  /// Deserializa desde una cadena de texto XML oficial de GestoPago
  factory GestoPagoTxResponse.fromXmlString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final responseElement = document.rootElement;
    final mensajeNode = responseElement.findElements('MENSAJE').firstOrNull;

    final idTxRoot = responseElement.findElements('ID_TX').firstOrNull?.innerText.trim() ?? '';
    final idTxMsg = mensajeNode?.findElements('ID_TX').firstOrNull?.innerText.trim() ?? '';
    final idTx = idTxRoot.isNotEmpty ? idTxRoot : idTxMsg;

    final numAutRoot = responseElement.findElements('NUM_AUTORIZACION').firstOrNull?.innerText.trim() ?? '';
    final numAutMsg = mensajeNode?.findElements('NUM_AUTORIZACION').firstOrNull?.innerText.trim() ?? '';
    final numAut = numAutRoot.isNotEmpty ? numAutRoot : numAutMsg;

    final saldoRootStr = responseElement.findElements('SALDO').firstOrNull?.innerText.trim() ?? '';
    final saldoMsgStr = mensajeNode?.findElements('SALDO').firstOrNull?.innerText.trim() ?? '';
    final saldo = double.tryParse(saldoRootStr.isNotEmpty ? saldoRootStr : saldoMsgStr) ?? 0.0;

    final comision = double.tryParse(responseElement.findElements('COMISION').firstOrNull?.innerText.trim() ?? '0') ?? 0.0;
    final saldoF = responseElement.findElements('SALDO_F').firstOrNull?.innerText.trim() ?? '';
    final comisionF = responseElement.findElements('COMISION_F').firstOrNull?.innerText.trim() ?? '';
    final fecha = responseElement.findElements('FECHA').firstOrNull?.innerText.trim() ?? '';
    final monto = double.tryParse(responseElement.findElements('MONTO').firstOrNull?.innerText.trim() ?? '0') ?? 0.0;

    final codigo = mensajeNode?.findElements('CODIGO').firstOrNull?.innerText.trim() ?? '';
    final texto = mensajeNode?.findElements('TEXTO').firstOrNull?.innerText.trim() ?? '';
    final ref = mensajeNode?.findElements('REFERENCIA').firstOrNull?.innerText.trim() ?? '';

    final pinMsg = mensajeNode?.findElements('PIN').firstOrNull?.innerText.trim() ?? '';
    final pinRoot = responseElement.findElements('PIN').firstOrNull?.innerText.trim() ?? '';
    final pin = pinMsg.isNotEmpty ? pinMsg : pinRoot;

    final legendMsg = mensajeNode?.findElements('legend').firstOrNull?.innerText.trim() ?? '';
    final legendRoot = responseElement.findElements('legend').firstOrNull?.innerText.trim() ?? '';
    final legend = legendMsg.isNotEmpty ? legendMsg : legendRoot;

    return GestoPagoTxResponse(
      idTx: idTx,
      numAutorizacion: numAut,
      saldo: saldo,
      comision: comision,
      saldoFormateado: saldoF.isNotEmpty ? saldoF : _formatCurrency(saldo),
      comisionFormateada: comisionF.isNotEmpty ? comisionF : comision.toStringAsFixed(2),
      fecha: fecha,
      monto: monto,
      codigoMensaje: codigo,
      textoMensaje: texto,
      referencia: ref,
      pin: pin,
      legend: legend,
      xmlRaw: xmlString,
    );
  }

  /// Construye un documento XML con el formato oficial de GestoPago (`<RESPONSE>`)
  static String buildOfficialXml({
    required String idTx,
    required String numAutorizacion,
    required double saldo,
    required double comision,
    required double monto,
    required String fecha,
    String referencia = '',
    String? pin,
    String? legend,
    String codigo = '01',
    String texto = 'Operacion realizada con exito',
  }) {
    final saldoStr = saldo.toStringAsFixed(2);
    final saldoFStr = _formatCurrency(saldo);
    final comisionStr = comision.toStringAsFixed(comision == comision.roundToDouble() ? 1 : 2);
    final montoStr = monto.toStringAsFixed(1);
    final pinXml = (pin != null && pin.isNotEmpty) ? '\n        <PIN>$pin</PIN>' : '';
    final legendXml = (legend != null && legend.isNotEmpty)
        ? '\n        <legend><![CDATA[$legend]]></legend>'
        : '';
    final refXml = referencia.isNotEmpty ? '\n        <REFERENCIA>$referencia</REFERENCIA>' : '';

    return '''<RESPONSE>
    <ID_TX>$idTx</ID_TX>
    <NUM_AUTORIZACION>$numAutorizacion</NUM_AUTORIZACION>
    <SALDO>$saldoStr</SALDO>
    <COMISION>$comisionStr</COMISION>
    <SALDO_F>$saldoFStr</SALDO_F>
    <COMISION_F>$comisionStr</COMISION_F>
    <FECHA>$fecha</FECHA>
    <MONTO>$montoStr</MONTO>
    <MENSAJE>
        <CODIGO>$codigo</CODIGO>
        <TEXTO>$texto</TEXTO>$pinXml$legendXml$refXml
    </MENSAJE>
</RESPONSE>''';
  }

  /// Formatea la fecha y hora con el estándar oficial de GestoPago (ej. 28/Oct/2026 19:16:35)
  static String formatFechaGestoPago(DateTime date) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final dia = date.day.toString().padLeft(2, '0');
    final mes = meses[date.month - 1];
    final anio = date.year;
    final hora = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    final seg = date.second.toString().padLeft(2, '0');
    return '$dia/$mes/$anio $hora:$min:$seg';
  }

  /// Formateador de moneda con separador de comas para miles
  static String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = integerPart.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '$formattedInt.$decimalPart';
  }
}
