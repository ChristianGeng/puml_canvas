import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/ast/diagram.dart';
import 'package:puml_canvas/src/lexer/lexer.dart';
import 'package:puml_canvas/src/parser/parser.dart';

/// Regression tests for additional PlantUML WBS source samples (W9-W10) that
/// previously failed to parse. Each test asserts the source parses into a
/// [WbsDiagram] without error. Visual semantics (parenthesized aliases,
/// Creole/HTML markup inside multi-line bodies, Unicode icons, image refs)
/// are consumed-and-ignored; full rendering is deferred.
void main() {
  WbsDiagram parseWbs(String src) {
    final tokens = Lexer().tokenize(src);
    final diagram = Parser().parse(tokens);
    expect(diagram, isA<WbsDiagram>());
    return diagram as WbsDiagram;
  }

  group('wbs diagram bugs W9-W10', () {
    test('W9 — **(alias) parenthesized aliases plus cross-edges', () {
      const source = '@startwbs\n'
          '* Test\n'
          '**(b) A topic\n'
          '***(c1) common\n'
          '**(t2) Another topic\n'
          't2 --> c1\n'
          'b -> t2 #blue\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });

    test('W10 — Creole/HTML markup inside **:..; multi-line bodies', () {
      const source = '@startwbs\n'
          '* Creole on WBS\n'
          '**:==Creole\n'
          'This is **bold**\n'
          'This is //italics//\n'
          'This is ""monospaced""\n'
          'This is --stricken-out--\n'
          'This is __underlined__\n'
          'This is ~~wave-underlined~~\n'
          '--test Unicode and icons--\n'
          'This is <U+221E> long\n'
          'This is a <&code> icon\n'
          'Use image : <img:https://plantuml.com/logo3.png>\n'
          ';\n'
          '**:\n'
          '<b>HTML Creole\n'
          'This is <b>bold</b>\n'
          'This is <i>italics</i>\n'
          'This is <font:monospaced>monospaced</font>\n'
          'This is <s>stroked</s>\n'
          'This is <u>underlined</u>\n'
          'This is <w>waved</w>\n'
          'This is <s:green>stroked</s>\n'
          'This is <u:red>underlined</u>\n'
          'This is <w:#0000FF>waved</w>\n'
          '-- other examples --\n'
          'This is <color:blue>Blue</color>\n'
          'This is <back:orange>Orange background</back>\n'
          'This is <size:20>big</size>\n'
          ';\n'
          '**:==Creole line\n'
          'You can have horizontal line\n'
          '----\n'
          'Or double line\n'
          '====\n'
          'Or strong line\n'
          '____\n'
          'Or dotted line\n'
          '..My title..\n'
          'Or dotted title //and title... //\n'
          '==Title==\n'
          'Or double-line title\n'
          '--Another title--\n'
          'Or single-line title\n'
          'Enjoy!;\n'
          '**:==Creole list item\n'
          '**test list 1**\n'
          '* Bullet list\n'
          '* Second item\n'
          '** Sub item\n'
          '*** Sub sub item\n'
          '* Third item\n'
          '----\n'
          '**test list 2**\n'
          '# Numbered list\n'
          '# Second item\n'
          '## Sub item\n'
          '## Another sub item\n'
          '# Third item\n'
          ';\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });
  });
}
