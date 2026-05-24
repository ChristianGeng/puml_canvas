import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas_example/main.dart';

void main() {
  testWidgets('ExampleApp renders the sample diagram', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('puml_canvas'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
