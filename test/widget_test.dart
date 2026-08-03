import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coasterna_project/main.dart';

void main() {
  testWidgets('App builds without throwing an exception',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MyApp());
        await tester.pump();

        // We only check that MaterialApp exists — not specific text —
        // because the home screen's content will keep changing as more
        // screens are built. A test checking exact text would break
        // again with every new screen.
        expect(find.byType(MaterialApp), findsOneWidget);
      });
}