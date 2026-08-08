import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medtrack/features/auth/presentation/sign_in_screen.dart';

void main() {
  // MedTrackApp itself needs an initialized Supabase client, so the sign-in
  // screen is exercised directly — it only reaches Supabase on submit.
  testWidgets('offers email/password sign-in by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));

    expect(find.text('เข้าสู่ระบบ'), findsWidgets);
    expect(find.text('ยังไม่มีบัญชี? สมัครสมาชิก'), findsOneWidget);
  });

  testWidgets('switches to the sign-up form', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));

    await tester.tap(find.text('ยังไม่มีบัญชี? สมัครสมาชิก'));
    await tester.pump();

    expect(find.text('สมัครสมาชิก'), findsWidgets);
    expect(find.text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'), findsOneWidget);
  });

  testWidgets('explains why the user was returned to sign-in', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignInScreen(notice: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่')),
    );

    expect(find.text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่'), findsOneWidget);
  });
}
