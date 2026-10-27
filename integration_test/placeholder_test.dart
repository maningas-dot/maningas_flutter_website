import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patient_portal_flutter/app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens the patient portal dashboard', (tester) async {
    await tester.pumpWidget(const PatientPortalApp());

    expect(find.text('Welcome back, James'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
  });
}
