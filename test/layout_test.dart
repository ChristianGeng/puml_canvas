import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

class _FixedTextMeasurer implements TextMeasurer {
  @override
  Size measure(String text, TextStyle style) =>
      Size(text.length * 7.0, 14);
}

void main() {
  group('SequenceLayout', () {
    const layout = SequenceLayout();
    final measurer = _FixedTextMeasurer();

    test('returns empty scene for diagram with no participants', () {
      final scene = layout.layout(const SequenceDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('emits two actor boxes + lifeline + message line per participant pair',
        () {
      final scene = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B', label: 'hi'),
        ]),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      final lines = scene.shapes.whereType<SceneLine>().toList();
      expect(boxes, hasLength(4));
      expect(lines.where((l) => l.dashed && l.head == null), hasLength(2));
      expect(lines.where((l) => l.head != null), hasLength(1));
    });

    test('scene size grows with participant count', () {
      final small = layout.layout(
        const SequenceDiagram(
            events: [Message(from: 'A', to: 'B')]),
        measurer,
      );
      final big = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B'),
          Message(from: 'B', to: 'C'),
        ]),
        measurer,
      );
      expect(big.size.width, greaterThan(small.size.width));
    });

    test('explicit participant declarations fix layout order', () {
      final scene = layout.layout(
        const SequenceDiagram(
          participants: [
            Participant(alias: 'C'),
            Participant(alias: 'A'),
            Participant(alias: 'B'),
          ],
          events: [
            Message(from: 'A', to: 'B'),
          ],
        ),
        measurer,
      );
      final actorBoxes = scene.shapes.whereType<SceneBox>().toList();
      final topBoxes = actorBoxes
          .where((b) => b.rect.top < scene.size.height / 2)
          .toList()
        ..sort((a, b) => a.rect.left.compareTo(b.rect.left));
      expect(topBoxes.map((b) => b.label), ['C', 'A', 'B']);
    });

    test('displayName is used as actor label when present', () {
      final scene = layout.layout(
        const SequenceDiagram(
          participants: [
            Participant(alias: 'DB', displayName: 'Database'),
          ],
          events: [
            Message(from: 'A', to: 'DB'),
          ],
        ),
        measurer,
      );
      final labels =
          scene.shapes.whereType<SceneBox>().map((b) => b.label).toSet();
      expect(labels, contains('Database'));
      expect(labels, isNot(contains('DB')));
    });

    test('self-message emits three line segments with one arrow head', () {
      final scene = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'A', label: 'recurse'),
        ]),
        measurer,
      );
      final messageLines = scene.shapes
          .whereType<SceneLine>()
          .where((l) => !(l.dashed && l.head == null && l.strokeWidth == 0.5))
          .toList();
      expect(messageLines, hasLength(3));
      expect(messageLines.where((l) => l.head != null), hasLength(1));
    });

    test('self-message increases scene height', () {
      final straight = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B'),
        ]),
        measurer,
      );
      final selfA = layout.layout(
        const SequenceDiagram(
          participants: [
            Participant(alias: 'A'),
            Participant(alias: 'B'),
          ],
          events: [Message(from: 'A', to: 'A')],
        ),
        measurer,
      );
      expect(selfA.size.height, greaterThan(straight.size.height));
    });

    test('note emits a SceneNote shape', () {
      final scene = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B'),
          Note(
              position: NotePosition.rightOf,
              participants: ['A'],
              text: 'side note'),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneNote>(), hasLength(1));
    });

    test('multi-line note is taller than single-line with same chars', () {
      final single = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B'),
          Note(
              position: NotePosition.rightOf,
              participants: ['A'],
              text: 'oneline'),
        ]),
        measurer,
      );
      final multi = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B'),
          Note(
              position: NotePosition.rightOf,
              participants: ['A'],
              text: 'one\nline'),
        ]),
        measurer,
      );
      final singleNote = single.shapes.whereType<SceneNote>().single;
      final multiNote = multi.shapes.whereType<SceneNote>().single;
      expect(multiNote.rect.height, greaterThan(singleNote.rect.height));
    });

    test('note over multiple participants spans them', () {
      final scene = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B'),
          Note(
              position: NotePosition.over,
              participants: ['A', 'B'],
              text: 'spans'),
        ]),
        measurer,
      );
      final note = scene.shapes.whereType<SceneNote>().single;
      final boxes = scene.shapes
          .whereType<SceneBox>()
          .where((b) => b.rect.top < scene.size.height / 2)
          .toList();
      final cxA =
          boxes.firstWhere((b) => b.label == 'A').rect.center.dx;
      final cxB =
          boxes.firstWhere((b) => b.label == 'B').rect.center.dx;
      expect(note.rect.left, lessThanOrEqualTo(cxA));
      expect(note.rect.right, greaterThanOrEqualTo(cxB));
    });

    test('ref over emits an outer box, ref tab, and body text', () {
      final scene = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B'),
          RefBox(participants: ['A', 'B'], text: 'see other diagram'),
        ]),
        measurer,
      );
      final refTabs = scene.shapes
          .whereType<SceneBox>()
          .where((b) => b.label == 'ref')
          .toList();
      expect(refTabs, hasLength(1));
      final bodyTexts = scene.shapes
          .whereType<SceneText>()
          .where((t) => t.text == 'see other diagram')
          .toList();
      expect(bodyTexts, hasLength(1));

      final actorBoxes = scene.shapes
          .whereType<SceneBox>()
          .where((b) => b.label == 'A' || b.label == 'B')
          .toList();
      final cxA = actorBoxes
          .firstWhere((b) => b.label == 'A')
          .rect
          .center
          .dx;
      final cxB = actorBoxes
          .firstWhere((b) => b.label == 'B')
          .rect
          .center
          .dx;
      final outer = scene.shapes
          .whereType<SceneBox>()
          .where((b) =>
              b.label == null &&
              b.rect.left < cxA &&
              b.rect.right > cxB &&
              b.rect.width > 30)
          .toList();
      expect(outer, hasLength(1));
    });

    test('activate/deactivate produces an activation bar', () {
      final scene = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B'),
          Activate('B'),
          Message(from: 'B', to: 'A', lineStyle: LineStyle.dashed),
          Deactivate('B'),
        ]),
        measurer,
      );
      // Top + bottom actor boxes for A and B = 4. Activation bar adds one
      // narrow filled rectangle.
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      expect(boxes, hasLength(5));
      final narrow = boxes.where((b) => b.rect.width < 20).toList();
      expect(narrow, hasLength(1));
      expect(narrow.single.fill, const Color(0xFFFFFFFF));
    });

    test('unmatched activate auto-closes at lifeline bottom', () {
      final scene = layout.layout(
        const SequenceDiagram(events: [
          Message(from: 'A', to: 'B'),
          Activate('B'),
          Message(from: 'B', to: 'A'),
        ]),
        measurer,
      );
      final narrow = scene.shapes
          .whereType<SceneBox>()
          .where((b) => b.rect.width < 20)
          .toList();
      expect(narrow, hasLength(1));
    });

    test('group emits an outer box with transparent fill and a label tab', () {
      final scene = layout.layout(
        const SequenceDiagram(events: [
          Group(
            kind: GroupKind.alt,
            branches: [
              GroupBranch(
                  label: 'ok', events: [Message(from: 'A', to: 'B')]),
              GroupBranch(
                  label: 'fail', events: [Message(from: 'A', to: 'B')]),
            ],
          ),
        ]),
        measurer,
      );
      final transparent = scene.shapes
          .whereType<SceneBox>()
          .where((b) => b.fill.a == 0)
          .toList();
      expect(transparent, hasLength(1));
      final labelTab = scene.shapes
          .whereType<SceneBox>()
          .where((b) => b.label == 'alt')
          .toList();
      expect(labelTab, hasLength(1));
      // Two branches → one else divider line (dashed, no arrow head)
      final dividers = scene.shapes
          .whereType<SceneLine>()
          .where((l) =>
              l.dashed &&
              l.head == null &&
              l.from.dy == l.to.dy &&
              l.stroke != const Color(0xFF000000))
          .toList();
      expect(dividers, hasLength(1));
    });

    test('nested groups produce two label tabs', () {
      final scene = layout.layout(
        const SequenceDiagram(events: [
          Group(
            kind: GroupKind.alt,
            branches: [
              GroupBranch(events: [
                Group(
                  kind: GroupKind.loop,
                  branches: [
                    GroupBranch(events: [Message(from: 'A', to: 'B')]),
                  ],
                ),
              ]),
            ],
          ),
        ]),
        measurer,
      );
      final kinds = scene.shapes
          .whereType<SceneBox>()
          .where((b) => b.label == 'alt' || b.label == 'loop')
          .map((b) => b.label)
          .toSet();
      expect(kinds, {'alt', 'loop'});
    });

    group('actor kinds', () {
      for (final entry in const {
        ParticipantKind.actor: 'actor',
        ParticipantKind.boundary: 'boundary',
        ParticipantKind.control: 'control',
        ParticipantKind.entity: 'entity',
        ParticipantKind.database: 'database',
        ParticipantKind.collections: 'collections',
        ParticipantKind.queue: 'queue',
      }.entries) {
        test('${entry.value} emits SceneSymbol for top and bottom', () {
          final scene = layout.layout(
            SequenceDiagram(
              participants: [
                Participant(alias: 'A', kind: entry.key),
                const Participant(alias: 'B'),
              ],
              events: const [Message(from: 'A', to: 'B')],
            ),
            measurer,
          );
          final symbols = scene.shapes
              .whereType<SceneSymbol>()
              .where((s) => s.kind == entry.key)
              .toList();
          expect(symbols, hasLength(2));
          expect(symbols.every((s) => s.label == 'A'), isTrue);
        });
      }

      test('participant kind still emits SceneBox (no SceneSymbol)', () {
        final scene = layout.layout(
          const SequenceDiagram(
            participants: [Participant(alias: 'A')],
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        expect(scene.shapes.whereType<SceneSymbol>(), isEmpty);
        final aBoxes = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'A')
            .toList();
        expect(aBoxes, hasLength(2));
      });

      test('lifeline connects top symbol bottom to bottom symbol top', () {
        final scene = layout.layout(
          const SequenceDiagram(
            participants: [
              Participant(alias: 'A', kind: ParticipantKind.actor),
              Participant(alias: 'B'),
            ],
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final aSymbols = scene.shapes
            .whereType<SceneSymbol>()
            .where((s) => s.label == 'A')
            .toList()
          ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
        final lifeline = scene.shapes
            .whereType<SceneLine>()
            .where((l) =>
                l.dashed &&
                l.head == null &&
                l.strokeWidth == 0.5 &&
                (l.from.dx - aSymbols.first.rect.center.dx).abs() < 0.01)
            .single;
        expect(lifeline.from.dy, aSymbols.first.rect.bottom);
        expect(lifeline.to.dy, aSymbols.last.rect.top);
      });
    });

    group('arrow variants', () {
      SceneLine messageLine(Scene scene) => scene.shapes
          .whereType<SceneLine>()
          .firstWhere((l) => l.head != null);

      test('default forward message has filled head at "to" end', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [Message(from: 'A', to: 'B')]),
          measurer,
        );
        final line = messageLine(scene);
        expect(line.head, ArrowHead.filled);
        expect(line.headAtFrom, isFalse);
      });

      test('open head propagates from Message to SceneLine', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B', head: ArrowHead.open),
          ]),
          measurer,
        );
        expect(messageLine(scene).head, ArrowHead.open);
      });

      test('openCircle and cross heads propagate', () {
        final circleScene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B', head: ArrowHead.openCircle),
          ]),
          measurer,
        );
        expect(messageLine(circleScene).head, ArrowHead.openCircle);

        final crossScene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B', head: ArrowHead.cross),
          ]),
          measurer,
        );
        expect(messageLine(crossScene).head, ArrowHead.cross);
      });

      test('backward direction sets headAtFrom=true', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(
                from: 'A',
                to: 'B',
                direction: MessageDirection.backward),
          ]),
          measurer,
        );
        expect(messageLine(scene).headAtFrom, isTrue);
      });

      test('self-message reuses configured head', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'A', head: ArrowHead.cross),
          ]),
          measurer,
        );
        final heads = scene.shapes
            .whereType<SceneLine>()
            .where((l) => l.head != null)
            .toList();
        expect(heads, hasLength(1));
        expect(heads.single.head, ArrowHead.cross);
      });
    });

    group('arrow modifiers', () {
      test('hidden message emits no SceneLine but preserves Y advance', () {
        final visible = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Message(from: 'A', to: 'C'),
          ]),
          measurer,
        );
        final hidden = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Message(from: 'A', to: 'C', hidden: true),
          ]),
          measurer,
        );
        expect(hidden.size.height, visible.size.height);
        final hiddenMessageLines = hidden.shapes
            .whereType<SceneLine>()
            .where((l) => l.head != null)
            .toList();
        final visibleMessageLines = visible.shapes
            .whereType<SceneLine>()
            .where((l) => l.head != null)
            .toList();
        expect(hiddenMessageLines, hasLength(visibleMessageLines.length - 1));
      });

      test('colored message propagates stroke to SceneLine', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B', color: Color(0xFFFF0000)),
          ]),
          measurer,
        );
        final messageLine = scene.shapes
            .whereType<SceneLine>()
            .firstWhere((l) => l.head != null);
        expect(messageLine.stroke, const Color(0xFFFF0000));
      });

      test('hidden self-message preserves Y advance', () {
        final visible = layout.layout(
          const SequenceDiagram(
            participants: [Participant(alias: 'A'), Participant(alias: 'B')],
            events: [Message(from: 'A', to: 'A')],
          ),
          measurer,
        );
        final hidden = layout.layout(
          const SequenceDiagram(
            participants: [Participant(alias: 'A'), Participant(alias: 'B')],
            events: [Message(from: 'A', to: 'A', hidden: true)],
          ),
          measurer,
        );
        expect(hidden.size.height, visible.size.height);
        expect(
          hidden.shapes.whereType<SceneLine>().where((l) => l.head != null),
          isEmpty,
        );
      });
    });

    group('lifecycle', () {
      test('Create relocates the participant top actor box to the create Y',
          () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Message(from: 'A', to: 'C'),
            Create('C'),
          ]),
          measurer,
        );
        final cBoxes = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'C')
            .toList()
          ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
        expect(cBoxes, hasLength(2));
        final aBoxes = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'A')
            .toList()
          ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
        final aTopY = aBoxes.first.rect.top;
        expect(cBoxes.first.rect.top, greaterThan(aTopY));
      });

      test('Destroy omits the bottom actor box and emits an X mark', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Message(from: 'B', to: 'A'),
            Destroy('A'),
          ]),
          measurer,
        );
        final aBoxes = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'A')
            .toList();
        expect(aBoxes, hasLength(1));
        final aBoxes2 = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'B')
            .toList();
        expect(aBoxes2, hasLength(2));
        final aTopCenter = aBoxes.single.rect.center.dx;
        final crossLines = scene.shapes
            .whereType<SceneLine>()
            .where((l) =>
                !l.dashed &&
                l.head == null &&
                (l.from.dx - aTopCenter).abs() < 6 &&
                (l.to.dx - aTopCenter).abs() < 6 &&
                l.from.dy != l.to.dy)
            .toList();
        expect(crossLines, hasLength(2));
      });

      test('Destroy shortens the lifeline', () {
        final undamaged = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Message(from: 'B', to: 'A'),
          ]),
          measurer,
        );
        final damaged = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Message(from: 'B', to: 'A'),
            Destroy('A'),
          ]),
          measurer,
        );
        final aCenter = undamaged.shapes
            .whereType<SceneBox>()
            .firstWhere((b) => b.label == 'A')
            .rect
            .center
            .dx;
        SceneLine lifelineFor(Scene s) => s.shapes
            .whereType<SceneLine>()
            .where((l) =>
                l.dashed &&
                l.head == null &&
                l.strokeWidth == 0.5 &&
                (l.from.dx - aCenter).abs() < 0.01)
            .single;
        final undLine = lifelineFor(undamaged);
        final damLine = lifelineFor(damaged);
        expect(damLine.to.dy, lessThan(undLine.to.dy));
      });
    });

    group('participant box', () {
      test('box rectangle surrounds the actor box', () {
        final scene = layout.layout(
          const SequenceDiagram(
            participants: [Participant(alias: 'A')],
            boxes: [
              ParticipantBox(
                label: 'L',
                participants: [Participant(alias: 'A')],
              ),
            ],
            events: [Message(from: 'A', to: 'A')],
          ),
          measurer,
        );
        final topActorBox = scene.shapes
            .whereType<SceneBox>()
            .firstWhere((b) => b.label == 'A');
        final boxRects = scene.shapes
            .whereType<SceneBox>()
            .where((b) =>
                b.label == null &&
                b.rect.left < topActorBox.rect.left &&
                b.rect.right > topActorBox.rect.right &&
                b.rect.top <= topActorBox.rect.top)
            .toList();
        expect(boxRects, hasLength(1));
        expect(boxRects.single.rect.bottom, greaterThan(topActorBox.rect.bottom));

        final labelTexts = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'L')
            .toList();
        expect(labelTexts, hasLength(1));
        expect(labelTexts.single.offset.dy,
            lessThanOrEqualTo(topActorBox.rect.top));
      });

      test('colored box adopts the provided color', () {
        const blue = Color(0xFFADD8E6);
        final scene = layout.layout(
          const SequenceDiagram(
            participants: [Participant(alias: 'A')],
            boxes: [
              ParticipantBox(
                label: 'L',
                color: blue,
                participants: [Participant(alias: 'A')],
              ),
            ],
            events: [Message(from: 'A', to: 'A')],
          ),
          measurer,
        );
        final coloredBoxes = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.fill == blue && b.stroke == blue)
            .toList();
        expect(coloredBoxes, hasLength(1));
      });

      test('box is emitted before actor boxes in the shape list', () {
        final scene = layout.layout(
          const SequenceDiagram(
            participants: [Participant(alias: 'A')],
            boxes: [
              ParticipantBox(
                label: 'L',
                participants: [Participant(alias: 'A')],
              ),
            ],
            events: [Message(from: 'A', to: 'A')],
          ),
          measurer,
        );
        final firstActorIndex = scene.shapes.indexWhere(
            (s) => s is SceneBox && s.label == 'A');
        final boxIndex = scene.shapes.indexWhere(
            (s) => s is SceneBox && s.label == null && s.rect.height > 20);
        expect(boxIndex, greaterThanOrEqualTo(0));
        expect(boxIndex, lessThan(firstActorIndex));
      });
    });

    group('separators', () {
      test('title separator emits a labeled box and flanking lines', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Separator(kind: SeparatorKind.title, label: 'Phase 1'),
            Message(from: 'A', to: 'B'),
          ]),
          measurer,
        );
        final labelBoxes = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'Phase 1')
            .toList();
        expect(labelBoxes, hasLength(1));
        final centerY = labelBoxes.single.rect.center.dy;
        final flanks = scene.shapes
            .whereType<SceneLine>()
            .where((l) =>
                !l.dashed &&
                l.head == null &&
                (l.from.dy - centerY).abs() < 0.5 &&
                (l.to.dy - centerY).abs() < 0.5)
            .toList();
        expect(flanks.length, greaterThanOrEqualTo(2));
      });

      test('delay separator emits zigzag marks on each lifeline', () {
        final scene = layout.layout(
          const SequenceDiagram(
            participants: [Participant(alias: 'A'), Participant(alias: 'B')],
            events: [
              Message(from: 'A', to: 'B'),
              Separator(kind: SeparatorKind.delay, delayPixels: 30),
              Message(from: 'A', to: 'B'),
            ],
          ),
          measurer,
        );
        final aTopBox = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'A')
            .reduce((a, b) => a.rect.top < b.rect.top ? a : b);
        final cxA = aTopBox.rect.center.dx;
        final shortHorizontal = scene.shapes
            .whereType<SceneLine>()
            .where((l) =>
                !l.dashed &&
                l.head == null &&
                l.from.dy == l.to.dy &&
                (l.from.dx - cxA).abs() < 10 &&
                (l.to.dx - cxA).abs() < 10 &&
                (l.to.dx - l.from.dx).abs() < 20 &&
                (l.to.dx - l.from.dx).abs() > 1)
            .toList();
        expect(shortHorizontal.length, greaterThanOrEqualTo(2));
      });

      test('skip separator emits a "..." text', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Separator(kind: SeparatorKind.skip),
            Message(from: 'A', to: 'B'),
          ]),
          measurer,
        );
        final dots = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == '...')
            .toList();
        expect(dots, hasLength(1));
      });

      test('dash separator emits a dashed horizontal line', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Separator(kind: SeparatorKind.dash),
            Message(from: 'A', to: 'B'),
          ]),
          measurer,
        );
        final dashedHorizontals = scene.shapes
            .whereType<SceneLine>()
            .where((l) =>
                l.dashed &&
                l.head == null &&
                l.from.dy == l.to.dy &&
                (l.to.dx - l.from.dx).abs() > 50 &&
                l.strokeWidth == 1.0)
            .toList();
        expect(dashedHorizontals, hasLength(1));
      });
    });

    group('title/header/footer/caption', () {
      test('title shifts topActorY downward', () {
        final without = layout.layout(
          const SequenceDiagram(events: [Message(from: 'A', to: 'B')]),
          measurer,
        );
        final withTitle = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(title: 'My Diagram'),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final aBoxWithout = without.shapes
            .whereType<SceneBox>()
            .firstWhere((b) => b.label == 'A');
        final aBoxWith = withTitle.shapes
            .whereType<SceneBox>()
            .firstWhere((b) => b.label == 'A');
        expect(aBoxWith.rect.top, greaterThan(aBoxWithout.rect.top));
        expect(withTitle.size.height, greaterThan(without.size.height));
      });

      test('title text is emitted near the top', () {
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(title: 'Hello'),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final titleText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'Hello')
            .single;
        final aBox = scene.shapes
            .whereType<SceneBox>()
            .firstWhere((b) => b.label == 'A');
        expect(titleText.offset.dy, lessThan(aBox.rect.top));
      });

      test('header is emitted above title', () {
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              title: 'Title',
              header: HeaderFooter(text: 'Header'),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final headerText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'Header')
            .single;
        final titleText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'Title')
            .single;
        expect(headerText.offset.dy, lessThan(titleText.offset.dy));
      });

      test('caption is below diagram and footer below caption', () {
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              caption: 'Cap',
              footer: HeaderFooter(text: 'Foot'),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final aBoxes = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'A')
            .toList()
          ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
        final bottomActorBottom = aBoxes.last.rect.bottom;
        final captionText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'Cap')
            .single;
        final footerText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'Foot')
            .single;
        expect(captionText.offset.dy, greaterThanOrEqualTo(bottomActorBottom));
        expect(footerText.offset.dy, greaterThan(captionText.offset.dy));
      });

      test('footer left alignment uses padding from left', () {
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              footer: HeaderFooter(text: 'F', align: TextAlign.left),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final footerText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'F')
            .single;
        expect(footerText.offset.dx, lessThan(scene.size.width / 2));
      });

      test('footer right alignment is right-aligned', () {
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              footer: HeaderFooter(text: 'F', align: TextAlign.right),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final footerText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'F')
            .single;
        expect(footerText.offset.dx, greaterThan(scene.size.width / 2));
      });
    });

    group('legend', () {
      test('legend grows total scene height', () {
        final without = layout.layout(
          const SequenceDiagram(events: [Message(from: 'A', to: 'B')]),
          measurer,
        );
        final withLegend = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              legend: Legend(text: 'A legend body'),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        expect(withLegend.size.height, greaterThan(without.size.height));
      });

      test('legend emits a SceneBox and SceneText in the bottom region', () {
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              legend: Legend(text: 'Legend body text'),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final aBoxes = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'A')
            .toList()
          ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
        final bottomActorBottom = aBoxes.last.rect.bottom;
        final legendText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'Legend body text')
            .single;
        expect(legendText.offset.dy, greaterThanOrEqualTo(bottomActorBottom));
        final containing = scene.shapes
            .whereType<SceneBox>()
            .where((b) =>
                b.label == null &&
                b.rect.top >= bottomActorBottom &&
                b.rect.contains(legendText.offset))
            .toList();
        expect(containing, isNotEmpty);
      });

      test('legend right alignment places box on the right side', () {
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              legend: Legend(text: 'R', align: TextAlign.right),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final aBoxes = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'A')
            .toList()
          ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
        final bottomActorBottom = aBoxes.last.rect.bottom;
        final legendBox = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == null && b.rect.top >= bottomActorBottom)
            .first;
        expect(legendBox.rect.center.dx, greaterThan(scene.size.width / 2));
      });

      test('legend sits between diagram and caption/footer', () {
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              legend: Legend(text: 'L'),
              caption: 'Cap',
              footer: HeaderFooter(text: 'Foot'),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final legendText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'L')
            .single;
        final captionText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'Cap')
            .single;
        final footerText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'Foot')
            .single;
        expect(legendText.offset.dy, lessThan(captionText.offset.dy));
        expect(captionText.offset.dy, lessThan(footerText.offset.dy));
      });
    });

    group('newpage', () {
      test('NewPage between two messages emits a thick horizontal divider', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            NewPage(),
            Message(from: 'A', to: 'B'),
          ]),
          measurer,
        );
        final dividers = scene.shapes
            .whereType<SceneLine>()
            .where((l) =>
                !l.dashed &&
                l.head == null &&
                l.from.dy == l.to.dy &&
                l.strokeWidth > 2.0 &&
                (l.to.dx - l.from.dx).abs() > 50)
            .toList();
        expect(dividers, hasLength(1));
      });

      test('NewPage with title emits both divider and text', () {
        final scene = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            NewPage('Page Two'),
            Message(from: 'A', to: 'B'),
          ]),
          measurer,
        );
        final dividers = scene.shapes
            .whereType<SceneLine>()
            .where((l) =>
                !l.dashed &&
                l.head == null &&
                l.from.dy == l.to.dy &&
                l.strokeWidth > 2.0 &&
                (l.to.dx - l.from.dx).abs() > 50)
            .toList();
        expect(dividers, hasLength(1));
        final titleText = scene.shapes
            .whereType<SceneText>()
            .where((t) => t.text == 'Page Two')
            .toList();
        expect(titleText, hasLength(1));
        expect(titleText.single.offset.dy, lessThan(dividers.single.from.dy));
      });

      test('NewPage increases scene height vs. no page break', () {
        final without = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            Message(from: 'A', to: 'B'),
          ]),
          measurer,
        );
        final withBreak = layout.layout(
          const SequenceDiagram(events: [
            Message(from: 'A', to: 'B'),
            NewPage('Two'),
            Message(from: 'A', to: 'B'),
          ]),
          measurer,
        );
        expect(withBreak.size.height, greaterThan(without.size.height));
      });
    });

    test('AutoLayout dispatches SequenceDiagram to SequenceLayout', () {
      final auto = const AutoLayout().layout(
        const SequenceDiagram(
            events: [Message(from: 'A', to: 'B')]),
        measurer,
      );
      final direct = layout.layout(
        const SequenceDiagram(
            events: [Message(from: 'A', to: 'B')]),
        measurer,
      );
      expect(auto.size, direct.size);
      expect(auto.shapes.length, direct.shapes.length);
    });

    group('skinparam', () {
      test('backgroundColor propagates to Scene.background', () {
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              skin: SkinParams(backgroundColor: Color(0xFFFEEDFA)),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        expect(scene.background, const Color(0xFFFEEDFA));
      });

      test('noteBackgroundColor sets the SceneNote fill', () {
        const fill = Color(0xFF112233);
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              skin: SkinParams(noteBackgroundColor: fill),
            ),
            events: [
              Note(
                position: NotePosition.over,
                participants: ['A'],
                text: 'hi',
              ),
            ],
          ),
          measurer,
        );
        final note = scene.shapes.whereType<SceneNote>().single;
        expect(note.fill, fill);
      });

      test('noteBorderColor sets the SceneNote stroke', () {
        const stroke = Color(0xFF445566);
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              skin: SkinParams(noteBorderColor: stroke),
            ),
            events: [
              Note(
                position: NotePosition.over,
                participants: ['A'],
                text: 'hi',
              ),
            ],
          ),
          measurer,
        );
        final note = scene.shapes.whereType<SceneNote>().single;
        expect(note.stroke, stroke);
      });

      test('participantBackgroundColor and Border apply to actor SceneBoxes',
          () {
        const fill = Color(0xFFEEEEEE);
        const stroke = Color(0xFF334455);
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              skin: SkinParams(
                participantBackgroundColor: fill,
                participantBorderColor: stroke,
              ),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final actorBoxes =
            scene.shapes.whereType<SceneBox>().where((b) => b.label == 'A');
        expect(actorBoxes, isNotEmpty);
        for (final b in actorBoxes) {
          expect(b.fill, fill);
          expect(b.stroke, stroke);
        }
      });

      test('sequenceArrowColor is used when message has no explicit color', () {
        const arrow = Color(0xFFAABBCC);
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              skin: SkinParams(sequenceArrowColor: arrow),
            ),
            events: [Message(from: 'A', to: 'B', label: 'hi')],
          ),
          measurer,
        );
        final messageLine = scene.shapes
            .whereType<SceneLine>()
            .where((l) => l.head != null)
            .single;
        expect(messageLine.stroke, arrow);
      });

      test('explicit Message.color wins over sequenceArrowColor', () {
        const arrow = Color(0xFFAABBCC);
        const explicit = Color(0xFFFF0000);
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              skin: SkinParams(sequenceArrowColor: arrow),
            ),
            events: [Message(from: 'A', to: 'B', color: explicit)],
          ),
          measurer,
        );
        final messageLine = scene.shapes
            .whereType<SceneLine>()
            .where((l) => l.head != null)
            .single;
        expect(messageLine.stroke, explicit);
      });

      test('sequenceLifeLineBackgroundColor sets lifeline stroke', () {
        const life = Color(0xFF998877);
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              skin: SkinParams(sequenceLifeLineBackgroundColor: life),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final lifelines = scene.shapes
            .whereType<SceneLine>()
            .where((l) => l.dashed && l.head == null)
            .toList();
        expect(lifelines, isNotEmpty);
        for (final l in lifelines) {
          expect(l.stroke, life);
        }
      });

      test('defaultFontSize is applied to actor labels', () {
        const fontSize = 22.0;
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              skin: SkinParams(defaultFontSize: fontSize),
            ),
            events: [Message(from: 'A', to: 'B')],
          ),
          measurer,
        );
        final actorBox = scene.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'A')
            .first;
        expect(actorBox.textStyle.fontSize, fontSize);
      });

      test('defaultFontSize is applied to note text style', () {
        const fontSize = 18.0;
        final scene = layout.layout(
          const SequenceDiagram(
            decorations: DiagramDecorations(
              skin: SkinParams(defaultFontSize: fontSize),
            ),
            events: [
              Note(
                position: NotePosition.over,
                participants: ['A'],
                text: 'hi',
              ),
            ],
          ),
          measurer,
        );
        final note = scene.shapes.whereType<SceneNote>().single;
        expect(note.textStyle.fontSize, fontSize);
      });
    });
  });

  group('ClassLayout', () {
    const layout = ClassLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram returns empty scene', () {
      final scene = layout.layout(const ClassDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('single class emits outer box + header box + name text', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(name: 'Foo'),
        ]),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(boxes, hasLength(2));
      expect(texts.where((t) => t.text == 'Foo'), hasLength(1));
    });

    test('class with two members emits two body text lines plus the vis chars',
        () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(name: 'Foo', members: [
            Field(name: 'x', type: 'int'),
            Method(name: 'go', signature: 'go()'),
          ]),
        ]),
        measurer,
      );
      final texts = scene.shapes.whereType<SceneText>().toList();
      // header name + 2 visibility chars + 2 body strings = 5
      expect(texts, hasLength(5));
    });

    test('two classes side-by-side do not overlap', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(name: 'A'),
          ClassDecl(name: 'B'),
        ]),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      // outer boxes are the largest rectangles of each class
      final outers = <Rect>[];
      for (final b in boxes) {
        if (outers.every((r) => !r.overlaps(b.rect))) {
          // skip header boxes which are contained in outer
        }
        outers.add(b.rect);
      }
      // Walk through pairs and ensure no two outer-class boxes overlap.
      final classOuters = boxes
          .where((b) => b.label == null)
          .map((b) => b.rect)
          .toList();
      for (var i = 0; i < classOuters.length; i++) {
        for (var j = i + 1; j < classOuters.length; j++) {
          if (classOuters[i] == classOuters[j]) continue;
          // Either disjoint or one fully contains the other (header in body)
          if (classOuters[i].overlaps(classOuters[j])) {
            final iContainsJ = classOuters[i].contains(classOuters[j].topLeft) &&
                classOuters[i].contains(classOuters[j].bottomRight);
            final jContainsI = classOuters[j].contains(classOuters[i].topLeft) &&
                classOuters[j].contains(classOuters[i].bottomRight);
            expect(iContainsJ || jContainsI, isTrue,
                reason:
                    'class rectangles overlap: ${classOuters[i]} vs ${classOuters[j]}');
          }
        }
      }
    });

    test('inheritance edge emits a line between the two boxes', () {
      final scene = layout.layout(
        const ClassDiagram(
          classes: [ClassDecl(name: 'A'), ClassDecl(name: 'B')],
          relationships: [
            Relationship(
              from: 'A',
              to: 'B',
              kind: RelationshipKind.inheritance,
            ),
          ],
        ),
        measurer,
      );
      final lines = scene.shapes.whereType<SceneLine>().toList();
      expect(lines, hasLength(1));
      expect(lines.single.head, ArrowHead.triangle);
      expect(lines.single.headAtFrom, isTrue);
    });

    test('composition uses filled diamond head at \'from\' end', () {
      final scene = layout.layout(
        const ClassDiagram(
          classes: [ClassDecl(name: 'A'), ClassDecl(name: 'B')],
          relationships: [
            Relationship(
              from: 'A',
              to: 'B',
              kind: RelationshipKind.composition,
            ),
          ],
        ),
        measurer,
      );
      final line = scene.shapes.whereType<SceneLine>().single;
      expect(line.head, ArrowHead.filledDiamond);
      expect(line.headAtFrom, isTrue);
    });

    test('directed association uses open arrow at \'to\' end', () {
      final scene = layout.layout(
        const ClassDiagram(
          classes: [ClassDecl(name: 'A'), ClassDecl(name: 'B')],
          relationships: [
            Relationship(
              from: 'A',
              to: 'B',
              kind: RelationshipKind.directedAssociation,
            ),
          ],
        ),
        measurer,
      );
      final line = scene.shapes.whereType<SceneLine>().single;
      expect(line.head, ArrowHead.open);
      expect(line.headAtFrom, isFalse);
    });

    test('dependency uses dashed line', () {
      final scene = layout.layout(
        const ClassDiagram(
          classes: [ClassDecl(name: 'A'), ClassDecl(name: 'B')],
          relationships: [
            Relationship(
              from: 'A',
              to: 'B',
              kind: RelationshipKind.dependency,
            ),
          ],
        ),
        measurer,
      );
      final line = scene.shapes.whereType<SceneLine>().single;
      expect(line.dashed, isTrue);
    });

    test('object emits outer box + header box + underlined name text', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(name: 'alice', kind: ClassKind.object_),
        ]),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(boxes, hasLength(2));
      final header = texts.singleWhere((t) => t.text == 'alice');
      expect(header.textStyle.decoration, TextDecoration.underline);
    });

    test('typed object header reads "alice : Person" and is underlined', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(
            name: 'alice',
            kind: ClassKind.object_,
            instanceOf: 'Person',
          ),
        ]),
        measurer,
      );
      final texts = scene.shapes.whereType<SceneText>().toList();
      final header = texts.singleWhere((t) => t.text == 'alice : Person');
      expect(header.textStyle.decoration, TextDecoration.underline);
    });

    test('object with attributes emits "name = value" body lines', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(
            name: 'alice',
            kind: ClassKind.object_,
            members: [
              Attribute(name: 'name', value: 'Alice'),
              Attribute(name: 'age', value: '30'),
            ],
          ),
        ]),
        measurer,
      );
      final texts =
          scene.shapes.whereType<SceneText>().map((t) => t.text).toList();
      expect(texts, contains('name = Alice'));
      expect(texts, contains('age = 30'));
    });

    test('map gets a <<map>> stereotype label and key => value lines', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(
            name: 'config',
            kind: ClassKind.map_,
            members: [
              Attribute(name: 'host', value: 'localhost', isMap: true),
            ],
          ),
        ]),
        measurer,
      );
      final texts =
          scene.shapes.whereType<SceneText>().map((t) => t.text).toList();
      expect(texts, contains('<<map>>'));
      expect(texts, contains('host => localhost'));
    });

    test('entity gets a <<entity>> stereotype label', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(name: 'E', kind: ClassKind.entity_),
        ]),
        measurer,
      );
      final texts =
          scene.shapes.whereType<SceneText>().map((t) => t.text).toList();
      expect(texts, contains('<<entity>>'));
    });

    test('crow\'s foot relationship emits SceneCrowFoot at both ends', () {
      final scene = layout.layout(
        const ClassDiagram(
          classes: [
            ClassDecl(name: 'A', kind: ClassKind.entity_),
            ClassDecl(name: 'B', kind: ClassKind.entity_),
          ],
          relationships: [
            Relationship(
              from: 'A',
              to: 'B',
              kind: RelationshipKind.association,
              fromCrowFoot: CrowFoot.one,
              toCrowFoot: CrowFoot.zeroOrMany,
            ),
          ],
        ),
        measurer,
      );
      final feet = scene.shapes.whereType<SceneCrowFoot>().toList();
      expect(feet, hasLength(2));
      final atFrom = feet.firstWhere((f) => f.kind == CrowFoot.one);
      final atTo = feet.firstWhere((f) => f.kind == CrowFoot.zeroOrMany);
      expect(atFrom.position, isNot(atTo.position));
      final lines = scene.shapes.whereType<SceneLine>().toList();
      expect(lines.single.head, isNull);
    });

    test('field with leading * and <<PK>> renders body with markers', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(name: 'E', kind: ClassKind.entity_, members: [
            Field(name: 'id', type: 'int', required: true, stereotype: 'PK'),
          ]),
        ]),
        measurer,
      );
      final bodyTexts = scene.shapes
          .whereType<SceneText>()
          .map((t) => t.text)
          .toList();
      expect(bodyTexts.any((t) => t.contains('* id: int <<PK>>')), isTrue);
    });

    test('class header stereotype is rendered above the name', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(name: 'Order', stereotype: 'Aggregate'),
        ]),
        measurer,
      );
      final texts = scene.shapes
          .whereType<SceneText>()
          .map((t) => t.text)
          .toList();
      expect(texts, contains('<<Aggregate>>'));
      expect(texts, contains('Order'));
    });

    test('generics are appended to the header name', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(name: 'AggregateRoot', generics: 'ID'),
        ]),
        measurer,
      );
      final texts = scene.shapes
          .whereType<SceneText>()
          .map((t) => t.text)
          .toList();
      expect(texts, contains('AggregateRoot<ID>'));
    });

    test('record kind shows <<record>> stereotype', () {
      final scene = layout.layout(
        const ClassDiagram(classes: [
          ClassDecl(name: 'Money', kind: ClassKind.record_),
        ]),
        measurer,
      );
      final texts = scene.shapes
          .whereType<SceneText>()
          .map((t) => t.text)
          .toList();
      expect(texts, contains('<<record>>'));
    });

    test('free notes are emitted as SceneNote shapes', () {
      final scene = layout.layout(
        const ClassDiagram(
          classes: [ClassDecl(name: 'Foo')],
          freeNotes: [FreeNote(alias: 'N1', text: 'hello')],
          relationships: [
            Relationship(
                from: 'N1', to: 'Foo', kind: RelationshipKind.link),
          ],
        ),
        measurer,
      );
      final notes = scene.shapes.whereType<SceneNote>().toList();
      expect(notes, hasLength(1));
      expect(notes.single.text, 'hello');
      final dashed =
          scene.shapes.whereType<SceneLine>().where((l) => l.dashed).toList();
      expect(dashed, isNotEmpty);
    });

    test('attached note connects via a dashed line to its class', () {
      final scene = layout.layout(
        const ClassDiagram(
          classes: [ClassDecl(name: 'Foo')],
          freeNotes: [
            FreeNote(alias: '__note_0', text: 'inv', attachedTo: 'Foo'),
          ],
        ),
        measurer,
      );
      final notes = scene.shapes.whereType<SceneNote>().toList();
      expect(notes, hasLength(1));
      final dashed =
          scene.shapes.whereType<SceneLine>().where((l) => l.dashed).toList();
      expect(dashed, isNotEmpty);
    });
  });

  group('UseCaseLayout', () {
    const layout = UseCaseLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram returns empty scene', () {
      final scene = layout.layout(const UseCaseDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('actor emits a SceneSymbol with actor kind', () {
      final scene = layout.layout(
        const UseCaseDiagram(nodes: [
          UseCaseNode(
              alias: 'User', label: 'User', kind: UseCaseNodeKind.actor),
        ]),
        measurer,
      );
      final symbols = scene.shapes.whereType<SceneSymbol>().toList();
      expect(symbols, hasLength(1));
      expect(symbols.single.kind, ParticipantKind.actor);
      expect(symbols.single.label, 'User');
    });

    test('usecase emits a SceneEllipse with the label', () {
      final scene = layout.layout(
        const UseCaseDiagram(nodes: [
          UseCaseNode(
              alias: 'UC1',
              label: 'Browse Products',
              kind: UseCaseNodeKind.useCase),
        ]),
        measurer,
      );
      final ellipses = scene.shapes.whereType<SceneEllipse>().toList();
      expect(ellipses, hasLength(1));
      expect(ellipses.single.label, 'Browse Products');
    });

    test('boundary emits a SceneBox around contained use cases', () {
      final scene = layout.layout(
        const UseCaseDiagram(
          nodes: [
            UseCaseNode(
                alias: 'UC1', label: 'A', kind: UseCaseNodeKind.useCase),
            UseCaseNode(
                alias: 'UC2', label: 'B', kind: UseCaseNodeKind.useCase),
          ],
          boundaries: [
            UseCaseBoundary(
                label: 'System', containedAliases: ['UC1', 'UC2']),
          ],
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      final ellipses = scene.shapes.whereType<SceneEllipse>().toList();
      expect(boxes, hasLength(1));
      expect(ellipses, hasLength(2));
      final boundaryRect = boxes.single.rect;
      for (final e in ellipses) {
        expect(boundaryRect.contains(e.rect.topLeft), isTrue);
        expect(boundaryRect.contains(e.rect.bottomRight), isTrue);
      }
    });

    test('relation emits a SceneLine between actor and use case', () {
      final scene = layout.layout(
        const UseCaseDiagram(
          nodes: [
            UseCaseNode(
                alias: 'User', label: 'User', kind: UseCaseNodeKind.actor),
            UseCaseNode(
                alias: 'UC1', label: 'Login', kind: UseCaseNodeKind.useCase),
          ],
          relations: [
            UseCaseRelation(from: 'User', to: 'UC1'),
          ],
        ),
        measurer,
      );
      final lines = scene.shapes.whereType<SceneLine>().toList();
      expect(lines, hasLength(1));
      expect(lines.single.head, ArrowHead.open);
    });

    test('dashed include relation emits dashed line with label', () {
      final scene = layout.layout(
        const UseCaseDiagram(
          nodes: [
            UseCaseNode(
                alias: 'A', label: 'A', kind: UseCaseNodeKind.useCase),
            UseCaseNode(
                alias: 'B', label: 'B', kind: UseCaseNodeKind.useCase),
          ],
          relations: [
            UseCaseRelation(
              from: 'A',
              to: 'B',
              lineStyle: LineStyle.dashed,
              label: '<<include>>',
            ),
          ],
        ),
        measurer,
      );
      final line = scene.shapes.whereType<SceneLine>().single;
      expect(line.dashed, isTrue);
      expect(line.label, '<<include>>');
    });

    test('full example emits 2 actors, 4 ellipses, 1 boundary box', () {
      final scene = layout.layout(
        const UseCaseDiagram(
          nodes: [
            UseCaseNode(
                alias: 'User', label: 'User', kind: UseCaseNodeKind.actor),
            UseCaseNode(
                alias: 'Admin', label: 'Admin', kind: UseCaseNodeKind.actor),
            UseCaseNode(
                alias: 'UC1',
                label: 'Browse',
                kind: UseCaseNodeKind.useCase),
            UseCaseNode(
                alias: 'UC2',
                label: 'Place Order',
                kind: UseCaseNodeKind.useCase),
            UseCaseNode(
                alias: 'UC3',
                label: 'Manage',
                kind: UseCaseNodeKind.useCase),
            UseCaseNode(
                alias: 'UC4', label: 'Login', kind: UseCaseNodeKind.useCase),
          ],
          boundaries: [
            UseCaseBoundary(
              label: 'System',
              containedAliases: ['UC1', 'UC2', 'UC3', 'UC4'],
            ),
          ],
        ),
        measurer,
      );
      expect(
          scene.shapes
              .whereType<SceneSymbol>()
              .where((s) => s.kind == ParticipantKind.actor)
              .length,
          2);
      expect(scene.shapes.whereType<SceneEllipse>().length, 4);
      expect(scene.shapes.whereType<SceneBox>().length, 1);
    });
  });

  group('ActivityLayout', () {
    const layout = ActivityLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram returns empty scene', () {
      final scene = layout.layout(const ActivityDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('start emits a filled circle', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [StartNode()]),
        measurer,
      );
      final circles = scene.shapes.whereType<SceneCircle>().toList();
      expect(circles, hasLength(1));
      expect(circles.single.ring, isFalse);
    });

    test('stop emits a ring circle', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [StopNode()]),
        measurer,
      );
      final circles = scene.shapes.whereType<SceneCircle>().toList();
      expect(circles, hasLength(1));
      expect(circles.single.ring, isTrue);
    });

    test('action emits a rounded box with the label', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [Action(text: 'Hello')]),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      expect(boxes, hasLength(1));
      expect(boxes.single.label, 'Hello');
    });

    test('if block emits a diamond and a merge diamond', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [
          IfBlock(
            branches: [
              IfBranch(condition: 'ok?', body: [Action(text: 'Yes path')]),
            ],
            elseBody: [Action(text: 'No path')],
          ),
        ]),
        measurer,
      );
      final diamonds = scene.shapes.whereType<SceneDiamond>().toList();
      expect(diamonds.length, greaterThanOrEqualTo(2));
    });

    test('if/else places branches side-by-side', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [
          IfBlock(
            branches: [
              IfBranch(condition: 'ok?', body: [Action(text: 'Yes path')]),
            ],
            elseBody: [Action(text: 'No path')],
          ),
        ]),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      expect(boxes, hasLength(2));
      final thenBox =
          boxes.firstWhere((b) => b.label == 'Yes path');
      final elseBox =
          boxes.firstWhere((b) => b.label == 'No path');
      expect(thenBox.rect.left, lessThan(elseBox.rect.left));
      expect(
        (thenBox.rect.top - elseBox.rect.top).abs() < 1,
        isTrue,
        reason: 'side-by-side branches share a row',
      );
    });

    test('if/else merge diamond is centered between and below branches', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [
          IfBlock(
            branches: [
              IfBranch(condition: 'ok?', body: [Action(text: 'Yes')]),
            ],
            elseBody: [Action(text: 'No')],
          ),
        ]),
        measurer,
      );
      final diamonds = scene.shapes.whereType<SceneDiamond>().toList();
      expect(diamonds, hasLength(2));
      final decision = diamonds[0];
      final merge = diamonds[1];
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final maxBranchBottom = boxes.fold<double>(
          0, (a, b) => b.rect.bottom > a ? b.rect.bottom : a);
      expect(merge.rect.top, greaterThan(maxBranchBottom));
      expect(
        (merge.rect.center.dx - decision.rect.center.dx).abs() < 1,
        isTrue,
      );
    });

    test('nested if expands its parent column width', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [
          IfBlock(
            branches: [
              IfBranch(
                condition: 'outer?',
                body: [
                  IfBlock(
                    branches: [
                      IfBranch(
                        condition: 'inner?',
                        body: [Action(text: 'Inner yes')],
                      ),
                    ],
                    elseBody: [Action(text: 'Inner no')],
                  ),
                ],
              ),
            ],
            elseBody: [Action(text: 'Outer no')],
          ),
        ]),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final innerYes = boxes.firstWhere((b) => b.label == 'Inner yes');
      final innerNo = boxes.firstWhere((b) => b.label == 'Inner no');
      final outerNo = boxes.firstWhere((b) => b.label == 'Outer no');
      expect(innerYes.rect.left, lessThan(innerNo.rect.left));
      expect(innerNo.rect.right, lessThan(outerNo.rect.left));
    });

    test('while emits a diamond and connects body', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [
          WhileBlock(condition: 'more?', body: [Action(text: 'Item')]),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneDiamond>(), hasLength(1));
      expect(scene.shapes.whereType<SceneRoundedBox>(), hasLength(1));
    });

    test('fork emits two thick bars and one rounded box per branch', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [
          ForkBlock(branches: [
            [Action(text: 'A')],
            [Action(text: 'B')],
          ]),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneBox>(), hasLength(2));
      expect(scene.shapes.whereType<SceneRoundedBox>(), hasLength(2));
    });

    test('fork places branches side-by-side between two thick bars', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [
          ForkBlock(branches: [
            [Action(text: 'A')],
            [Action(text: 'B')],
            [Action(text: 'C')],
          ]),
        ]),
        measurer,
      );
      final bars = scene.shapes.whereType<SceneBox>().toList();
      expect(bars, hasLength(2));
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      expect(boxes, hasLength(3));
      final a = boxes.firstWhere((b) => b.label == 'A');
      final b = boxes.firstWhere((b) => b.label == 'B');
      final c = boxes.firstWhere((b) => b.label == 'C');
      expect(a.rect.left, lessThan(b.rect.left));
      expect(b.rect.left, lessThan(c.rect.left));
      expect(
        (a.rect.top - b.rect.top).abs() < 1,
        isTrue,
        reason: 'parallel branches sit on the same row',
      );
      final topBar = bars[0];
      final bottomBar = bars[1];
      expect(topBar.rect.top, lessThan(a.rect.top));
      expect(bottomBar.rect.top, greaterThan(a.rect.bottom));
    });

    test('connects sequential nodes with arrow lines', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [
          StartNode(),
          Action(text: 'Do'),
          StopNode(),
        ]),
        measurer,
      );
      final lines = scene.shapes.whereType<SceneLine>().toList();
      expect(lines.length, greaterThanOrEqualTo(2));
      for (final l in lines) {
        expect(l.head, isNotNull);
      }
    });

    test('sequence ending in detach produces no trailing arrow', () {
      final withDetach = layout.layout(
        const ActivityDiagram(nodes: [
          Action(text: 'A'),
          Action(text: 'B'),
          Detach(),
        ]),
        measurer,
      );
      final withoutDetach = layout.layout(
        const ActivityDiagram(nodes: [
          Action(text: 'A'),
          Action(text: 'B'),
        ]),
        measurer,
      );
      final arrowsWith = withDetach.shapes
          .whereType<SceneLine>()
          .where((l) => l.head != null)
          .toList();
      final arrowsWithout = withoutDetach.shapes
          .whereType<SceneLine>()
          .where((l) => l.head != null)
          .toList();
      expect(arrowsWith.length, arrowsWithout.length,
          reason: 'detach must not introduce a new outgoing arrow');
    });

    test('sequence ending in kill emits two crossed lines', () {
      final scene = layout.layout(
        const ActivityDiagram(nodes: [
          Action(text: 'A'),
          Kill(),
        ]),
        measurer,
      );
      final crossLines = scene.shapes
          .whereType<SceneLine>()
          .where((l) =>
              l.head == null &&
              (l.from.dx - l.to.dx).abs() > 0 &&
              (l.from.dy - l.to.dy).abs() > 0)
          .toList();
      expect(crossLines, hasLength(2));
    });

    test('parses and lays out the nested-partitions terminator sample', () {
      const src = '@startuml\n'
          'title Incident response workflow with partitions, detach, kill, fork, and repeat\n'
          '\n'
          'start\n'
          'partition "Detector" {\n'
          '  :Receive alert;\n'
          '  if (Duplicate?) then (yes)\n'
          '    :Attach to existing incident;\n'
          '    detach\n'
          '  else (no)\n'
          '    :Create incident;\n'
          '  endif\n'
          '}\n'
          '\n'
          'partition "Triage" {\n'
          '  repeat\n'
          '    :Collect logs;\n'
          '    :Query metrics;\n'
          '    if (Signal sufficient?) then (yes)\n'
          '      break\n'
          '    else (no)\n'
          '      :Ask service owner;\n'
          '    endif\n'
          '  repeat while (within 10 min?) is (yes)\n'
          '}\n'
          '\n'
          'fork\n'
          '  partition "Comms" {\n'
          '    :Post status page update;\n'
          '    :Notify stakeholders;\n'
          '  }\n'
          'fork again\n'
          '  partition "Mitigation" {\n'
          '    if (Feature flag exists?) then (yes)\n'
          '      :Disable risky feature;\n'
          '    else (no)\n'
          '      :Rollback deployment;\n'
          '      if (Rollback fails?) then (yes)\n'
          '        kill\n'
          '      endif\n'
          '    endif\n'
          '  }\n'
          'fork again\n'
          '  partition "Evidence" {\n'
          '    :Snapshot dashboards;\n'
          '    :Export traces;\n'
          '  }\n'
          'end fork\n'
          '\n'
          'while (Error rate above SLO?) is (yes)\n'
          '  :Apply next mitigation;\n'
          'endwhile (no)\n'
          ':Write postmortem draft;\n'
          'stop\n'
          '@enduml\n';
      final tokens = Lexer().tokenize(src);
      final diagram = Parser().parse(tokens) as ActivityDiagram;
      final scene = layout.layout(diagram, measurer);
      expect(scene.size.width, greaterThan(0));
      expect(scene.size.height, greaterThan(0));
      final crossLines = scene.shapes
          .whereType<SceneLine>()
          .where((l) =>
              l.head == null &&
              (l.from.dx - l.to.dx).abs() > 0 &&
              (l.from.dy - l.to.dy).abs() > 0)
          .toList();
      expect(crossLines.length, greaterThanOrEqualTo(2),
          reason: 'kill should emit two crossed lines');
    });
  });

  group('StateLayout', () {
    const layout = StateLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram returns empty scene', () {
      final scene = layout.layout(const StateDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('simple state renders as rounded box', () {
      final scene = layout.layout(
        const StateDiagram(states: [StateDecl(name: 'Idle')]),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      expect(boxes, hasLength(1));
      expect(boxes.single.label, 'Idle');
    });

    test('initial pseudo-state renders as filled circle', () {
      final scene = layout.layout(
        const StateDiagram(
          states: [StateDecl(name: 'Idle')],
          transitions: [StateTransition(from: '[*]', to: 'Idle')],
        ),
        measurer,
      );
      final circles = scene.shapes.whereType<SceneCircle>().toList();
      expect(circles, hasLength(1));
      expect(circles.single.ring, isFalse);
    });

    test('final pseudo-state renders as ring circle', () {
      final scene = layout.layout(
        const StateDiagram(
          states: [StateDecl(name: 'Done')],
          transitions: [StateTransition(from: 'Done', to: '[*]')],
        ),
        measurer,
      );
      final ringed = scene.shapes
          .whereType<SceneCircle>()
          .where((c) => c.ring)
          .toList();
      expect(ringed, hasLength(1));
    });

    test('initial and final emit two distinct circles', () {
      final scene = layout.layout(
        const StateDiagram(
          states: [StateDecl(name: 'Idle')],
          transitions: [
            StateTransition(from: '[*]', to: 'Idle'),
            StateTransition(from: 'Idle', to: '[*]'),
          ],
        ),
        measurer,
      );
      final circles = scene.shapes.whereType<SceneCircle>().toList();
      expect(circles, hasLength(2));
      expect(circles.where((c) => c.ring), hasLength(1));
      expect(circles.where((c) => !c.ring), hasLength(1));
    });

    test('composite state emits multiple rounded boxes', () {
      final scene = layout.layout(
        const StateDiagram(
          states: [
            StateDecl(
              name: 'Outer',
              nestedStates: [
                StateDecl(name: 'Inner1'),
                StateDecl(name: 'Inner2'),
              ],
              nestedTransitions: [
                StateTransition(from: 'Inner1', to: 'Inner2'),
              ],
            ),
          ],
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      expect(boxes.length, greaterThanOrEqualTo(3));
    });

    test('concurrent regions emit a dashed divider line', () {
      final scene = layout.layout(
        const StateDiagram(
          states: [
            StateDecl(
              name: 'Para',
              concurrentRegions: [
                [StateDecl(name: 'A')],
                [StateDecl(name: 'B')],
              ],
              nestedTransitions: [],
            ),
          ],
        ),
        measurer,
      );
      final dashed = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.dashed)
          .toList();
      expect(dashed, hasLength(1));
    });

    test('transitions render as lines with arrow heads', () {
      final scene = layout.layout(
        const StateDiagram(
          states: [StateDecl(name: 'A'), StateDecl(name: 'B')],
          transitions: [StateTransition(from: 'A', to: 'B', label: 'go')],
        ),
        measurer,
      );
      final lines = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head != null)
          .toList();
      expect(lines, hasLength(1));
    });
  });

  group('ComponentLayout', () {
    const layout = ComponentLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram returns empty scene', () {
      final scene = layout.layout(const ComponentDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('component emits a SceneBox with stereotype text', () {
      final scene = layout.layout(
        const ComponentDiagram(nodes: [
          ComponentNode(
              alias: 'Web', label: 'Web', kind: ComponentNodeKind.component),
        ]),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(boxes, hasLength(1));
      expect(texts.map((t) => t.text), contains('<<component>>'));
      expect(texts.map((t) => t.text), contains('Web'));
    });

    test('interface emits a ring circle with label', () {
      final scene = layout.layout(
        const ComponentDiagram(nodes: [
          ComponentNode(
              alias: 'HTTP', label: 'HTTP', kind: ComponentNodeKind.interface),
        ]),
        measurer,
      );
      final circles = scene.shapes.whereType<SceneCircle>().toList();
      expect(circles, hasLength(1));
      expect(circles.single.ring, isTrue);
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(texts.map((t) => t.text), contains('HTTP'));
    });

    test('package container emits a box that wraps contained components', () {
      final scene = layout.layout(
        const ComponentDiagram(
          nodes: [
            ComponentNode(
                alias: 'A', label: 'A', kind: ComponentNodeKind.component),
            ComponentNode(
                alias: 'B', label: 'B', kind: ComponentNodeKind.component),
          ],
          containers: [
            ComponentContainer(
              label: 'Backend',
              kind: ContainerKind.package,
              nodeAliases: ['A', 'B'],
            ),
          ],
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      expect(boxes.length, greaterThanOrEqualTo(3));
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(texts.map((t) => t.text), contains('Backend'));
    });

    test('node container emits 3D shading lines', () {
      final scene = layout.layout(
        const ComponentDiagram(
          nodes: [
            ComponentNode(
                alias: 'P', label: 'P', kind: ComponentNodeKind.component),
          ],
          containers: [
            ComponentContainer(
              label: 'Server',
              kind: ContainerKind.node,
              nodeAliases: ['P'],
            ),
          ],
        ),
        measurer,
      );
      final lines =
          scene.shapes.whereType<SceneLine>().where((l) => l.head == null).toList();
      expect(lines.length, greaterThanOrEqualTo(3));
    });

    test('cloud container emits a rounded box', () {
      final scene = layout.layout(
        const ComponentDiagram(
          nodes: [
            ComponentNode(
                alias: 'L', label: 'L', kind: ComponentNodeKind.component),
          ],
          containers: [
            ComponentContainer(
              label: 'AWS',
              kind: ContainerKind.cloud,
              nodeAliases: ['L'],
            ),
          ],
        ),
        measurer,
      );
      final rounded = scene.shapes.whereType<SceneRoundedBox>().toList();
      expect(rounded, hasLength(1));
    });

    test('frame container emits a notch box plus the frame body', () {
      final scene = layout.layout(
        const ComponentDiagram(
          nodes: [
            ComponentNode(
                alias: 'X', label: 'X', kind: ComponentNodeKind.component),
          ],
          containers: [
            ComponentContainer(
              label: 'F',
              kind: ContainerKind.frame,
              nodeAliases: ['X'],
            ),
          ],
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      expect(boxes.length, greaterThanOrEqualTo(3));
    });

    test('nested containers place inner container inside outer', () {
      final scene = layout.layout(
        const ComponentDiagram(
          nodes: [
            ComponentNode(
                alias: 'I',
                label: 'Inside',
                kind: ComponentNodeKind.component),
          ],
          containers: [
            ComponentContainer(
              label: 'Outer',
              kind: ContainerKind.package,
              nestedContainers: [
                ComponentContainer(
                  label: 'Inner',
                  kind: ContainerKind.node,
                  nodeAliases: ['I'],
                ),
              ],
            ),
          ],
        ),
        measurer,
      );
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(texts.map((t) => t.text), containsAll(['Outer', 'Inner', 'Inside']));
    });

    test('relation emits a SceneLine with arrow head', () {
      final scene = layout.layout(
        const ComponentDiagram(
          nodes: [
            ComponentNode(
                alias: 'A', label: 'A', kind: ComponentNodeKind.component),
            ComponentNode(
                alias: 'B', label: 'B', kind: ComponentNodeKind.component),
          ],
          relations: [
            ComponentRelation(from: 'A', to: 'B'),
          ],
        ),
        measurer,
      );
      final lines =
          scene.shapes.whereType<SceneLine>().where((l) => l.head != null).toList();
      expect(lines, hasLength(1));
      expect(lines.single.head, ArrowHead.open);
    });

    test('dashed relation emits dashed line with label', () {
      final scene = layout.layout(
        const ComponentDiagram(
          nodes: [
            ComponentNode(
                alias: 'A', label: 'A', kind: ComponentNodeKind.component),
            ComponentNode(
                alias: 'B', label: 'B', kind: ComponentNodeKind.component),
          ],
          relations: [
            ComponentRelation(
              from: 'A',
              to: 'B',
              lineStyle: LineStyle.dashed,
              label: 'depends',
            ),
          ],
        ),
        measurer,
      );
      final dashedLine = scene.shapes
          .whereType<SceneLine>()
          .firstWhere((l) => l.dashed && l.head != null);
      expect(dashedLine.label, 'depends');
    });

    test('artifact emits a SceneNote shape with its label', () {
      final scene = layout.layout(
        const ComponentDiagram(nodes: [
          ComponentNode(
              alias: 'Config',
              label: 'config.yml',
              kind: ComponentNodeKind.artifact),
        ]),
        measurer,
      );
      final notes = scene.shapes.whereType<SceneNote>().toList();
      expect(notes, hasLength(1));
      expect(notes.single.text, 'config.yml');
    });
  });

  group('TimingLayout', () {
    const layout = TimingLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram returns empty scene', () {
      final scene = layout.layout(const TimingDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('emits axis text labels for each used time', () {
      final scene = layout.layout(
        const TimingDiagram(
          lanes: [
            TimingLane(alias: 'WB', label: 'WB', kind: TimingLaneKind.robust),
          ],
          events: [
            StateChange(time: 0, lane: 'WB', state: 'Idle'),
            StateChange(time: 100, lane: 'WB', state: 'Loading'),
          ],
        ),
        measurer,
      );
      final axisTexts = scene.shapes
          .whereType<SceneText>()
          .where((t) => t.text.startsWith('@'))
          .toList();
      expect(axisTexts.map((t) => t.text), containsAll(<String>['@0', '@100']));
    });

    test('robust lane emits horizontal state bars and a transition edge', () {
      final scene = layout.layout(
        const TimingDiagram(
          lanes: [
            TimingLane(alias: 'WB', label: 'WB', kind: TimingLaneKind.robust),
          ],
          events: [
            StateChange(time: 0, lane: 'WB', state: 'Idle'),
            StateChange(time: 100, lane: 'WB', state: 'Loading'),
          ],
        ),
        measurer,
      );
      final lines = scene.shapes.whereType<SceneLine>().toList();
      final horizontals =
          lines.where((l) => l.from.dy == l.to.dy && l.from.dx != l.to.dx);
      final verticals =
          lines.where((l) => l.from.dx == l.to.dx && l.from.dy != l.to.dy);
      expect(horizontals.length, greaterThanOrEqualTo(2));
      expect(verticals.length, greaterThanOrEqualTo(1));
    });

    test('arrow event emits a vertical SceneLine between lanes', () {
      final scene = layout.layout(
        const TimingDiagram(
          lanes: [
            TimingLane(alias: 'A', label: 'A', kind: TimingLaneKind.concise),
            TimingLane(alias: 'B', label: 'B', kind: TimingLaneKind.robust),
          ],
          events: [
            TimingArrow(time: 50, from: 'A', to: 'B', label: 'open'),
          ],
        ),
        measurer,
      );
      final arrows = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.head != null && l.label == 'open')
          .toList();
      expect(arrows, hasLength(1));
      expect(arrows.single.from.dx, arrows.single.to.dx);
    });
  });

  group('MindmapLayout', () {
    const layout = MindmapLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram returns empty scene', () {
      final scene = layout.layout(const MindmapDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('root-only emits one rounded box and no connectors', () {
      final scene = layout.layout(
        const MindmapDiagram(
          root: MindmapNode(text: 'Root', depth: 1),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final lines = scene.shapes.whereType<SceneLine>().toList();
      expect(boxes, hasLength(1));
      expect(lines, isEmpty);
    });

    test('emits a rounded box per node and a connector per parent->child edge',
        () {
      final scene = layout.layout(
        const MindmapDiagram(
          root: MindmapNode(
            text: 'Root',
            depth: 1,
            children: [
              MindmapNode(text: 'A', depth: 2),
              MindmapNode(text: 'B', depth: 2),
              MindmapNode(
                text: 'C',
                depth: 2,
                children: [
                  MindmapNode(text: 'C1', depth: 3),
                ],
              ),
            ],
          ),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final lines = scene.shapes.whereType<SceneLine>().toList();
      expect(boxes, hasLength(5));
      expect(lines, hasLength(4));
    });

    test('explicit + and - prefixes place children on the requested side', () {
      final scene = layout.layout(
        const MindmapDiagram(
          root: MindmapNode(
            text: 'Root',
            depth: 1,
            children: [
              MindmapNode(
                  text: 'R', depth: 2, side: MindmapSide.right),
              MindmapNode(
                  text: 'L', depth: 2, side: MindmapSide.left),
            ],
          ),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final root = boxes.firstWhere((b) => b.label == 'Root');
      final r = boxes.firstWhere((b) => b.label == 'R');
      final l = boxes.firstWhere((b) => b.label == 'L');
      expect(r.rect.left, greaterThan(root.rect.right));
      expect(l.rect.right, lessThan(root.rect.left));
    });

    test('color modifier overrides default node fill', () {
      const red = Color(0xFFFF0000);
      final scene = layout.layout(
        const MindmapDiagram(
          root: MindmapNode(
            text: 'Root',
            depth: 1,
            children: [
              MindmapNode(text: 'X', depth: 2, color: red),
            ],
          ),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final x = boxes.firstWhere((b) => b.label == 'X');
      expect(x.fill, red);
    });
  });

  group('WbsLayout', () {
    const layout = WbsLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram returns empty scene', () {
      final scene = layout.layout(const WbsDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('root-only emits one rounded box and no connectors', () {
      final scene = layout.layout(
        const WbsDiagram(
          root: MindmapNode(text: 'Root', depth: 1),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final lines = scene.shapes.whereType<SceneLine>().toList();
      expect(boxes, hasLength(1));
      expect(lines, isEmpty);
    });

    test('emits a rounded box per node and connectors per parent->child edge',
        () {
      final scene = layout.layout(
        const WbsDiagram(
          root: MindmapNode(
            text: 'Root',
            depth: 1,
            children: [
              MindmapNode(text: 'A', depth: 2),
              MindmapNode(text: 'B', depth: 2),
              MindmapNode(
                text: 'C',
                depth: 2,
                children: [
                  MindmapNode(text: 'C1', depth: 3),
                ],
              ),
            ],
          ),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      expect(boxes, hasLength(5));
    });

    test('children stack below the root with siblings spread horizontally', () {
      final scene = layout.layout(
        const WbsDiagram(
          root: MindmapNode(
            text: 'Root',
            depth: 1,
            children: [
              MindmapNode(text: 'A', depth: 2),
              MindmapNode(text: 'B', depth: 2),
            ],
          ),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final root = boxes.firstWhere((b) => b.label == 'Root');
      final a = boxes.firstWhere((b) => b.label == 'A');
      final b = boxes.firstWhere((b) => b.label == 'B');
      expect(a.rect.top, greaterThan(root.rect.bottom));
      expect(b.rect.top, greaterThan(root.rect.bottom));
      expect(a.rect.right, lessThanOrEqualTo(b.rect.left));
    });

    test('grandchildren stack below their parent', () {
      final scene = layout.layout(
        const WbsDiagram(
          root: MindmapNode(
            text: 'Root',
            depth: 1,
            children: [
              MindmapNode(
                text: 'P',
                depth: 2,
                children: [
                  MindmapNode(text: 'Q', depth: 3),
                ],
              ),
            ],
          ),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final p = boxes.firstWhere((b) => b.label == 'P');
      final q = boxes.firstWhere((b) => b.label == 'Q');
      expect(q.rect.top, greaterThan(p.rect.bottom));
    });

    test('color modifier overrides default node fill', () {
      const red = Color(0xFFFF0000);
      final scene = layout.layout(
        const WbsDiagram(
          root: MindmapNode(
            text: 'Root',
            depth: 1,
            children: [
              MindmapNode(text: 'X', depth: 2, color: red),
            ],
          ),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneRoundedBox>().toList();
      final x = boxes.firstWhere((b) => b.label == 'X');
      expect(x.fill, red);
    });
  });

  group('DataLayout', () {
    const layout = DataLayout();
    final measurer = _FixedTextMeasurer();

    test('flat object emits one box per row plus key/value text per entry', () {
      final scene = layout.layout(
        const DataDiagram(
          format: DataFormat.json,
          root: DataObject([
            MapEntry('name',
                DataScalar(value: 'Alice', kind: ScalarKind.string)),
            MapEntry('age',
                DataScalar(value: '30', kind: ScalarKind.number)),
          ]),
        ),
        measurer,
      );
      final boxes = scene.shapes.whereType<SceneBox>().toList();
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(boxes.length, greaterThanOrEqualTo(1));
      final keyTexts = texts.where((t) => t.text == 'name' || t.text == 'age');
      expect(keyTexts, hasLength(2));
      final valueTexts =
          texts.where((t) => t.text == '"Alice"' || t.text == '30');
      expect(valueTexts, hasLength(2));
    });

    test('nested object renders inner table inside value cell', () {
      final scene = layout.layout(
        const DataDiagram(
          format: DataFormat.json,
          root: DataObject([
            MapEntry(
              'address',
              DataObject([
                MapEntry('city',
                    DataScalar(value: 'Seoul', kind: ScalarKind.string)),
              ]),
            ),
          ]),
        ),
        measurer,
      );
      final texts =
          scene.shapes.whereType<SceneText>().map((t) => t.text).toList();
      expect(texts, contains('address'));
      expect(texts, contains('city'));
      expect(texts, contains('"Seoul"'));
    });

    test('array renders numbered rows', () {
      final scene = layout.layout(
        const DataDiagram(
          format: DataFormat.json,
          root: DataArray([
            DataScalar(value: 'a', kind: ScalarKind.string),
            DataScalar(value: 'b', kind: ScalarKind.string),
          ]),
        ),
        measurer,
      );
      final texts =
          scene.shapes.whereType<SceneText>().map((t) => t.text).toList();
      expect(texts, contains('0:'));
      expect(texts, contains('1:'));
      expect(texts, contains('"a"'));
      expect(texts, contains('"b"'));
    });

    test('scalar kinds get distinct colors', () {
      final scene = layout.layout(
        const DataDiagram(
          format: DataFormat.json,
          root: DataObject([
            MapEntry('s',
                DataScalar(value: 'x', kind: ScalarKind.string)),
            MapEntry('n',
                DataScalar(value: '1', kind: ScalarKind.number)),
            MapEntry('b',
                DataScalar(value: 'true', kind: ScalarKind.boolean)),
            MapEntry('z',
                DataScalar(value: 'null', kind: ScalarKind.null_)),
          ]),
        ),
        measurer,
      );
      final texts = scene.shapes.whereType<SceneText>().toList();
      final s = texts.firstWhere((t) => t.text == '"x"');
      final n = texts.firstWhere((t) => t.text == '1');
      final b = texts.firstWhere((t) => t.text == 'true');
      final z = texts.firstWhere((t) => t.text == 'null');
      expect(s.textStyle.color, isNot(n.textStyle.color));
      expect(n.textStyle.color, isNot(b.textStyle.color));
      expect(b.textStyle.color, isNot(z.textStyle.color));
    });
  });

  group('SaltLayout', () {
    const layout = SaltLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram produces an empty scene', () {
      final scene = layout.layout(const SaltDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('label row emits an outer box and a SceneText', () {
      final scene = layout.layout(
        const SaltDiagram(rows: [
          SaltRow(cells: [SaltLabel('Name')]),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneBox>().length, 1);
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(texts, hasLength(1));
      expect(texts.single.text, 'Name');
    });

    test('button cell emits a SceneRoundedBox with the label', () {
      final scene = layout.layout(
        const SaltDiagram(rows: [
          SaltRow(cells: [SaltButton('Ok')]),
        ]),
        measurer,
      );
      final rounded = scene.shapes.whereType<SceneRoundedBox>().toList();
      expect(rounded, hasLength(1));
      expect(rounded.single.label, 'Ok');
    });

    test('text field emits a SceneRoundedBox and italic SceneText', () {
      final scene = layout.layout(
        const SaltDiagram(rows: [
          SaltRow(cells: [SaltTextField('Alice')]),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneRoundedBox>(), hasLength(1));
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(texts, hasLength(1));
      expect(texts.single.text, 'Alice');
      expect(texts.single.textStyle.fontStyle, FontStyle.italic);
    });

    test('radio selected vs unselected differ by ring flag', () {
      final scene = layout.layout(
        const SaltDiagram(rows: [
          SaltRow(cells: [SaltRadio(selected: true, label: 'Yes')]),
          SaltRow(cells: [SaltRadio(selected: false, label: 'No')]),
        ]),
        measurer,
      );
      final circles = scene.shapes.whereType<SceneCircle>().toList();
      expect(circles, hasLength(2));
      expect(circles[0].ring, isFalse);
      expect(circles[1].ring, isTrue);
    });

    test('checkbox emits one inner SceneBox plus two lines when checked', () {
      final scene = layout.layout(
        const SaltDiagram(rows: [
          SaltRow(cells: [SaltCheckbox(checked: true, label: 'Done')]),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneBox>().length, 2);
      expect(scene.shapes.whereType<SceneLine>().length, 2);
    });

    test('divider row emits a SceneLine across the row', () {
      final scene = layout.layout(
        const SaltDiagram(rows: [
          SaltRow(cells: [SaltLabel('A')]),
          SaltRow(isDivider: true),
          SaltRow(cells: [SaltLabel('B')]),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneLine>(), hasLength(1));
    });

    test('grid columns share widths across rows', () {
      final scene = layout.layout(
        const SaltDiagram(rows: [
          SaltRow(cells: [SaltLabel('A'), SaltLabel('Long Label')]),
          SaltRow(cells: [SaltLabel('B'), SaltLabel('X')]),
        ]),
        measurer,
      );
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(texts, hasLength(4));
      final byText = {for (final t in texts) t.text: t};
      expect(byText['B']!.offset.dx, byText['A']!.offset.dx);
      expect(byText['X']!.offset.dx, byText['Long Label']!.offset.dx);
    });
  });

  group('GanttLayout', () {
    const layout = GanttLayout();
    final measurer = _FixedTextMeasurer();
    final start = DateTime.parse('2026-01-01');

    test('empty diagram produces an empty scene', () {
      final scene = layout.layout(
        GanttDiagram(projectStart: start),
        measurer,
      );
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('task emits a bar SceneBox and a name SceneText', () {
      final scene = layout.layout(
        GanttDiagram(projectStart: start, items: [
          GanttTask(
            name: 'Design',
            start: start,
            duration: const Duration(days: 5),
          ),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneBox>(), hasLength(1));
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(texts.any((t) => t.text == 'Design'), isTrue);
    });

    test('milestone emits a SceneDiamond', () {
      final scene = layout.layout(
        GanttDiagram(projectStart: start, items: [
          GanttMilestone(name: 'Release', date: start),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneDiamond>(), hasLength(1));
    });

    test('section emits a horizontal SceneLine and a title SceneText', () {
      final scene = layout.layout(
        GanttDiagram(projectStart: start, items: const [
          GanttSection('Phase 1'),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneLine>().length, greaterThanOrEqualTo(1));
      final texts = scene.shapes.whereType<SceneText>().toList();
      expect(texts.any((t) => t.text == 'Phase 1'), isTrue);
    });

    test('combined diagram emits expected shape counts', () {
      final scene = layout.layout(
        GanttDiagram(projectStart: start, items: [
          GanttTask(
            name: 'A',
            start: start,
            duration: const Duration(days: 3),
          ),
          GanttTask(
            name: 'B',
            start: start.add(const Duration(days: 3)),
            duration: const Duration(days: 4),
          ),
          const GanttSection('Done'),
          GanttMilestone(
            name: 'Ship',
            date: start.add(const Duration(days: 7)),
          ),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneBox>(), hasLength(2));
      expect(scene.shapes.whereType<SceneDiamond>(), hasLength(1));
    });
  });

  group('NetworkLayout', () {
    const layout = NetworkLayout();
    final measurer = _FixedTextMeasurer();

    test('empty diagram produces an empty scene', () {
      final scene = layout.layout(const NetworkDiagram(), measurer);
      expect(scene.shapes, isEmpty);
      expect(scene.size, Size.zero);
    });

    test('single network with nodes emits 1 bus + N nodes + N connectors', () {
      final scene = layout.layout(
        const NetworkDiagram(networks: [
          NetworkSegment(name: 'dmz', nodes: [
            NetworkNode(name: 'web01', address: '210.0.0.1'),
            NetworkNode(name: 'web02', address: '210.0.0.2'),
          ]),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneBox>(), hasLength(3));
      expect(
        scene.shapes.whereType<SceneLine>().where((l) => l.head == null),
        hasLength(2),
      );
    });

    test('node address renders as a second SceneText below name', () {
      final scene = layout.layout(
        const NetworkDiagram(networks: [
          NetworkSegment(name: 'dmz', nodes: [
            NetworkNode(name: 'web01', address: '210.0.0.1'),
          ]),
        ]),
        measurer,
      );
      final texts =
          scene.shapes.whereType<SceneText>().map((t) => t.text).toSet();
      expect(texts, contains('web01'));
      expect(texts, contains('210.0.0.1'));
      expect(texts, contains('dmz'));
    });

    test('multiple networks produce stacked rows of buses', () {
      final scene = layout.layout(
        const NetworkDiagram(networks: [
          NetworkSegment(name: 'dmz', nodes: [
            NetworkNode(name: 'web01'),
          ]),
          NetworkSegment(name: 'internal', nodes: [
            NetworkNode(name: 'db01'),
          ]),
        ]),
        measurer,
      );
      expect(scene.shapes.whereType<SceneBox>(), hasLength(4));
      expect(
        scene.shapes.whereType<SceneLine>().where((l) => l.head == null),
        hasLength(2),
      );
    });

    test('segment-level address renders below the network name', () {
      final scene = layout.layout(
        const NetworkDiagram(networks: [
          NetworkSegment(
            name: 'dmz',
            address: '210.0.0.0/24',
            nodes: [NetworkNode(name: 'web01')],
          ),
        ]),
        measurer,
      );
      final texts =
          scene.shapes.whereType<SceneText>().map((t) => t.text).toSet();
      expect(texts, contains('210.0.0.0/24'));
    });
  });
}
