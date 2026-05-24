import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

class _NoopMeasurer implements TextMeasurer {
  @override
  Size measure(String text, TextStyle style) =>
      Size(text.length * 7.0, 14);
}

int _countObjectsArrays(DataNode node) {
  if (node is DataObject) {
    var n = 1;
    for (final e in node.entries) {
      n += _countObjectsArrays(e.value);
    }
    return n;
  }
  if (node is DataArray) {
    var n = 1;
    for (final i in node.items) {
      n += _countObjectsArrays(i);
    }
    return n;
  }
  return 0;
}

int _countNestedEdges(DataNode node) {
  if (node is DataObject) {
    var n = 0;
    for (final e in node.entries) {
      if (e.value is DataObject || e.value is DataArray) n++;
      n += _countNestedEdges(e.value);
    }
    return n;
  }
  if (node is DataArray) {
    var n = 0;
    for (final i in node.items) {
      if (i is DataObject || i is DataArray) n++;
      n += _countNestedEdges(i);
    }
    return n;
  }
  return 0;
}

void main() {
  test('json_deep_schema produces #tables == #objects+arrays and matching '
      'dashed connector count', () {
    const source = '@startjson\n'
        '#highlight "services" / "1" / "routes" / "0"\n'
        '{\n'
        '  "version": "2026.05",\n'
        '  "services": [\n'
        '    {\n'
        '      "name": "viewer-api",\n'
        '      "ports": [443, 8443],\n'
        '      "features": {\n'
        '        "plantuml": true,\n'
        '        "mermaid": true,\n'
        '        "maxUploadMb": 128\n'
        '      }\n'
        '    },\n'
        '    {\n'
        '      "name": "router",\n'
        '      "routes": [\n'
        '        {\n'
        '          "match": {\n'
        '            "extension": [".puml", ".plantuml"],\n'
        '            "mime": "text/x-plantuml"\n'
        '          },\n'
        '          "target": "plantuml-viewer",\n'
        '          "priority": 20\n'
        '        }\n'
        '      ]\n'
        '    }\n'
        '  ],\n'
        '  "limits": null,\n'
        '  "metadata": {\n'
        '    "unicode": "han geul PlantUML",\n'
        '    "escaped": "line1\\nline2\\tTabbed"\n'
        '  }\n'
        '}\n'
        '@endjson\n';
    final tokens = Lexer().tokenize(source);
    final diagram = Parser().parse(tokens) as DataDiagram;
    final expectedTables = _countObjectsArrays(diagram.root);
    final expectedEdges = _countNestedEdges(diagram.root);
    final scene = const DataLayout().layout(diagram, _NoopMeasurer());
    final outerBoxes = scene.shapes
        .whereType<SceneBox>()
        .where((b) => b.strokeWidth > 0)
        .toList();
    final dashedLines = scene.shapes
        .whereType<SceneLine>()
        .where((l) => l.dashed)
        .toList();
    expect(outerBoxes, hasLength(expectedTables));
    expect(dashedLines, hasLength(expectedEdges));
    expect(scene.size.width, greaterThan(0));
    expect(scene.size.height, greaterThan(0));
  });
}
