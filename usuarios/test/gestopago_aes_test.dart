import 'package:flutter_test/flutter_test.dart';
import 'package:encrypt/encrypt.dart' as enc;

void main() {
  test('AES-256-CBC encryption test matching GestoPago specs', () {
    final key = enc.Key.fromBase64("HPo7OLqB4Fkk4E2yGOtwqw8H5fHR9kNx67OR4g4UdlA=");
    final iv = enc.IV.fromBase64("p5ldmBPdd/9pjC0bDC/nSg==");
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final plain = "{'idProducto':582,'idServicio':133,'telefono':'5555555551','horaLocal':'20220101235900','upc':'UPC_Test_XX','unidad':'083'}";
    final encrypted = encrypter.encrypt(plain, iv: iv);

    expect(encrypted.base64.isNotEmpty, true);

    final decrypted = encrypter.decrypt(encrypted, iv: iv);
    expect(decrypted, equals(plain));
  });
}
