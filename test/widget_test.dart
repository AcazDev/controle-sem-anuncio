import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:controle_remoto_app/main.dart';
import 'package:controle_remoto_app/about_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Smoke test inicial do Controle Remoto', (WidgetTester tester) async {
    // Configura SharedPreferences com valores mock
    SharedPreferences.setMockInitialValues({
      'has_seen_about_dialog_first_time': true,
      'setting_tv_brand': 'samsung',
      'setting_streaming_shortcuts': ['netflix', 'prime_video', 'globoplay'],
    });

    await tester.pumpWidget(const ControleRemotoApp());
    await tester.pumpAndSettle();

    expect(find.text('SAMSUNG'), findsOneWidget);
    expect(find.text('NETFLIX'), findsOneWidget);
  });

  testWidgets('Exibe diálogo Sobre na primeira execução', (WidgetTester tester) async {
    // Primeira abertura: has_seen_about_dialog_first_time não definido
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ControleRemotoApp());
    await tester.pumpAndSettle();

    expect(find.text('Sobre o Aplicativo'), findsOneWidget);
    expect(find.text('100% Gratuito & Sem Anúncios'), findsOneWidget);
  });
}
