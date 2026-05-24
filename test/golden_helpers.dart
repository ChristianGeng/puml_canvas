import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

/// Renders a PumlView inside a deterministic test harness for golden tests.
///
/// The harness pins the surface size, disables Material chrome, and forces
/// LTR text direction so the only thing that varies across runs is the
/// diagram itself.
Widget pumlGoldenHarness(String source, {Size size = const Size(640, 480)}) {
  return Center(
    child: SizedBox.fromSize(
      size: size,
      child: ColoredBox(
        color: const Color(0xFFFFFFFF),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PumlView(source: source),
        ),
      ),
    ),
  );
}

Future<void> expectPumlGolden(
  WidgetTester tester,
  String source,
  String goldenName, {
  Size size = const Size(640, 480),
}) async {
  await tester.pumpWidget(pumlGoldenHarness(source, size: size));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(PumlView),
    matchesGoldenFile('golden/$goldenName.png'),
  );
}
