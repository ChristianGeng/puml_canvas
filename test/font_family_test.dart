import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';
import 'package:puml_canvas/src/text/font_family.dart';

/// Family name under which the tests register Roboto.
const _family = 'TestRoboto';

/// Loads Roboto from the Flutter SDK under [_family].
///
/// `flutter test` draws text with its own test font, whose glyphs are all
/// one em wide, and falls back to it for any unknown family. Roboto has
/// real glyph widths, so text measured with it is narrower. The SDK ships
/// Roboto with its Material fonts, so no font has to be checked in.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final file = File(
      '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  final bytes = file.readAsBytesSync();
  final loader = FontLoader(_family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

const _style = TextStyle(color: Color(0xFF000000), fontSize: 12);

const _source = '@startuml\nAlice -> Bob : hello world\n@enduml\n';

/// Paints [paint] onto a [size] canvas and returns the raw RGBA pixels.
Future<Uint8List> _pixels(Size size, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder
      .endRecording()
      .toImage(size.width.ceil(), size.height.ceil());
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

Scene _textScene(TextStyle style) => Scene(
      size: const Size(200, 40),
      shapes: [
        SceneText(
          offset: const Offset(10, 10),
          text: 'hello world',
          textStyle: style,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRoboto);

  group('withDefaultFontFamily', () {
    test('fills in the family only when the style names none', () {
      const plain = TextStyle(fontSize: 12);
      expect(withDefaultFontFamily(plain, 'Roboto').fontFamily, 'Roboto');
      expect(withDefaultFontFamily(plain, null), same(plain));
      const named = TextStyle(fontFamily: 'monospace');
      expect(withDefaultFontFamily(named, 'Roboto'), same(named));
      // Without fontFamily, Flutter uses the first fallback entry as the
      // preferred font, so a non-empty list names a family.
      const fallback = TextStyle(fontFamilyFallback: ['Noto Sans']);
      expect(withDefaultFontFamily(fallback, 'Roboto'), same(fallback));
      // An empty list is the same as none.
      const empty = TextStyle(fontFamilyFallback: <String>[]);
      expect(withDefaultFontFamily(empty, 'Roboto').fontFamily, 'Roboto');
    });
  });

  group('FlutterTextMeasurer fontFamily', () {
    test('null fontFamily measures the style unchanged', () {
      final unchanged = TextPainter(
        text: parseInlineMarkup('hello', _style),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(const FlutterTextMeasurer().measure('hello', _style),
          unchanged.size);
    });

    test('fontFamily changes the measured width', () {
      final plain = const FlutterTextMeasurer().measure('hello', _style);
      final roboto =
          const FlutterTextMeasurer(fontFamily: _family).measure('hello', _style);
      expect(roboto.width, isNot(plain.width));
      expect(roboto.width, lessThan(plain.width));
    });

    test('a family named in the style wins over fontFamily', () {
      final styled = _style.copyWith(fontFamily: _family);
      expect(
        const FlutterTextMeasurer(fontFamily: 'NoSuchFont')
            .measure('hello', styled),
        const FlutterTextMeasurer().measure('hello', styled),
      );
    });
  });

  group('Renderer fontFamily', () {
    test('fontFamily changes the painted text', () async {
      final scene = _textScene(_style);
      final plain =
          await _pixels(scene.size, (c) => const Renderer().render(c, scene));
      final roboto = await _pixels(scene.size,
          (c) => const Renderer(fontFamily: _family).render(c, scene));
      expect(roboto, isNot(equals(plain)));
    });

    test('a family named in the style wins over fontFamily', () async {
      final scene = _textScene(_style.copyWith(fontFamily: _family));
      final plain =
          await _pixels(scene.size, (c) => const Renderer().render(c, scene));
      final other = await _pixels(scene.size,
          (c) => const Renderer(fontFamily: 'NoSuchFont').render(c, scene));
      expect(other, equals(plain));
    });
  });

  group('PumlView fontFamily', () {
    Widget view({String? fontFamily}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: PumlView(source: _source, fontFamily: fontFamily),
          ),
        );

    testWidgets('passes fontFamily to the measurer', (tester) async {
      await tester.pumpWidget(view());
      final plain = tester.getSize(find.byType(CustomPaint));
      await tester.pumpWidget(view(fontFamily: _family));
      final roboto = tester.getSize(find.byType(CustomPaint));
      expect(roboto.width, lessThan(plain.width));
    });

    testWidgets('passes fontFamily to the renderer', (tester) async {
      await tester.pumpWidget(view(fontFamily: _family));
      final box =
          tester.renderObject<RenderCustomPaint>(find.byType(CustomPaint));
      final painter = box.painter!;
      final size = box.size;

      final diagram = Parser().parse(Lexer().tokenize(_source));
      final scene = AutoLayout()
          .layout(diagram, const FlutterTextMeasurer(fontFamily: _family));
      expect(scene.size, size);

      await tester.runAsync(() async {
        final painted = await _pixels(size, (c) => painter.paint(c, size));
        final expected = await _pixels(size,
            (c) => const Renderer(fontFamily: _family).render(c, scene));
        final unstyled =
            await _pixels(size, (c) => const Renderer().render(c, scene));
        expect(painted, equals(expected));
        expect(painted, isNot(equals(unstyled)));
      });
    });
  });
}
