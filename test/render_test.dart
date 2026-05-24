import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void main() {
  group('Renderer', () {
    test('paints without throwing for an empty scene', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const Renderer().render(canvas, Scene.empty);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('paints box and line shapes without throwing', () {
      final scene = Scene(
        size: const ui.Size(200, 100),
        shapes: const [
          SceneBox(
            rect: ui.Rect.fromLTWH(10, 10, 60, 30),
            label: 'A',
            textStyle: TextStyle(color: ui.Color(0xFF000000), fontSize: 12),
          ),
          SceneLine(
            from: ui.Offset(40, 50),
            to: ui.Offset(160, 50),
            label: 'hi',
            labelStyle: TextStyle(color: ui.Color(0xFF000000), fontSize: 12),
          ),
        ],
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const Renderer().render(canvas, scene);
      expect(recorder.endRecording(), isNotNull);
    });

    for (final head in ArrowHead.values) {
      test('paints $head arrow head without throwing', () {
        final scene = Scene(
          size: const ui.Size(200, 100),
          shapes: [
            SceneLine(
              from: const ui.Offset(20, 50),
              to: const ui.Offset(180, 50),
              head: head,
            ),
          ],
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        const Renderer().render(canvas, scene);
        expect(recorder.endRecording(), isNotNull);
      });
    }

    test('paints reversed arrow (headAtFrom=true) without throwing', () {
      final scene = Scene(
        size: const ui.Size(200, 100),
        shapes: const [
          SceneLine(
            from: ui.Offset(20, 50),
            to: ui.Offset(180, 50),
            head: ArrowHead.filled,
            headAtFrom: true,
          ),
        ],
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const Renderer().render(canvas, scene);
      expect(recorder.endRecording(), isNotNull);
    });

    test('omits head when head is null', () {
      final scene = Scene(
        size: const ui.Size(200, 100),
        shapes: const [
          SceneLine(
            from: ui.Offset(20, 50),
            to: ui.Offset(180, 50),
            head: null,
          ),
        ],
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const Renderer().render(canvas, scene);
      expect(recorder.endRecording(), isNotNull);
    });

    test('paints a scene with a background color without throwing', () {
      final scene = Scene(
        size: const ui.Size(120, 60),
        shapes: const [],
        background: const ui.Color(0xFFFFEEDD),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const Renderer().render(canvas, scene);
      expect(recorder.endRecording(), isNotNull);
    });
  });
}
