import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelimio_mobile/main.dart' as app;
import 'package:kelimio_mobile/presentation/screens/sign_in_screen.dart';
import 'package:kelimio_mobile/presentation/screens/splash_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a signed-out cold start reaches the sign-in screen', (
    tester,
  ) async {
    app.main();

    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline) &&
        find.byType(SignInScreen).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
