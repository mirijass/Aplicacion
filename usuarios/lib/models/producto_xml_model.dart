import 'package:xml/xml.dart';

/// Modelo de Mensaje proveniente de la respuesta XML (<MENSAJE>)
class MensajeXml {
  final String codigo;
  final String texto;

  MensajeXml({required this.codigo, required this.texto});

  factory MensajeXml.fromXmlElement(XmlElement element) {
    final codigoNode = element.findElements('CODIGO').firstOrNull;
    final textoNode = element.findElements('TEXTO').firstOrNull;

    return MensajeXml(
      codigo: codigoNode?.innerText.trim() ?? '',
      texto: textoNode?.innerText.trim() ?? '',
    );
  }
}

/// Modelo de Producto proveniente de la respuesta XML (<producto>)
class ProductoXml {
  final int? idProducto;
  final String servicio;
  final String producto;
  final int? idServicio;
  final int? idCatTipoServicio;
  final int? tipoFront;
  final bool hasDigitoVerificador;
  final double precio;
  final bool showAyuda;
  final String tipoReferencia;
  final String legend;

  ProductoXml({
    this.idProducto,
    required this.servicio,
    required this.producto,
    this.idServicio,
    this.idCatTipoServicio,
    this.tipoFront,
    required this.hasDigitoVerificador,
    required this.precio,
    required this.showAyuda,
    required this.tipoReferencia,
    required this.legend,
  });

  /// Deserializar desde un elemento XML (<producto ...><legend>...</legend></producto>)
  factory ProductoXml.fromXmlElement(XmlElement element) {
    final legendNode = element.findElements('legend').firstOrNull;
    final legendText = legendNode?.innerText.trim() ?? '';

    return ProductoXml(
      idProducto: int.tryParse(element.getAttribute('idProducto') ?? ''),
      servicio: element.getAttribute('servicio') ?? '',
      producto: element.getAttribute('producto') ?? '',
      idServicio: int.tryParse(element.getAttribute('idServicio') ?? ''),
      idCatTipoServicio: int.tryParse(element.getAttribute('idCatTipoServicio') ?? ''),
      tipoFront: int.tryParse(element.getAttribute('tipoFront') ?? ''),
      hasDigitoVerificador: element.getAttribute('hasDigitoVerificador') == 'true',
      precio: double.tryParse(element.getAttribute('precio') ?? '0.0') ?? 0.0,
      showAyuda: element.getAttribute('showAyuda') == 'true',
      tipoReferencia: element.getAttribute('tipoReferencia') ?? '',
      legend: legendText,
    );
  }

  /// Convertir a Map para sqflite (SQLite no tiene tipo Boolean nativo, usa 1 o 0)
  Map<String, dynamic> toMap() {
    return {
      'idProducto': idProducto,
      'servicio': servicio,
      'producto': producto,
      'idServicio': idServicio,
      'idCatTipoServicio': idCatTipoServicio,
      'tipoFront': tipoFront,
      'hasDigitoVerificador': hasDigitoVerificador ? 1 : 0,
      'precio': precio,
      'showAyuda': showAyuda ? 1 : 0,
      'tipoReferencia': tipoReferencia,
      'legend': legend,
    };
  }

  /// Reconstruir desde un Map obtenido de sqflite
  factory ProductoXml.fromMap(Map<String, dynamic> map) {
    return ProductoXml(
      idProducto: map['idProducto'] as int?,
      servicio: map['servicio'] as String? ?? '',
      producto: map['producto'] as String? ?? '',
      idServicio: map['idServicio'] as int?,
      idCatTipoServicio: map['idCatTipoServicio'] as int?,
      tipoFront: map['tipoFront'] as int?,
      hasDigitoVerificador: (map['hasDigitoVerificador'] as int?) == 1,
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      showAyuda: (map['showAyuda'] as int?) == 1,
      tipoReferencia: map['tipoReferencia'] as String? ?? '',
      legend: map['legend'] as String? ?? '',
    );
  }

  /// URL de la imagen / logo oficial de la marca o servicio
  String get logoUrl {
    final s = servicio.toLowerCase();
    String domain = 'gestopago.com';
    if (s.contains('telcel')) {
      domain = 'telcel.com';
    } else if (s.contains('at&t') || s.contains('at-t') || s.contains('att')) {
      domain = 'att.com.mx';
    } else if (s.contains('movistar')) {
      domain = 'movistar.com.mx';
    } else if (s.contains('unefon')) {
      domain = 'unefon.com.mx';
    } else if (s.contains('bait')) {
      domain = 'mibait.com';
    } else if (s.contains('cfe')) {
      domain = 'cfe.mx';
    } else if (s.contains('aguakan')) {
      domain = 'aguakan.com';
    } else if (s.contains('saltillo')) {
      domain = 'aguasdesaltillo.com';
    } else if (s.contains('naturgy') || s.contains('gas')) {
      domain = 'naturgy.com.mx';
    } else if (s.contains('amazon')) {
      domain = 'amazon.com.mx';
    } else if (s.contains('netflix')) {
      domain = 'netflix.com';
    } else if (s.contains('spotify')) {
      domain = 'spotify.com';
    } else if (s.contains('playstation')) {
      domain = 'playstation.com';
    } else if (s.contains('xbox')) {
      domain = 'xbox.com';
    } else if (s.contains('nintendo')) {
      domain = 'nintendo.com';
    } else if (s.contains('cinepolis')) {
      domain = 'cinepolis.com';
    } else if (s.contains('cinemex')) {
      domain = 'cinemex.com';
    }
    return 'https://t2.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://$domain&size=128';
  }
}

/// Respuesta Global parseada desde la etiqueta raíz <RESPONSE>
class RespuestaXml {
  final MensajeXml mensaje;
  final List<ProductoXml> productos;

  RespuestaXml({required this.mensaje, required this.productos});

  factory RespuestaXml.fromXmlString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final responseElement = document.findElements('RESPONSE').first;

    final mensajeElement = responseElement.findElements('MENSAJE').first;
    final mensaje = MensajeXml.fromXmlElement(mensajeElement);

    final productosElement = responseElement.findElements('PRODUCTOS').first;
    final productos = productosElement
        .findElements('producto')
        .map((p) => ProductoXml.fromXmlElement(p))
        .toList();

    return RespuestaXml(mensaje: mensaje, productos: productos);
  }
}
