import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void main() {
  group('PumlView', () {
    testWidgets('renders empty diagram without throwing', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: PumlView(source: '@startuml\n@enduml\n'),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a single-message sequence diagram', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: PumlView(source: '@startuml\nA -> B : hello\n@enduml\n'),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('uses errorBuilder for malformed source', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: PumlView(
          source: '@startuml\nA B\n@enduml\n',
          errorBuilder: (_, err) => Text('ERR: $err'),
        ),
      ));
      expect(find.textContaining('ERR:'), findsOneWidget);
    });

    testWidgets('renders a message with inline formatting without throwing',
        (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: PumlView(
          source: '@startuml\n'
              'A -> B : <b>bold</b> and <color:red>red</color>\n'
              '@enduml\n',
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('renders a diagram with !include via fileLoader',
        (tester) async {
      String loader(String path) {
        if (path == 'shared.puml') {
          return 'A -> B : from include\n';
        }
        throw StateError('unexpected path: $path');
      }

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: PumlView(
          source: '@startuml\n!include shared.puml\n@enduml\n',
          fileLoader: loader,
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}
