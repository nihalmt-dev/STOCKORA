
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('STOCKORA basic widget test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('STOCKORA'),
          ),
        ),
      ),
    );

    expect(find.text('STOCKORA'), findsOneWidget);
  });
}
