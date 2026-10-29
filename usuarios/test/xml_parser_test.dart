import 'package:flutter_test/flutter_test.dart';
import 'package:usuarios/models/producto_xml_model.dart';

void main() {
  test('Prueba de Deserialización de Respuesta XML a Objetos Dart', () {
    const xmlSample = '''<?xml version='1.0' encoding='UTF-8'?>
<RESPONSE>
    <MENSAJE>
        <CODIGO>01</CODIGO>
        <TEXTO>Operacion realizada con exito</TEXTO>
    </MENSAJE>
    <PRODUCTOS>
        <producto servicio='ABIB' producto='ABIB 100' idServicio='2284' idProducto='14302' idCatTipoServicio='13' tipoFront='1' hasDigitoVerificador='false' precio='100.0' showAyuda='false' tipoReferencia='a'>
            <legend>
                <![CDATA[Recibe soporte las 24h del dia marcando desde tu telefono al *787]]>
            </legend>
        </producto>
        <producto servicio='Amazon' producto='Amazon \$100' idServicio='71' idProducto='200' idCatTipoServicio='10' tipoFront='1' hasDigitoVerificador='true' precio='100.0' showAyuda='false' tipoReferencia='a'>
            <legend>
                <![CDATA[Para usar tu tarjeta ingresa a www.amazon.com.mx]]>
            </legend>
        </producto>
    </PRODUCTOS>
</RESPONSE>''';

    final respuesta = RespuestaXml.fromXmlString(xmlSample);

    expect(respuesta.mensaje.codigo, equals('01'));
    expect(respuesta.mensaje.texto, equals('Operacion realizada con exito'));
    expect(respuesta.productos.length, equals(2));

    final p1 = respuesta.productos[0];
    expect(p1.servicio, equals('ABIB'));
    expect(p1.producto, equals('ABIB 100'));
    expect(p1.idProducto, equals(14302));
    expect(p1.precio, equals(100.0));
    expect(p1.hasDigitoVerificador, isFalse);
    expect(p1.legend, contains('Recibe soporte las 24h'));

    // Verificar conversión a Map para sqflite
    final map = p1.toMap();
    expect(map['idProducto'], equals(14302));
    expect(map['servicio'], equals('ABIB'));
    expect(map['hasDigitoVerificador'], equals(0));

    // Reconstruir desde Map de sqflite
    final p1FromMap = ProductoXml.fromMap(map);
    expect(p1FromMap.idProducto, equals(14302));
    expect(p1FromMap.servicio, equals('ABIB'));
    expect(p1FromMap.hasDigitoVerificador, isFalse);
  });
}
