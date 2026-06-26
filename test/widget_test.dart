import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/app.dart';

void main() {
  testWidgets('app renders without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CadenceApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
