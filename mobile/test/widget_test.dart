import 'package:flutter_test/flutter_test.dart';

import 'package:medtrack/app/app.dart';

void main() {
  testWidgets('shows the login screen on first launch', (tester) async {
    await tester.pumpWidget(const MedTrackApp(apiBaseUrl: 'http://localhost:3000/v1'));

    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
  });
}
