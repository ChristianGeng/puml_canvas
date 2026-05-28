// Regression: PlantUML "Test of CreoleMode" sample exercises the full inline
// markup repertoire (bold/italics/underline/strike/wave/mono, plus tag-based
// `<back:>`, `<size:>`, `<u:color>`, `<color>`, `<s:color>...</strike>`,
// `<w:#color>`, `<img:...>`). All of the inline markers and HTML-like tags
// inside note bodies must round-trip through the lexer + parser without
// throwing.
//
// NOTE: The stray `Some ~~long delay~~` line between two `...` delay markers
// from the original PlantUML sample is NOT standard syntax (a label must sit
// on the same line as the dots, e.g. `... 5 minutes later ...`). That edge
// case is deferred — it is intentionally omitted from this test.
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void main() {
  test('extensive inline markup sample parses without error', () {
    const source = '''@startuml
participant Alice
participant "The **Famous** Bob" as Bob
Alice -> Bob : hello --there--
...
Bob -> Alice : ok
note left
This is **bold**
This is //italics//
This is ""monospaced""
This is --stroked--
This is __underlined__
This is ~~waved~~
end note
Alice -> Bob : A //well formatted// message
note right of Alice
This is <back:cadetblue><size:18>displayed</size></back>
__left of__ Alice.
end note
note left of Bob
<u:red>This</u> is <color #118888>displayed</color>
**<color purple>left of</color> <s:red>Alice</strike> Bob**.
end note
note over Alice, Bob
<w:#FF33FF>This is hosted</w> by <img:https://plantuml.com/sourceforge.jpg>
end note
@enduml
''';
    final tokens = Lexer().tokenize(source);
    final diagram = Parser().parse(tokens) as SequenceDiagram;
    expect(diagram.participants, hasLength(2));
    expect(diagram.participants.map((p) => p.alias).toList(), ['Alice', 'Bob']);

    final messages = diagram.events.whereType<Message>().toList();
    expect(messages, hasLength(3));
    expect(messages[0].label, 'hello --there--');
    expect(messages[1].label, 'ok');
    expect(messages[2].label, 'A //well formatted// message');

    final notes = diagram.events.whereType<Note>().toList();
    expect(notes, hasLength(4));

    final separators = diagram.events.whereType<Separator>().toList();
    expect(separators, hasLength(1));
    expect(separators.single.kind, SeparatorKind.skip);
  });
}
