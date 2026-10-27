// Smoke test for the PetGuardian login screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petguardian/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // No stored uid -> LoginPage stays on the login screen.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('LoginPage renders when no user is logged in',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('PetGuardian'), findsOneWidget);
    expect(find.text('HOŞGELDİNİZ'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'E-posta'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Şifre'), findsOneWidget);
  });

  testWidgets('LoginPage validates empty credentials',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'GİRİŞ YAP'));
    await tester.pumpAndSettle();

    expect(find.text('E-posta adresinizi giriniz!'), findsOneWidget);
    expect(find.text('Şifrenizi giriniz!'), findsOneWidget);
  });

  // Regression: a stored uid used to be enough to skip login, which opened the
  // app with no Auth session and made every Firestore call fail.
  testWidgets('a stored uid without a live Auth session stays on login',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'uid': 'stale-uid',
      'user_token': 'user_token',
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // The login screen is still shown...
    expect(find.text('HOŞGELDİNİZ'), findsOneWidget);

    // ...and the stale credentials were cleared.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('uid'), isNull);
    expect(prefs.getString('user_token'), isNull);
  });
}