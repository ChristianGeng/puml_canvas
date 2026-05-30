import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/ast/diagram.dart';
import 'package:puml_canvas/src/lexer/lexer.dart';
import 'package:puml_canvas/src/parser/parser.dart';

/// Regression tests for mindmap layout-directive and Creole/HTML body samples.
///
/// * M2 — `right to left direction` directive.
/// * M3 — `top to bottom direction left side` directive (direction + side
///   qualifier on the same line).
/// * M4 — Standalone `left side` / `right side` directives interleaved
///   between `**:..;` multi-line Creole/HTML body nodes.
///
/// All three sources must parse without throwing. Layout/visual rendering of
/// the directives is currently deferred — the parser-level fix consumes and
/// ignores them so the diagram still builds.
void main() {
  MindmapDiagram parseMindmap(String src) {
    final tokens = Lexer().tokenize(src);
    final diagram = Parser().parse(tokens);
    expect(diagram, isA<MindmapDiagram>());
    return diagram as MindmapDiagram;
  }

  test('M2 — right to left direction directive parses', () {
    const source = '@startmindmap\n'
        'right to left direction\n'
        '* 1\n'
        '** 2\n'
        '*** 4\n'
        '*** 5\n'
        '** 3\n'
        '*** 6\n'
        '*** 7\n'
        '@endmindmap\n';
    final d = parseMindmap(source);
    expect(d.root, isNotNull);
    expect(d.root!.text, '1');
    expect(d.root!.children.length, 2);
  });

  test('M3 — top to bottom direction left side directive parses', () {
    const source = '@startmindmap\n'
        'top to bottom direction left side\n'
        '* 1\n'
        '** 2\n'
        '*** 4\n'
        '*** 5\n'
        '** 3\n'
        '*** 6\n'
        '*** 7\n'
        '@endmindmap\n';
    final d = parseMindmap(source);
    expect(d.root, isNotNull);
    expect(d.root!.text, '1');
    expect(d.root!.children.length, 2);
  });

  test('M4 — Creole/HTML bodies with left side / right side directives', () {
    const source = '@startmindmap\n'
        '* Creole on Mindmap\n'
        'left side\n'
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
        'right side\n'
        '**:==Creole line\n'
        'You can have horizontal line\n'
        '----\n'
        'Or double line\n'
        '====\n'
        'Or strong line\n'
        '____\n'
        'Or dotted line\n'
        '..My title..\n'
        'Or dotted title\n'
        '//and title... //\n'
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
        '@endmindmap\n';
    final d = parseMindmap(source);
    expect(d.root, isNotNull);
    expect(d.root!.text, 'Creole on Mindmap');
    // Four `**:..;` bodies become depth-2 children of the root.
    expect(d.root!.children.length, 4);
  });

  test('M5 — `<code>` blocks with internal `;` do not terminate body', () {
    const source = '@startmindmap\n'
        '* Class Templates\n'
        '**:Example 1\n'
        '<code>\n'
        'template <typename T>\n'
        'class cname{\n'
        'void f1();\n'
        '...\n'
        '}\n'
        '</code>\n'
        ';\n'
        '**:Example 2\n'
        '<code>\n'
        'other template <typename T>\n'
        'class cname{\n'
        '...\n'
        '</code>\n'
        ';\n'
        '@endmindmap\n';
    final d = parseMindmap(source);
    expect(d.root, isNotNull);
    expect(d.root!.text, 'Class Templates');
    expect(d.root!.children.length, 2);
    expect(d.root!.children[0].text, contains('Example 1'));
    expect(d.root!.children[0].text, contains('void f1();'));
    expect(d.root!.children[0].text, contains('</code>'));
    expect(d.root!.children[1].text, contains('Example 2'));
    expect(d.root!.children[1].text, contains('other template'));
  });
}
