import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

String _flatten(InlineSpan span) {
  final buf = StringBuffer();
  span.visitChildren((s) {
    if (s is TextSpan && s.text != null) buf.write(s.text);
    return true;
  });
  return buf.toString();
}

TextSpan _firstChildSpan(TextSpan root) => root.children!.first as TextSpan;

void main() {
  const baseStyle = TextStyle(color: Color(0xFF000000), fontSize: 12);

  group('parseInlineMarkup', () {
    test('plain text returns a single child span', () {
      final span = parseInlineMarkup('hello world', baseStyle);
      expect(span.style, baseStyle);
      expect(span.children, hasLength(1));
      final only = span.children!.single as TextSpan;
      expect(only.text, 'hello world');
      expect(_flatten(span), 'hello world');
    });

    test('<b>bold</b> produces a child with bold weight', () {
      final span = parseInlineMarkup('a <b>bold</b> z', baseStyle);
      expect(_flatten(span), 'a bold z');
      final boldSpan = span.children!
          .whereType<TextSpan>()
          .firstWhere((s) => s.style?.fontWeight == FontWeight.bold);
      expect(_flatten(boldSpan), 'bold');
    });

    test('<i>italic</i> produces an italic child', () {
      final span = parseInlineMarkup('<i>x</i>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.fontStyle, FontStyle.italic);
      expect(_flatten(span), 'x');
    });

    test('<u>underline</u> produces an underline child', () {
      final span = parseInlineMarkup('<u>x</u>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.decoration, TextDecoration.underline);
    });

    test('<s>strike</s> produces a line-through child', () {
      final span = parseInlineMarkup('<s>x</s>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.decoration, TextDecoration.lineThrough);
    });

    test('<color:red>x</color> produces a red child', () {
      final span = parseInlineMarkup('<color:red>x</color>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.color, const Color(0xFFFF0000));
      expect(_flatten(span), 'x');
    });

    test('<color:#FF8800>x</color> produces hex-color child', () {
      final span = parseInlineMarkup('<color:#FF8800>x</color>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.color, const Color(0xFFFF8800));
    });

    test('<size:18>x</size> produces a sized child', () {
      final span = parseInlineMarkup('<size:18>x</size>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.fontSize, 18);
    });

    test('Markdown **bold** produces bold', () {
      final span = parseInlineMarkup('a **b** c', baseStyle);
      expect(_flatten(span), 'a b c');
      final bold = span.children!
          .whereType<TextSpan>()
          .firstWhere((s) => s.style?.fontWeight == FontWeight.bold);
      expect(_flatten(bold), 'b');
    });

    test('Markdown //italic// produces italic', () {
      final span = parseInlineMarkup('//x//', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.fontStyle, FontStyle.italic);
    });

    test('//Long long label// parses as a single italic span (spaces inside)',
        () {
      // Mirrors the label on the first arrow of the bug-report source:
      // `a -> b : //Long long label//`. The italic toggle must accept inner
      // whitespace and emit one italic child carrying the full label text.
      final span = parseInlineMarkup('//Long long label//', baseStyle);
      expect(_flatten(span), 'Long long label');
      final italics = span.children!
          .whereType<TextSpan>()
          .where((s) => s.style?.fontStyle == FontStyle.italic)
          .toList();
      expect(italics, hasLength(1));
      expect(_flatten(italics.single), 'Long long label');
    });

    test('Markdown __underline__ produces underline', () {
      final span = parseInlineMarkup('__x__', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.decoration, TextDecoration.underline);
    });

    test('Markdown ~~strike~~ produces strikethrough', () {
      final span = parseInlineMarkup('~~x~~', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.decoration, TextDecoration.lineThrough);
    });

    test('nested <b><i>...</i></b> produces nested bold+italic child', () {
      final span = parseInlineMarkup('<b>bold <i>italic</i></b>', baseStyle);
      expect(_flatten(span), 'bold italic');
      final outer = _firstChildSpan(span);
      expect(outer.style?.fontWeight, FontWeight.bold);
      final inner = outer.children!
          .whereType<TextSpan>()
          .firstWhere((s) => s.style?.fontStyle == FontStyle.italic);
      expect(_flatten(inner), 'italic');
    });

    test('unknown tags pass through as literal text', () {
      final span = parseInlineMarkup('<unknown>x</unknown>', baseStyle);
      expect(_flatten(span), '<unknown>x</unknown>');
    });

    test('mismatched closing tags do not crash; open tags close at end', () {
      final span = parseInlineMarkup('<b>bold</i>', baseStyle);
      expect(_flatten(span), 'bold</i>');
      final bold = span.children!
          .whereType<TextSpan>()
          .firstWhere((s) => s.style?.fontWeight == FontWeight.bold);
      expect(_flatten(bold), 'bold</i>');
    });

    test('\\n produces a newline character in output', () {
      final span = parseInlineMarkup(r'a\nb', baseStyle);
      expect(_flatten(span), 'a\nb');
    });

    test('<br> produces a newline character in output', () {
      final span = parseInlineMarkup('a<br>b', baseStyle);
      expect(_flatten(span), 'a\nb');
    });

    test('<color:#bogus>x</color> is treated as literal', () {
      final span =
          parseInlineMarkup('<color:#zzz>x</color>', baseStyle);
      expect(_flatten(span), '<color:#zzz>x</color>');
    });

    test('""verbatim"" wraps content in a monospace span', () {
      // PlantUML's `""..."" ` markup renders the enclosed text as monospace
      // and (critically for our case) keeps the inner characters as literal
      // glyphs — `?->` must NOT get reinterpreted as an arrow.
      final span = parseInlineMarkup('""?->""', baseStyle);
      expect(_flatten(span), '?->');
      final mono = span.children!
          .whereType<TextSpan>()
          .firstWhere((s) => s.style?.fontFamily == 'monospace');
      expect(_flatten(mono), '?->');
    });

    test('<back:cadetblue>x</back> produces a background-color child', () {
      final span =
          parseInlineMarkup('<back:cadetblue>x</back>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.backgroundColor, const Color(0xFF5F9EA0));
      expect(_flatten(span), 'x');
    });

    test('<color #118888>x</color> with space delimiter parses', () {
      // PlantUML accepts space-separated attribute syntax (`<color #118888>`)
      // in addition to the colon form; both should yield a colored span.
      final span =
          parseInlineMarkup('<color #118888>x</color>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.color, const Color(0xFF118888));
      expect(_flatten(span), 'x');
    });

    test('<color purple>x</color> resolves named color via space syntax', () {
      final span = parseInlineMarkup('<color purple>x</color>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.color, const Color(0xFF800080));
    });

    test('<u:red>x</u> produces a colored underline', () {
      final span = parseInlineMarkup('<u:red>x</u>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.decoration, TextDecoration.underline);
      expect(inner.style?.decorationColor, const Color(0xFFFF0000));
    });

    test('<s:red>x</strike> closes asymmetrically as a colored strike', () {
      // The bug source uses `<s:red>Alice</strike>` — the close tag uses
      // `strike` instead of `s` and must still terminate the coloredStrike
      // span rather than passing through as literal text.
      final span = parseInlineMarkup('<s:red>x</strike>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.decoration, TextDecoration.lineThrough);
      expect(inner.style?.decorationColor, const Color(0xFFFF0000));
      expect(_flatten(span), 'x');
    });

    test('<w:#FF33FF>x</w> produces a wavy colored underline', () {
      final span = parseInlineMarkup('<w:#FF33FF>x</w>', baseStyle);
      final inner = _firstChildSpan(span);
      expect(inner.style?.decoration, TextDecoration.underline);
      expect(inner.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(inner.style?.decorationColor, const Color(0xFFFF33FF));
    });

    test('<img:URL> emits a deterministic [img] placeholder', () {
      final span = parseInlineMarkup(
        '<img:https://plantuml.com/sourceforge.jpg>',
        baseStyle,
      );
      expect(_flatten(span), '[img]');
    });

    test('<img URL> (space form) also emits the [img] placeholder', () {
      final span = parseInlineMarkup('<img sourceforge.jpg>', baseStyle);
      expect(_flatten(span), '[img]');
    });

    test('""verbatim"" alongside **bold** in the same label', () {
      // Mirrors the labels in the found/lost messages source: the verbatim
      // span and a separate bold span both survive parsing.
      final span = parseInlineMarkup('""?->""\\n**short** to actor1', baseStyle);
      expect(_flatten(span), '?->\nshort to actor1');
      final mono = span.children!
          .whereType<TextSpan>()
          .firstWhere((s) => s.style?.fontFamily == 'monospace');
      expect(_flatten(mono), '?->');
      final bold = span.children!
          .whereType<TextSpan>()
          .firstWhere((s) => s.style?.fontWeight == FontWeight.bold);
      expect(_flatten(bold), 'short');
    });
  });
}
