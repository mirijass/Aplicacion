import 'package:flutter_test/flutter_test.dart';
import 'package:usuarios/main.dart';
import 'package:usuarios/services/db_helper.dart';

void main() {
  setUpAll(() async {
    final dbHelper = DBHelper();
    await dbHelper.init();
  });

  testWidgets('App carga la pantalla de Login correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Gestión de Usuarios'), findsOneWidget);
    expect(find.textContaining('Iniciar Sesión'), findsWidgets);
    expect(find.text('Correo o Nombre de Usuario'), findsOneWidget);
  });
}
