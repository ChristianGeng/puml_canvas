import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('component diagram parser bugs 77-79', () {
    test('77: anonymous cloud, nested containers, bare interface in relation',
        () {
      _parse('''
@startuml
package "Some Group" {
HTTP - [First Component]
[Another Component]
}
node "Other Groups" {
FTP - [Second Component]
[First Component] --> FTP
}
cloud {
[Example 1]
}
database "MySql" {
folder "This is my folder" {
[Folder 3]
}
frame "Foo" {
[Frame 4]
}
}
[Another Component] --> [Example 1]
[Example 1] --> [Folder 3]
[Folder 3] --> [Frame 4]
@enduml
''');
    });

    test('78: direction hint arrows with direction-keyword targets', () {
      _parse('''
@startuml
[Component] -left-> left
[Component] -right-> right
[Component] -up-> up
[Component] -down-> down
@enduml
''');
    });

    test('79: left to right direction + direction-hint arrows', () {
      _parse('''
@startuml
left to right direction
[Component] -left-> left
[Component] -right-> right
[Component] -up-> up
[Component] -down-> down
@enduml
''');
    });
  });
}
