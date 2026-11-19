import 'dart:io';

/// Permite cargar imágenes desde cualquier servidor HTTP/HTTPS en dispositivos físicos sin bloqueos de certificados
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

/// Configura HttpOverrides para plataformas móviles y de escritorio (Android, iOS, Windows, Linux, macOS)
void setupHttpOverrides() {
  HttpOverrides.global = MyHttpOverrides();
}
