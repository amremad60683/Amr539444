import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show makeApp, wrap, phone, settle;

void main() {
  testWidgets('switching to English from the profile works without overflow', (tester) async {
    phone(tester);
    final app = await makeApp();
    await app.completeOnboarding(name: 'Amr', balance: 1000, minDaily: 150, maxDaily: 250, lang: 'ar');
    await tester.pumpWidget(wrap(app));
    await settle(tester);
    await tester.tap(find.text('حسابي').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('اللغة'), 300);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اللغة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(app.settings.lang, 'en');
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Profile'), findsWidgets);
  });
}
