import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_teacher/app/theme.dart';
import 'package:ai_teacher/features/splash/splash_screen.dart';

void main() {
  testWidgets('App renders splash screen with AI Teacher title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'pref_onboarding_completed': true});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          '/home': (_) => const Scaffold(body: Text('Home Screen')),
          '/model_setup': (_) => const Scaffold(body: Text('Setup Screen')),
        },
      ),
    );

    // Verify AI Teacher and tagline text
    expect(find.text('AI Teacher'), findsOneWidget);
    expect(find.text('Your Personal Offline Exam Tutor'), findsOneWidget);
    expect(find.byIcon(Icons.school), findsOneWidget);

    // Drain the delayed timer so test framework closes cleanly
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
