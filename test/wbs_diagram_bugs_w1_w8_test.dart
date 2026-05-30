import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/ast/diagram.dart';
import 'package:puml_canvas/src/lexer/lexer.dart';
import 'package:puml_canvas/src/parser/parser.dart';

/// Regression tests for the 8 PlantUML WBS source samples (W1-W8) that
/// previously failed to parse. Each test asserts the source parses into a
/// [WbsDiagram] without error. Visual semantics (boxless styling, inline
/// colors, stereotype classes, cross-edges, multi-line bodies) are
/// consumed-and-ignored; full rendering is deferred.
void main() {
  WbsDiagram parseWbs(String src) {
    final tokens = Lexer().tokenize(src);
    final diagram = Parser().parse(tokens);
    expect(diagram, isA<WbsDiagram>());
    return diagram as WbsDiagram;
  }

  group('wbs diagram bugs W1-W8', () {
    test('W1 — mixed +/- with -_/+_ boxless variants', () {
      const source = '@startwbs\n'
          '+ Project\n'
          '+ Part One\n'
          '+ Task 1.1\n'
          '- LeftTask 1.2\n'
          '+ Task 1.3\n'
          '+ Part Two\n'
          '+ Task 2.1\n'
          '+ Task 2.2\n'
          '-_ Task 2.2.1 To the left boxless\n'
          '-_ Task 2.2.2 To the Left boxless\n'
          '+_ Task 2.2.3 To the right boxless\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });

    test('W2 — all boxless +_/-_ markers', () {
      const source = '@startwbs\n'
          '+_ Project\n'
          '+_ Part One\n'
          '+_ Task 1.1\n'
          '-_ LeftTask 1.2\n'
          '+_ Task 1.3\n'
          '+_ Part Two\n'
          '+_ Task 2.1\n'
          '+_ Task 2.2\n'
          '-_ Task 2.2.1 To the left boxless\n'
          '-_ Task 2.2.2 To the Left boxless\n'
          '+_ Task 2.2.3 To the right boxless\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });

    test('W3 — +[#color] inline color after marker', () {
      const source = '@startwbs\n'
          '+[#SkyBlue] this is the partner workpackage\n'
          '++[#pink] this is my workpackage\n'
          '++ this is another workpackage\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });

    test('W4 — * markers with <style>, <<class>>, and :..; multi-line', () {
      const source = '@startwbs\n'
          '<style>\n'
          'wbsDiagram {\n'
          '  .pink { BackgroundColor pink }\n'
          '  .your_style_name { BackgroundColor SkyBlue }\n'
          '}\n'
          '</style>\n'
          '* this is the partner workpackage <<your_style_name>>\n'
          '** this is my workpackage <<pink>>\n'
          '**:This is on multiple lines; <<pink>>\n'
          '** this is another workpackage\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });

    test('W5 — + markers with <style>, <<class>>, and :..; multi-line', () {
      const source = '@startwbs\n'
          '<style>\n'
          'wbsDiagram {\n'
          '  .pink { BackgroundColor pink }\n'
          '  .your_style_name { BackgroundColor SkyBlue }\n'
          '}\n'
          '</style>\n'
          '+ this is the partner workpackage <<your_style_name>>\n'
          '++ this is my workpackage <<pink>>\n'
          '++:This is on multiple lines; <<pink>>\n'
          '++ this is another workpackage\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });

    test('W6 — <style> :depth(N) selectors with ***<, ***_ markers', () {
      const source = '@startwbs\n'
          '<style>\n'
          'wbsDiagram {\n'
          '  Linecolor black\n'
          '  arrow {\n'
          '    LineColor green\n'
          '  }\n'
          '  :depth(0) {\n'
          '    BackgroundColor White\n'
          '    RoundCorner 10\n'
          '    LineColor red\n'
          '  }\n'
          '  arrow {\n'
          '    :depth(2) {\n'
          '      LineColor blue\n'
          '      LineStyle 4\n'
          '      LineThickness .5\n'
          '    }\n'
          '  }\n'
          '  node {\n'
          '    :depth(2) {\n'
          '      LineStyle 2\n'
          '      LineThickness 2.5\n'
          '    }\n'
          '  }\n'
          '  boxless {\n'
          '    FontColor darkgreen\n'
          '  }\n'
          '}\n'
          '</style>\n'
          '* World\n'
          '** America\n'
          '*** Canada\n'
          '*** Mexico\n'
          '**** Chihuahua\n'
          '*** USA\n'
          '**** Texas\n'
          '***< New York\n'
          '** Europe\n'
          '***_ England\n'
          '***_ Germany\n'
          '***_ Spain\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });

    test('W7 — <style> with node/rootNode/leafNode/arrow selectors', () {
      const source = '@startwbs\n'
          '<style>\n'
          'node {\n'
          '  Padding 12\n'
          '  Margin 3\n'
          '  HorizontalAlignment center\n'
          '  LineColor blue\n'
          '  LineThickness 3.0\n'
          '  BackgroundColor gold\n'
          '  RoundCorner 40\n'
          '  MaximumWidth 100\n'
          '}\n'
          'rootNode { LineStyle 8.0;3.0 LineColor red BackgroundColor white LineThickness 1.0 RoundCorner 0 Shadowing 0.0 }\n'
          'leafNode { LineColor gold RoundCorner 0 Padding 3 }\n'
          'arrow { LineStyle 4 LineThickness 0.5 LineColor green }\n'
          '</style>\n'
          '* Hi =)\n'
          '** sometimes i have node in wich i want to write a long text\n'
          '*** this results in really huge diagram\n'
          '**** of course, i can explicit split with a\\nnew line\n'
          '**** but it could be cool if PlantUML was able to split long lines, maybe with an option who specify the maximum width of a node\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });

    test('W8 — "name" as alias plus cross-edges with stereotype/color', () {
      const source = '@startwbs\n'
          '<style>\n'
          '.foo {\n'
          '  LineColor #00FF00;\n'
          '}\n'
          '</style>\n'
          '* Test\n'
          '** A topic\n'
          '*** "common" as c1\n'
          '*** "common2" as c2\n'
          '** "Another topic" as t2\n'
          't2 -> c1 <<foo>>\n'
          't2 ..> c2 #blue\n'
          '@endwbs\n';
      final d = parseWbs(source);
      expect(d.root, isNotNull);
    });
  });
}
