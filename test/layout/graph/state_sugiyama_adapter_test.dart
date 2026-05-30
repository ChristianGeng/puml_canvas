import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';
import 'package:puml_canvas/src/layout/graph/state_sugiyama_adapter.dart';

class _FixedTextMeasurer implements TextMeasurer {
  const _FixedTextMeasurer();
  @override
  Size measure(String text, TextStyle style) {
    final fontSize = style.fontSize ?? 12;
    return Size(text.length * fontSize * 0.6, fontSize * 1.2);
  }
}

StateDiagram _parseStateDiagram(String source) {
  final tokens = Lexer().tokenize(source);
  final d = Parser().parse(tokens);
  if (d is! StateDiagram) {
    throw StateError('expected StateDiagram, got ${d.runtimeType}');
  }
  return d;
}

void main() {
  const measurer = _FixedTextMeasurer();

  group('layoutStateDiagramWithSugiyama', () {
    test('linear chain: every state is in the Scene and layers stack down',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> Idle\n'
        'Idle --> Running : start\n'
        'Running --> [*] : stop\n'
        '@enduml\n',
      );

      final scene =
          layoutStateDiagramWithSugiyama(diagram, measurer);

      expect(scene.size.width, greaterThan(0));
      expect(scene.size.height, greaterThan(0));

      // Every real state name must appear as a SceneRoundedBox label.
      final labels = <String>{
        for (final s in scene.shapes)
          if (s is SceneRoundedBox && s.label != null) s.label!,
      };
      expect(labels.contains('Idle'), isTrue);
      expect(labels.contains('Running'), isTrue);

      // Both pseudo states render as SceneCircle.
      final circles =
          scene.shapes.whereType<SceneCircle>().toList(growable: false);
      expect(circles.length, 2);
      // Final state is a ring; initial is a filled dot.
      final rings = circles.where((c) => c.ring).toList();
      expect(rings.length, 1);

      // Layer order: initial pseudo dot must sit above Idle, which sits above
      // Running, which sits above the final ring.
      final idle = scene.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((s) => s.label == 'Idle');
      final running = scene.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((s) => s.label == 'Running');
      final initialDot = circles.firstWhere((c) => !c.ring);
      final finalRing = rings.single;
      expect(initialDot.center.dy, lessThan(idle.rect.center.dy));
      expect(idle.rect.center.dy, lessThan(running.rect.center.dy));
      expect(running.rect.center.dy, lessThan(finalRing.center.dy));

      // One route per transition: 3 transitions -> at least 3 SceneLines
      // tipped with an open arrowhead (the final segment of each route).
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .length;
      expect(arrows, 3);
    });

    test('transition labels render as SceneText', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> A\n'
        'A --> B : go\n'
        'B --> [*]\n'
        '@enduml\n',
      );

      final scene =
          layoutStateDiagramWithSugiyama(diagram, measurer);

      final labels = scene.shapes
          .whereType<SceneText>()
          .map((t) => t.text)
          .toSet();
      expect(labels.contains('go'), isTrue);
    });

    test('composite state renders shell + inner rects + internal transition',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state Outer {\n'
        '  A --> B : go\n'
        '}\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final boxes = scene.shapes
          .whereType<SceneRoundedBox>()
          .toList(growable: false);
      // 1 outer shell (label null, header rendered as SceneText) + 2 inner
      // state rects.
      expect(boxes.length, 3);
      final innerLabels = boxes.map((b) => b.label).whereType<String>().toSet();
      expect(innerLabels.contains('A'), isTrue);
      expect(innerLabels.contains('B'), isTrue);

      // The shell is the box with a null label.
      final shells = boxes.where((b) => b.label == null).toList();
      expect(shells.length, 1);
      final outerBox = shells.single;
      final innerA = boxes.firstWhere((b) => b.label == 'A');
      final innerB = boxes.firstWhere((b) => b.label == 'B');
      expect(outerBox.rect.contains(innerA.rect.center), isTrue);
      expect(outerBox.rect.contains(innerB.rect.center), isTrue);
      expect(outerBox.rect.left, lessThan(innerA.rect.left));
      expect(outerBox.rect.right, greaterThan(innerB.rect.right));
      expect(outerBox.rect.top, lessThan(innerA.rect.top));

      // One title text for the cluster header.
      final titles = scene.shapes
          .whereType<SceneText>()
          .where((t) => t.text == 'Outer')
          .toList();
      expect(titles.length, 1);

      // Exactly one route (A -> B): one open arrowhead.
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .length;
      expect(arrows, 1);
    });

    test('nested composite: inner shell strictly inside outer shell', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state Outer {\n'
        '  state Inner {\n'
        '    A --> B\n'
        '  }\n'
        '}\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final boxes = scene.shapes
          .whereType<SceneRoundedBox>()
          .toList(growable: false);
      // 2 shells (Outer, Inner; both with null label — title is SceneText) +
      // 2 inner state rects (A, B).
      expect(boxes.length, 4);

      final shells = boxes.where((b) => b.label == null).toList();
      expect(shells.length, 2);
      // Outer shell strictly contains the inner shell — sort by area.
      shells.sort(
          (a, b) => (b.rect.width * b.rect.height).compareTo(a.rect.width * a.rect.height));
      final outerBox = shells.first;
      final innerBox = shells.last;
      // Inner shell must lie strictly inside the outer shell.
      expect(innerBox.rect.left, greaterThan(outerBox.rect.left));
      expect(innerBox.rect.top, greaterThan(outerBox.rect.top));
      expect(innerBox.rect.right, lessThan(outerBox.rect.right));
      expect(innerBox.rect.bottom, lessThan(outerBox.rect.bottom));

      // Both leaf states render inside the inner shell.
      final leafA = boxes.firstWhere((b) => b.label == 'A');
      final leafB = boxes.firstWhere((b) => b.label == 'B');
      expect(innerBox.rect.contains(leafA.rect.center), isTrue);
      expect(innerBox.rect.contains(leafB.rect.center), isTrue);

      // Two cluster titles rendered: "Outer" and "Inner".
      final titles = scene.shapes
          .whereType<SceneText>()
          .map((t) => t.text)
          .toSet();
      expect(titles.contains('Outer'), isTrue);
      expect(titles.contains('Inner'), isTrue);
    });

    test('cross-container transition lands on the nested state, not its shell',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state C {\n'
        '  B\n'
        '}\n'
        'A --> B : enter\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final boxes = scene.shapes
          .whereType<SceneRoundedBox>()
          .toList(growable: false);
      final a = boxes.firstWhere((b) => b.label == 'A');
      final b = boxes.firstWhere((b) => b.label == 'B');
      // C is the cluster shell (label null on the rounded box; title is
      // emitted as a SceneText). Pick the shell that contains B.
      final c = boxes.firstWhere((box) =>
          box.label == null && box.rect.contains(b.rect.center));

      // The route should have an arrow head landing on B's rect (the nested
      // node) rather than C's shell rect.
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .toList();
      expect(arrows.length, 1);
      final arrow = arrows.single;
      // The head endpoint must be within (or on the edge of) B's rect, not
      // strictly inside C's shell-only area.
      final headBox = b.rect.inflate(1.0);
      expect(headBox.contains(arrow.to), isTrue);

      // Tail of the route should touch A's rect. The route is a chain of
      // SceneLines; the last one has the arrowhead, the preceding ones are
      // body segments. Walk backwards from the arrow segment to find the
      // route's tail (a segment whose `from` is not the `to` of another
      // route segment).
      final routeSegments = <SceneLine>[];
      // Collect all SceneLines whose endpoints chain into `arrow.to`.
      // Easiest: filter to lines that share endpoints with the arrow segment
      // by stepping backwards along the chain.
      var current = arrow;
      routeSegments.add(current);
      final allRouteCandidates = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == null)
          .toList(growable: false);
      while (true) {
        SceneLine? prev;
        for (final seg in allRouteCandidates) {
          if (seg.to == current.from) {
            prev = seg;
            break;
          }
        }
        if (prev == null) break;
        routeSegments.add(prev);
        current = prev;
      }
      final routeStart = routeSegments.last;
      final tailBox = a.rect.inflate(1.0);
      expect(tailBox.contains(routeStart.from), isTrue);

      // C's shell should contain B but not A.
      expect(c.rect.contains(b.rect.center), isTrue);
      expect(c.rect.contains(a.rect.center), isFalse);
    });

    test('dotted-name nesting: composites A and B with cross transitions', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state A.X\n'
        'state A.Y\n'
        'state B.Z\n'
        'X --> Z\n'
        'Z --> Y\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final boxes = scene.shapes
          .whereType<SceneRoundedBox>()
          .toList(growable: false);
      // Leaf states X, Y, Z render as labelled rects.
      final x = boxes.firstWhere((b) => b.label == 'X');
      final y = boxes.firstWhere((b) => b.label == 'Y');
      final z = boxes.firstWhere((b) => b.label == 'Z');

      // Two composite shells (null label) with header texts 'A' and 'B'.
      final headers = scene.shapes
          .whereType<SceneText>()
          .map((t) => t.text)
          .toSet();
      expect(headers.contains('A'), isTrue);
      expect(headers.contains('B'), isTrue);

      // A's shell contains X and Y; B's shell contains Z.
      final shellA = boxes.firstWhere(
          (b) => b.label == null && b.rect.contains(x.rect.center));
      expect(shellA.rect.contains(y.rect.center), isTrue);
      expect(shellA.rect.contains(z.rect.center), isFalse);
      final shellB = boxes.firstWhere(
          (b) => b.label == null && b.rect.contains(z.rect.center));
      expect(shellB.rect.contains(x.rect.center), isFalse);
      expect(shellB.rect.contains(y.rect.center), isFalse);

      // Cross-composite routes X->Z and Z->Y exist (two open arrowheads).
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .toList();
      expect(arrows.length, 2);
      bool nearRect(Offset p, Rect r) => r.inflate(2.0).contains(p);
      // One arrow tip lands on Z (X->Z), another on Y (Z->Y).
      expect(arrows.any((a) => nearRect(a.to, z.rect)), isTrue);
      expect(arrows.any((a) => nearRect(a.to, y.rect)), isTrue);
    });

    test('leaf state with a single description: shell + title + divider + desc',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'A : does X\n'
        '[*] --> A\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      // Exactly one state rect for A (the [*] pseudo renders as a circle, not
      // a rounded box).
      final aBoxes = scene.shapes
          .whereType<SceneRoundedBox>()
          .toList(growable: false);
      expect(aBoxes.length, 1);
      final aBox = aBoxes.single;
      // When descriptions are present the rect carries no label — the title
      // is emitted as a separate SceneText so we can draw a divider below it.
      expect(aBox.label, isNull);

      final titleText = scene.shapes
          .whereType<SceneText>()
          .firstWhere((t) => t.text == 'A');
      final descText = scene.shapes
          .whereType<SceneText>()
          .firstWhere((t) => t.text == 'does X');

      // Description sits below the title within the rect.
      expect(titleText.offset.dy, lessThan(descText.offset.dy));
      expect(aBox.rect.top, lessThanOrEqualTo(titleText.offset.dy));
      expect(descText.offset.dy, lessThan(aBox.rect.bottom));

      // One horizontal divider line spanning the rect width, between title
      // and description.
      final dividers = scene.shapes
          .whereType<SceneLine>()
          .where((l) =>
              l.head == null &&
              l.from.dy == l.to.dy &&
              (l.from.dx - aBox.rect.left).abs() < 0.001 &&
              (l.to.dx - aBox.rect.right).abs() < 0.001)
          .toList();
      expect(dividers.length, 1);
      final divider = dividers.single;
      expect(divider.from.dy, greaterThan(titleText.offset.dy));
      expect(divider.from.dy, lessThan(descText.offset.dy));
    });

    test('leaf state with three descriptions: ordered stack below title', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'A : first\n'
        'A : second\n'
        'A : third\n'
        '[*] --> A\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final descTexts = scene.shapes
          .whereType<SceneText>()
          .where((t) =>
              t.text == 'first' || t.text == 'second' || t.text == 'third')
          .toList();
      expect(descTexts.length, 3);

      final first = descTexts.firstWhere((t) => t.text == 'first');
      final second = descTexts.firstWhere((t) => t.text == 'second');
      final third = descTexts.firstWhere((t) => t.text == 'third');

      // Stacked vertically in declaration order.
      expect(first.offset.dy, lessThan(second.offset.dy));
      expect(second.offset.dy, lessThan(third.offset.dy));

      // All three share the same left edge (left-aligned).
      expect(first.offset.dx, second.offset.dx);
      expect(second.offset.dx, third.offset.dx);

      // All three fall within the state's rect.
      final aBox = scene.shapes.whereType<SceneRoundedBox>().single;
      expect(aBox.rect.top, lessThan(first.offset.dy));
      expect(third.offset.dy, lessThan(aBox.rect.bottom));
    });

    test('descriptions widen the rect when description is the longest line',
        () {
      final withoutDesc = _parseStateDiagram(
        '@startuml\n'
        'A\n'
        '[*] --> A\n'
        '@enduml\n',
      );
      final withDesc = _parseStateDiagram(
        '@startuml\n'
        'A : this description is much wider than A\n'
        '[*] --> A\n'
        '@enduml\n',
      );

      final sceneNarrow = layoutStateDiagramWithSugiyama(withoutDesc, measurer);
      final sceneWide = layoutStateDiagramWithSugiyama(withDesc, measurer);

      final narrowBox = sceneNarrow.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((b) => b.label == 'A' || b.label == null);
      final wideBox = sceneWide.shapes.whereType<SceneRoundedBox>().single;

      expect(wideBox.rect.width, greaterThan(narrowBox.rect.width));
    });

    test('z-order: all cluster shells come before all edge route lines', () {
      // Composite + a transition that crosses the cluster shell — this is the
      // scenario where shell-vs-edge z-order matters: the edge must paint on
      // top of the shell so any boundary crossing reads cleanly.
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state Outer {\n'
        '  A --> B : go\n'
        '}\n'
        'C --> A : enter\n'
        '@enduml\n',
      );
      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      // Cluster shells = SceneRoundedBox with no label (rendered before
      // labelled state rects). Edge route lines = SceneLine with head=null
      // (the body segments) AND head=ArrowHead.open (the terminal segment).
      var lastShellIdx = -1;
      var firstEdgeLineIdx = -1;
      for (var i = 0; i < scene.shapes.length; i++) {
        final s = scene.shapes[i];
        if (s is SceneRoundedBox && s.label == null) {
          // Could be a shell OR a description-style leaf rect; we treat both
          // as "shell-style" since they're emitted in the cluster/node group
          // ahead of routes. Track the latest.
          lastShellIdx = i;
        }
        if (s is SceneLine && s.head == ArrowHead.open) {
          // The terminal segment of an edge route. There's no description
          // divider line with an arrowhead, so this is unambiguous.
          if (firstEdgeLineIdx < 0) firstEdgeLineIdx = i;
        }
      }
      expect(lastShellIdx, greaterThanOrEqualTo(0),
          reason: 'expected at least one cluster shell in the scene');
      expect(firstEdgeLineIdx, greaterThanOrEqualTo(0),
          reason: 'expected at least one edge route in the scene');
      expect(lastShellIdx, lessThan(firstEdgeLineIdx),
          reason: 'all cluster shells should be emitted before any edge route');
    });

    test('composite state with one description: shell taller than no-desc and '
        'desc sits inside the top inset', () {
      // Baseline composite with no descriptions.
      final baseline = _parseStateDiagram(
        '@startuml\n'
        'state Outer {\n'
        '  A --> B : go\n'
        '}\n'
        '@enduml\n',
      );
      // Same composite with a single description line on Outer.
      final withDesc = _parseStateDiagram(
        '@startuml\n'
        'Outer : composite description\n'
        'state Outer {\n'
        '  A --> B : go\n'
        '}\n'
        '@enduml\n',
      );

      final sceneBase = layoutStateDiagramWithSugiyama(baseline, measurer);
      final sceneDesc = layoutStateDiagramWithSugiyama(withDesc, measurer);

      // The shell is the rounded box with a null label that contains both A
      // and B (vs. some other cluster shell). For this single-composite case
      // there is exactly one shell in each scene.
      final baseShell = sceneBase.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((b) => b.label == null);
      final descShell = sceneDesc.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((b) => b.label == null);

      // With a description, the shell rect is strictly taller.
      expect(descShell.rect.height, greaterThan(baseShell.rect.height));

      // The description text is rendered as a SceneText inside the shell.
      final descText = sceneDesc.shapes
          .whereType<SceneText>()
          .firstWhere((t) => t.text == 'composite description');
      expect(descShell.rect.contains(
          Offset(descText.offset.dx + 1, descText.offset.dy + 1)),
          isTrue);

      // Description sits above the inner state rects (inside the top inset).
      final innerA = sceneDesc.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((b) => b.label == 'A');
      final innerB = sceneDesc.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((b) => b.label == 'B');
      expect(descText.offset.dy, lessThan(innerA.rect.top));
      expect(descText.offset.dy, lessThan(innerB.rect.top));

      // The composite title still renders above the description.
      final titleText = sceneDesc.shapes
          .whereType<SceneText>()
          .firstWhere((t) => t.text == 'Outer');
      expect(titleText.offset.dy, lessThan(descText.offset.dy));
    });

    test('composite state with three descriptions: ordered stack inside bbox',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'Outer : first\n'
        'Outer : second\n'
        'Outer : third\n'
        'state Outer {\n'
        '  A --> B\n'
        '}\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final descTexts = scene.shapes
          .whereType<SceneText>()
          .where((t) =>
              t.text == 'first' || t.text == 'second' || t.text == 'third')
          .toList();
      expect(descTexts.length, 3);

      final first = descTexts.firstWhere((t) => t.text == 'first');
      final second = descTexts.firstWhere((t) => t.text == 'second');
      final third = descTexts.firstWhere((t) => t.text == 'third');

      // Stacked vertically in declaration order.
      expect(first.offset.dy, lessThan(second.offset.dy));
      expect(second.offset.dy, lessThan(third.offset.dy));

      // Left-aligned.
      expect(first.offset.dx, second.offset.dx);
      expect(second.offset.dx, third.offset.dx);

      // All three sit inside the cluster shell's rect.
      final shell = scene.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((b) => b.label == null);
      for (final t in descTexts) {
        expect(shell.rect.contains(Offset(t.offset.dx + 1, t.offset.dy + 1)),
            isTrue,
            reason: 'description "${t.text}" not inside shell ${shell.rect}');
      }

      // All three sit above the inner state rects.
      final innerA = scene.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((b) => b.label == 'A');
      expect(third.offset.dy, lessThan(innerA.rect.top));
    });

    test('nested composite: outer has descriptions, inner composite stays '
        'below the outer description block', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'Outer : outer note\n'
        'state Outer {\n'
        '  state Inner {\n'
        '    A --> B\n'
        '  }\n'
        '}\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final shells = scene.shapes
          .whereType<SceneRoundedBox>()
          .where((b) => b.label == null)
          .toList();
      // Two shells: outer and inner. Pick by area.
      shells.sort((a, b) =>
          (b.rect.width * b.rect.height).compareTo(a.rect.width * a.rect.height));
      final outerShell = shells.first;
      final innerShell = shells.last;

      final descText = scene.shapes
          .whereType<SceneText>()
          .firstWhere((t) => t.text == 'outer note');

      // Description is inside the outer shell, above the inner shell.
      expect(outerShell.rect.contains(
          Offset(descText.offset.dx + 1, descText.offset.dy + 1)),
          isTrue);
      expect(descText.offset.dy, lessThan(innerShell.rect.top));

      // Inner shell still sits strictly inside the outer shell.
      expect(innerShell.rect.left, greaterThan(outerShell.rect.left));
      expect(innerShell.rect.top, greaterThan(outerShell.rect.top));
      expect(innerShell.rect.right, lessThan(outerShell.rect.right));
      expect(innerShell.rect.bottom, lessThan(outerShell.rect.bottom));
    });

    test('feature flag default is off — AutoLayout uses legacy StateLayout', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> A\n'
        'A --> B : go\n'
        'B --> [*]\n'
        '@enduml\n',
      );

      final legacy = const AutoLayout().layout(diagram, measurer);
      final viaFlagOff =
          const AutoLayout(useSugiyamaForStates: false).layout(diagram, measurer);
      // Default constructor must be byte-identical to flag=false.
      expect(legacy.size, viaFlagOff.size);
      expect(legacy.shapes.length, viaFlagOff.shapes.length);

      final viaFlagOn =
          const AutoLayout(useSugiyamaForStates: true).layout(diagram, measurer);
      final viaAdapter =
          layoutStateDiagramWithSugiyama(diagram, measurer);
      // Flag-on must route through the Sugiyama adapter (identical shape
      // count and size to a direct adapter call).
      expect(viaFlagOn.size, viaAdapter.size);
      expect(viaFlagOn.shapes.length, viaAdapter.shapes.length);
    });
  });

  group('concurrent regions', () {
    test('vertical regions (--): regions stack top-to-bottom with a divider',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state Active {\n'
        '  [*] --> NumLockOff\n'
        '  NumLockOff --> NumLockOn : press\n'
        '  --\n'
        '  [*] --> CapsOff\n'
        '  CapsOff --> CapsOn : press\n'
        '}\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      // Composite header rendered as a SceneText 'Active'.
      final texts = scene.shapes.whereType<SceneText>().map((t) => t.text);
      expect(texts.contains('Active'), isTrue);

      // All four inner state labels appear as SceneRoundedBox labels.
      final boxByLabel = <String, SceneRoundedBox>{
        for (final s in scene.shapes.whereType<SceneRoundedBox>())
          if (s.label != null) s.label!: s,
      };
      for (final name in ['NumLockOff', 'NumLockOn', 'CapsOff', 'CapsOn']) {
        expect(boxByLabel.containsKey(name), isTrue, reason: name);
      }

      // At least one dashed region divider.
      final dashed = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.dashed)
          .toList();
      expect(dashed, isNotEmpty);

      // Region-2 states sit BELOW region-1 states (vertical stacking).
      final r1MaxY = [boxByLabel['NumLockOff']!, boxByLabel['NumLockOn']!]
          .map((b) => b.rect.bottom)
          .reduce((a, b) => a > b ? a : b);
      final r2MinY = [boxByLabel['CapsOff']!, boxByLabel['CapsOn']!]
          .map((b) => b.rect.top)
          .reduce((a, b) => a < b ? a : b);
      expect(r1MaxY, lessThan(r2MinY));
    });

    test('horizontal regions (||): regions sit side-by-side, vertical divider',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state Active {\n'
        '  [*] --> NumLockOff\n'
        '  NumLockOff --> NumLockOn : press\n'
        '  ||\n'
        '  [*] --> CapsOff\n'
        '  CapsOff --> CapsOn : press\n'
        '}\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final boxByLabel = <String, SceneRoundedBox>{
        for (final s in scene.shapes.whereType<SceneRoundedBox>())
          if (s.label != null) s.label!: s,
      };
      for (final name in ['NumLockOff', 'NumLockOn', 'CapsOff', 'CapsOn']) {
        expect(boxByLabel.containsKey(name), isTrue, reason: name);
      }

      // Region-2 states sit to the RIGHT of region-1 states.
      final r1MaxX = [boxByLabel['NumLockOff']!, boxByLabel['NumLockOn']!]
          .map((b) => b.rect.right)
          .reduce((a, b) => a > b ? a : b);
      final r2MinX = [boxByLabel['CapsOff']!, boxByLabel['CapsOn']!]
          .map((b) => b.rect.left)
          .reduce((a, b) => a < b ? a : b);
      expect(r1MaxX, lessThan(r2MinX));

      // The divider is a vertical dashed line.
      final dashed = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.dashed)
          .toList();
      expect(dashed, isNotEmpty);
      expect((dashed.first.from.dx - dashed.first.to.dx).abs(),
          lessThan(0.001));
    });

    test('inner states stay within the composite shell and routes exist', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state Active {\n'
        '  [*] --> NumLockOff\n'
        '  NumLockOff --> NumLockOn : press\n'
        '  --\n'
        '  [*] --> CapsOff\n'
        '  CapsOff --> CapsOn : press\n'
        '}\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      // The composite shell is the box that contains all the inner state rects.
      final innerNames = {'NumLockOff', 'NumLockOn', 'CapsOff', 'CapsOn'};
      final inner = boxes
          .where((b) => innerNames.contains(b.label))
          .toList(growable: false);
      // Shell rect: the widest box that is not an inner state.
      final shell = boxes
          .where((b) => !innerNames.contains(b.label))
          .reduce((a, b) =>
              a.rect.width * a.rect.height > b.rect.width * b.rect.height
                  ? a
                  : b);
      for (final b in inner) {
        expect(b.rect.left, greaterThanOrEqualTo(shell.rect.left - 0.5));
        expect(b.rect.right, lessThanOrEqualTo(shell.rect.right + 0.5));
        expect(b.rect.top, greaterThanOrEqualTo(shell.rect.top - 0.5));
        expect(b.rect.bottom, lessThanOrEqualTo(shell.rect.bottom + 0.5));
      }

      // Inner transitions render as open-arrowhead route lines.
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .length;
      expect(arrows, greaterThanOrEqualTo(1));
    });

    test('nested composite inside a region does not crash and renders', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state Active {\n'
        '  state Inner {\n'
        '    Leaf1 --> Leaf2 : go\n'
        '  }\n'
        '  [*] --> Inner\n'
        '  --\n'
        '  [*] --> CapsOff\n'
        '  CapsOff --> CapsOn : press\n'
        '}\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final labels = <String?>{
        for (final s in scene.shapes.whereType<SceneRoundedBox>()) s.label,
      };
      // Nested composite's inner leaves appear.
      expect(labels.contains('Leaf1'), isTrue);
      expect(labels.contains('Leaf2'), isTrue);
      expect(labels.contains('CapsOff'), isTrue);
      // Composite header text is present.
      final texts = scene.shapes.whereType<SceneText>().map((t) => t.text);
      expect(texts.contains('Active'), isTrue);
      expect(texts.contains('Inner'), isTrue);
    });
  });

  group('recursive composite layout', () {
    // The canonical PlantUML NotShooting/Configuring example. Each composite
    // owns its own [*] initial and lays out as its own recursive sub-graph;
    // sibling composites stack vertically without overlapping; cross-container
    // EvConfig transitions route between the two composites' shells.
    StateDiagram canonical() => _parseStateDiagram(
          '@startuml\n'
          '[*] --> NotShooting\n'
          'state NotShooting {\n'
          '  [*] --> Idle\n'
          '  Idle --> Configuring : EvConfig\n'
          '  Configuring --> Idle : EvConfig\n'
          '}\n'
          'state Configuring {\n'
          '  [*] --> NewValueSelection\n'
          '  NewValueSelection --> NewValuePreview : EvNewValue\n'
          '  NewValuePreview --> NewValueSelection : EvNewValueRejected\n'
          '  NewValuePreview --> NewValueSelection : EvNewValueSaved\n'
          '  state NewValuePreview { State1 -> State2 }\n'
          '}\n'
          '@enduml\n',
        );

    SceneRoundedBox boxLabelled(Scene scene, String label) => scene.shapes
        .whereType<SceneRoundedBox>()
        .firstWhere((b) => b.label == label);

    // The composite shell whose rect contains [child]'s center but is itself
    // the smallest such null-label box (so a nested shell wins over an outer).
    SceneRoundedBox shellContaining(Scene scene, Rect child) {
      final shells = scene.shapes
          .whereType<SceneRoundedBox>()
          .where((b) => b.label == null && b.rect.contains(child.center))
          .toList();
      shells.sort((a, b) =>
          (a.rect.width * a.rect.height).compareTo(b.rect.width * b.rect.height));
      return shells.first;
    }

    test('all leaf labels present', () {
      final scene = layoutStateDiagramWithSugiyama(canonical(), measurer);
      final labels = <String>{
        for (final s in scene.shapes.whereType<SceneRoundedBox>())
          if (s.label != null) s.label!,
      };
      for (final name in ['Idle', 'NewValueSelection', 'State1', 'State2']) {
        expect(labels.contains(name), isTrue, reason: name);
      }
    });

    test('three initial dots: one per scope, each inside its composite shell',
        () {
      final scene = layoutStateDiagramWithSugiyama(canonical(), measurer);
      final dots = scene.shapes
          .whereType<SceneCircle>()
          .where((c) => !c.ring)
          .toList();
      expect(dots.length, 3);

      // NotShooting and Configuring shells: the two outer composite shells.
      final idle = boxLabelled(scene, 'Idle');
      final nvs = boxLabelled(scene, 'NewValueSelection');
      final notShooting = shellContaining(scene, idle.rect);
      final configuring = shellContaining(scene, nvs.rect);

      // Root dot: above NotShooting, not inside either composite shell.
      final rootDots = dots
          .where((d) =>
              !notShooting.rect.contains(d.center) &&
              !configuring.rect.contains(d.center))
          .toList();
      expect(rootDots.length, 1);
      expect(rootDots.single.center.dy, lessThan(notShooting.rect.top));

      // One dot inside NotShooting's shell, one inside Configuring's shell.
      final inNotShooting =
          dots.where((d) => notShooting.rect.contains(d.center)).toList();
      final inConfiguring =
          dots.where((d) => configuring.rect.contains(d.center)).toList();
      expect(inNotShooting.length, 1);
      expect(inConfiguring.length, 1);
    });

    test('NotShooting shell sits above Configuring shell, no overlap', () {
      final scene = layoutStateDiagramWithSugiyama(canonical(), measurer);
      final idle = boxLabelled(scene, 'Idle');
      final nvs = boxLabelled(scene, 'NewValueSelection');
      final notShooting = shellContaining(scene, idle.rect);
      final configuring = shellContaining(scene, nvs.rect);

      const eps = 1.0;
      expect(notShooting.rect.bottom, lessThanOrEqualTo(configuring.rect.top + eps));
      // No rect overlap between the two sibling shells.
      expect(notShooting.rect.overlaps(configuring.rect), isFalse);
    });

    test('all five transition labels render', () {
      final scene = layoutStateDiagramWithSugiyama(canonical(), measurer);
      final texts =
          scene.shapes.whereType<SceneText>().map((t) => t.text).toList();
      expect(texts.where((t) => t == 'EvConfig').length, 2);
      expect(texts.contains('EvNewValue'), isTrue);
      expect(texts.contains('EvNewValueRejected'), isTrue);
      expect(texts.contains('EvNewValueSaved'), isTrue);
    });

    test('NewValuePreview shell strictly inside Configuring; State1/2 inside it',
        () {
      final scene = layoutStateDiagramWithSugiyama(canonical(), measurer);
      final nvs = boxLabelled(scene, 'NewValueSelection');
      final configuring = shellContaining(scene, nvs.rect);
      final s1 = boxLabelled(scene, 'State1');
      final s2 = boxLabelled(scene, 'State2');
      final preview = shellContaining(scene, s1.rect);

      // Preview shell strictly inside Configuring shell.
      expect(preview.rect.left, greaterThan(configuring.rect.left));
      expect(preview.rect.top, greaterThan(configuring.rect.top));
      expect(preview.rect.right, lessThan(configuring.rect.right));
      expect(preview.rect.bottom, lessThan(configuring.rect.bottom));

      // State1/State2 inside the preview shell.
      expect(preview.rect.contains(s1.rect.center), isTrue);
      expect(preview.rect.contains(s2.rect.center), isTrue);
    });

    test('EvConfig routes connect NotShooting and Configuring shells', () {
      final scene = layoutStateDiagramWithSugiyama(canonical(), measurer);
      final idle = boxLabelled(scene, 'Idle');
      final nvs = boxLabelled(scene, 'NewValueSelection');
      final notShooting = shellContaining(scene, idle.rect);
      final configuring = shellContaining(scene, nvs.rect);

      // The two EvConfig label texts identify their route midpoints; instead,
      // assert that arrowhead endpoints exist near both shells' boundaries.
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .toList();

      // Gather all route endpoints (segment ends) from arrow-tipped segments.
      bool nearShell(Offset p, Rect shell) {
        final inflated = shell.inflate(20.0);
        return inflated.contains(p) &&
            (!shell.deflate(2.0).contains(p) || shell.contains(p));
      }

      // At least one arrow segment touches near the NotShooting shell and at
      // least one near the Configuring shell (the EvConfig pair crosses the
      // boundary between the two composites).
      final touchNotShooting = arrows.any((a) =>
          nearShell(a.from, notShooting.rect) ||
          nearShell(a.to, notShooting.rect));
      final touchConfiguring = arrows.any((a) =>
          nearShell(a.from, configuring.rect) ||
          nearShell(a.to, configuring.rect));
      expect(touchNotShooting, isTrue);
      expect(touchConfiguring, isTrue);

      // A route endpoint should land exactly on one of Configuring's
      // horizontal boundaries (the composite is the EvConfig destination/
      // source, terminated at its shell rather than punched through).
      final onConfiguringBoundary = arrows.any((a) {
        for (final p in [a.from, a.to]) {
          final onTop = (p.dy - configuring.rect.top).abs() < 0.5;
          final onBottom = (p.dy - configuring.rect.bottom).abs() < 0.5;
          final withinX =
              p.dx >= configuring.rect.left && p.dx <= configuring.rect.right;
          if ((onTop || onBottom) && withinX) return true;
        }
        return false;
      });
      expect(onConfiguringBoundary, isTrue);
    });
  });

  group('arrow direction', () {
    SceneRoundedBox boxFor(Scene scene, String label) => scene.shapes
        .whereType<SceneRoundedBox>()
        .firstWhere((s) => s.label == label);

    test('`A -> B` places B to the right of A in the same row', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> A\n'
        'A -> B\n'
        'A --> [*]\n'
        'B --> [*]\n'
        '@enduml\n',
      );
      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);
      final a = boxFor(scene, 'A');
      final b = boxFor(scene, 'B');
      expect(b.rect.center.dx, greaterThan(a.rect.center.dx));
      expect((b.rect.center.dy - a.rect.center.dy).abs(), lessThan(1.0));
    });

    test('`A --> B` places B below A in the same column', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> A\n'
        'A --> B\n'
        'B --> [*]\n'
        '@enduml\n',
      );
      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);
      final a = boxFor(scene, 'A');
      final b = boxFor(scene, 'B');
      expect(b.rect.center.dy, greaterThan(a.rect.center.dy));
      expect((b.rect.center.dx - a.rect.center.dx).abs(), lessThan(1.0));
    });

    test('`A -up-> B` places B above A with the arrowhead on B', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> A\n'
        'A -up-> B\n'
        'B --> [*]\n'
        '@enduml\n',
      );
      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);
      final a = boxFor(scene, 'A');
      final b = boxFor(scene, 'B');
      expect(b.rect.center.dy, lessThan(a.rect.center.dy));
      // The rendered arrow (open head) for A->B terminates on/near B's rect.
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .toList();
      bool nearRect(Offset p, Rect r) =>
          p.dx >= r.left - 1 &&
          p.dx <= r.right + 1 &&
          p.dy >= r.top - 1 &&
          p.dy <= r.bottom + 1;
      final touchesB = arrows.any((l) => nearRect(l.to, b.rect));
      expect(touchesB, isTrue);
    });

    test('`A -left-> B` places B to the left of A', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> A\n'
        'A -left-> B\n'
        'A --> [*]\n'
        'B --> [*]\n'
        '@enduml\n',
      );
      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);
      final a = boxFor(scene, 'A');
      final b = boxFor(scene, 'B');
      expect(b.rect.center.dx, lessThan(a.rect.center.dx));
    });

    test('repro: single-dash `->` puts State2 right of State1, all routes draw',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> State1\n'
        'State1 --> [*]\n'
        'State1 : this is a string\n'
        'State1 : this is another string\n'
        'State1 -> State2\n'
        'State2 --> [*]\n'
        '@enduml\n',
      );
      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      // State1 renders as a boxed state whose description lines are present.
      final texts = scene.shapes
          .whereType<SceneText>()
          .map((t) => t.text)
          .toList();
      expect(texts.contains('State1'), isTrue);
      expect(texts.contains('this is a string'), isTrue);
      expect(texts.contains('this is another string'), isTrue);

      // State2 sits to the RIGHT of State1.
      final state2 = boxFor(scene, 'State2');
      // State1's title text x marks its column; find State1's enclosing box by
      // the description text it carries.
      final state1Title =
          scene.shapes.whereType<SceneText>().firstWhere((t) => t.text == 'State1');
      expect(state2.rect.center.dx, greaterThan(state1Title.offset.dx));

      // Four routes: initial->State1, State1->[*], State1->State2, State2->[*].
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .length;
      expect(arrows, 4);
    });

    test('horizontally-placed node re-routes its other edges from new spot',
        () {
      // Regression: State2 is pulled into State1's row by `State1 -> State2`,
      // so its `State2 --> [*]` edge must route from State2's NEW position, not
      // the stale layer-0 spot it had before horizontal placement.
      final scene = layoutStateDiagramWithSugiyama(
        _parseStateDiagram(
          '@startuml\n'
          '[*] --> State1\n'
          'State1 --> [*]\n'
          'State1 -> State2\n'
          'State2 --> [*]\n'
          '@enduml\n',
        ),
        measurer,
      );
      final state2 = boxFor(scene, 'State2');
      final ring =
          scene.shapes.whereType<SceneCircle>().firstWhere((c) => c.ring);
      // Arrows whose tip lands on the final ring (State1->[*] and State2->[*]).
      final intoRing = scene.shapes
          .whereType<SceneLine>()
          .where((l) =>
              l.head == ArrowHead.open && (l.to - ring.center).distance < 30)
          .toList();
      expect(intoRing.length, 2);
      // One of them must start from State2 (right side), not the stale top-left
      // position: its tail x must reach State2's column.
      final maxTailX =
          intoRing.map((l) => l.from.dx).reduce((a, b) => a > b ? a : b);
      expect(maxTailX, greaterThanOrEqualTo(state2.rect.left - 5));
    });
  });

  group('same-rank horizontal placement', () {
    SceneRoundedBox boxFor(Scene scene, String label) => scene.shapes
        .whereType<SceneRoundedBox>()
        .firstWhere((s) => s.label == label);

    test('common successor of `A -> B` centers between A and B on next rank',
        () {
      // PlantUML treats `State1 -> State2` as a same-rank constraint: both sit
      // on one row and the shared final ring centers between them — no long
      // diagonal back-edge under State1.
      final scene = layoutStateDiagramWithSugiyama(
        _parseStateDiagram(
          '@startuml\n'
          '[*] --> State1\n'
          'State1 --> [*]\n'
          'State1 -> State2\n'
          'State2 --> [*]\n'
          '@enduml\n',
        ),
        measurer,
      );
      final state1 = boxFor(scene, 'State1');
      final state2 = boxFor(scene, 'State2');
      // Same row.
      expect((state1.rect.center.dy - state2.rect.center.dy).abs(),
          lessThan(1.0));
      // State2 to the right of State1.
      expect(state2.rect.center.dx, greaterThan(state1.rect.center.dx));
      // Final ring centered horizontally between the two states.
      final ring =
          scene.shapes.whereType<SceneCircle>().firstWhere((c) => c.ring);
      expect(ring.center.dx, greaterThan(state1.rect.center.dx));
      expect(ring.center.dx, lessThan(state2.rect.center.dx));
      // Ring sits BELOW the same-rank row (it is a successor of both).
      expect(ring.center.dy, greaterThan(state1.rect.center.dy));
      // The `State2 --> [*]` arrow does not travel far left of State1 (no
      // back-crossing): both ring-bound arrow tails stay at/right of State1.
      final intoRing = scene.shapes
          .whereType<SceneLine>()
          .where((l) =>
              l.head == ArrowHead.open && (l.to - ring.center).distance < 40)
          .toList();
      expect(intoRing.length, 2);
      for (final l in intoRing) {
        expect(l.from.dx, greaterThanOrEqualTo(state1.rect.left - 1));
      }
    });

    test('diamond `A -> B`, `A --> C`, `B --> C`: C centers between A and B',
        () {
      final scene = layoutStateDiagramWithSugiyama(
        _parseStateDiagram(
          '@startuml\n'
          '[*] --> A\n'
          'A -> B\n'
          'A --> C\n'
          'B --> C\n'
          '@enduml\n',
        ),
        measurer,
      );
      final a = boxFor(scene, 'A');
      final b = boxFor(scene, 'B');
      final c = boxFor(scene, 'C');
      // A and B on the same row, B to the right.
      expect((a.rect.center.dy - b.rect.center.dy).abs(), lessThan(1.0));
      expect(b.rect.center.dx, greaterThan(a.rect.center.dx));
      // C centered between A and B, one rank below.
      expect(c.rect.center.dx, greaterThan(a.rect.center.dx));
      expect(c.rect.center.dx, lessThan(b.rect.center.dx));
      expect(c.rect.center.dy, greaterThan(a.rect.center.dy));
      // Both A->C and B->C present and short (tails sit above C, at/around
      // each source column).
      final intoC = scene.shapes
          .whereType<SceneLine>()
          .where((l) =>
              l.head == ArrowHead.open &&
              (l.to - c.rect.center).distance < c.rect.height + 5)
          .toList();
      expect(intoC.length, greaterThanOrEqualTo(2));
    });

    test('`A -left-> B`: B sits to the LEFT of A on the same row', () {
      final scene = layoutStateDiagramWithSugiyama(
        _parseStateDiagram(
          '@startuml\n'
          '[*] --> A\n'
          'A -left-> B\n'
          'A --> [*]\n'
          'B --> [*]\n'
          '@enduml\n',
        ),
        measurer,
      );
      final a = boxFor(scene, 'A');
      final b = boxFor(scene, 'B');
      expect(b.rect.center.dx, lessThan(a.rect.center.dx));
      expect((a.rect.center.dy - b.rect.center.dy).abs(), lessThan(1.0));
    });
  });

  group('parallel edges', () {
    // Text rect for a SceneText, measured with the same measurer the adapter
    // uses for transition labels.
    Rect rectOf(SceneText t) {
      final size = measurer.measure(t.text, t.textStyle);
      return Rect.fromLTWH(t.offset.dx, t.offset.dy, size.width, size.height);
    }

    SceneText labelText(Scene scene, String text) => scene.shapes
        .whereType<SceneText>()
        .firstWhere((t) => t.text == text);

    test('three parallel transitions fan into distinct non-overlapping labels',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        'state Configuring {\n'
        '  [*] --> NewValueSelection\n'
        '  NewValueSelection --> NewValuePreview : EvNewValue\n'
        '  NewValuePreview --> NewValueSelection : EvNewValueRejected\n'
        '  NewValuePreview --> NewValueSelection : EvNewValueSaved\n'
        '  state NewValuePreview { State1 -> State2 }\n'
        '}\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final ev1 = labelText(scene, 'EvNewValue');
      final ev2 = labelText(scene, 'EvNewValueRejected');
      final ev3 = labelText(scene, 'EvNewValueSaved');

      // Pairwise-distinct offsets.
      expect(ev1.offset, isNot(ev2.offset));
      expect(ev1.offset, isNot(ev3.offset));
      expect(ev2.offset, isNot(ev3.offset));

      // No two label text rects overlap.
      final rects = [rectOf(ev1), rectOf(ev2), rectOf(ev3)];
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse,
              reason: 'labels $i and $j overlap');
        }
      }
    });

    test('two parallel transitions: distinct polylines, non-overlapping labels',
        () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> A\n'
        'A --> B : L1\n'
        'A --> B : L2\n'
        'B --> [*]\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final l1 = labelText(scene, 'L1');
      final l2 = labelText(scene, 'L2');
      expect(rectOf(l1).overlaps(rectOf(l2)), isFalse);

      // The two A->B routes are not identical polylines. Collect the arrow-
      // headed final segments grouped near the A->B region; assert at least one
      // pair of route segments differs.
      final arrowSegs = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .toList();
      // Two A->B arrows plus the two pseudo arrows: at least the two A->B ones
      // must have distinct geometry (they no longer coincide).
      final distinct = <String>{
        for (final s in arrowSegs) '${s.from}->${s.to}',
      };
      expect(distinct.length, arrowSegs.length,
          reason: 'every arrow segment should be geometrically distinct');
    });

    test('bidirectional pair: both labels present, non-overlapping, '
        'arrowheads correct', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] --> A\n'
        'A --> B : go\n'
        'B --> A : back\n'
        'B --> [*]\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      final go = labelText(scene, 'go');
      final back = labelText(scene, 'back');
      expect(rectOf(go).overlaps(rectOf(back)), isFalse);

      final a = scene.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((s) => s.label == 'A');
      final b = scene.shapes
          .whereType<SceneRoundedBox>()
          .firstWhere((s) => s.label == 'B');

      // `go` (A->B) arrowhead lands near B; `back` (B->A) arrowhead lands near
      // A. The arrow-headed segment closest to each label's edge points the
      // correct way: the head endpoint of the A->B route is on B's side, and
      // the head endpoint of the B->A route is on A's side.
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head == ArrowHead.open)
          .toList();
      // The arrowhead pointing toward B (down to A->B) has its `to` nearer B's
      // center than A's; vice versa for the other.
      bool nearer(Offset p, Rect target, Rect other) =>
          (p - target.center).distance < (p - other.center).distance;
      final towardB =
          arrows.where((l) => nearer(l.to, b.rect, a.rect)).toList();
      final towardA =
          arrows.where((l) => nearer(l.to, a.rect, b.rect)).toList();
      expect(towardB, isNotEmpty);
      expect(towardA, isNotEmpty);
    });

    test('nested forward-ref to a top-level leaf renders it only once', () {
      final diagram = _parseStateDiagram(
        '@startuml\n'
        '[*] -> State1\n'
        'State1 --> State2 : Succeeded\n'
        'State2 --> State3 : Succeeded\n'
        'state State3 {\n'
        '  [*] --> long1\n'
        '  State2 --> [H]: Resume\n'
        '}\n'
        'State3 --> State2 : Pause\n'
        '@enduml\n',
      );

      final scene = layoutStateDiagramWithSugiyama(diagram, measurer);

      // State2 must be rendered exactly once: the spurious nested stub inside
      // State3 was pruned by the parser, so only the top-level box remains.
      final state2Boxes = scene.shapes
          .whereType<SceneRoundedBox>()
          .where((s) => s.label == 'State2')
          .length;
      expect(state2Boxes, 1);
    });
  });
}
