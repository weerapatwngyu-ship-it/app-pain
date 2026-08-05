import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medtrack/features/auth/presentation/sign_in_screen.dart';

void main() {
  // MedTrackApp itself needs an initialized Supabase client, so the sign-in
  // screen is exercised directly — it only reaches Supabase on tap.
  testWidgets('offers Google as the way in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));

    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
  });

  testWidgets('explains why the user was returned to sign-in', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignInScreen(notice: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่')),
    );

    expect(find.text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่'), findsOneWidget);
  });
}
