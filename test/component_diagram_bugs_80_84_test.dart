import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('component diagram parser bugs 80-84', () {
    test('80: bare multi-line bracketed description block', () {
      _parse('''
@startuml
component comp1
[
This component has a long comment on several lines
]
@enduml
''');
    });

    test('81: sprite hex grid + rectangle with stereotype reference', () {
      _parse(r'''
@startuml
sprite $businessProcess [16x16/16] {
FFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFF
}
rectangle " End to End\nbusiness process" <<$businessProcess>> {
rectangle "inner process 1" <<$businessProcess>> as src
rectangle "inner process 2" <<$businessProcess>> as tgt
src -> tgt
}
@enduml
''');
    });

    test('82: skinparam blocks + () "Name" as Alias + capitalized Component + ..> () mid-arrow interface',
        () {
      _parse('''
@startuml
skinparam interface {
backgroundColor RosyBrown
borderColor orange
}
skinparam component {
FontSize 13
BackgroundColor<<Apache>> Pink
BorderColor<<Apache>> #FF6655
FontName Courier
BorderColor black
BackgroundColor gold
ArrowFontName Impact
ArrowColor #FF6655
ArrowFontColor #777777
}
() "Data Access" as DA
Component "Web Server" as WS << Apache >>
DA - [First Component]
[First Component] ..> () HTTP : use
HTTP - WS
@enduml
''');
    });

    test('83: stereotype-keyed skinparam + bracket components with stereotype trailers',
        () {
      _parse('''
@startuml
skinparam component {
backgroundColor<<static lib>> DarkKhaki
backgroundColor<<shared lib>> Green
}
skinparam node {
borderColor Green
backgroundColor Yellow
backgroundColor<<shared_node>> Magenta
}
skinparam databaseBackgroundColor Aqua
[AA] <<static lib>>
[BB] <<shared lib>>
[CC] <<static lib>>
node node1
node node2 <<shared_node>>
database Production
@enduml
''');
    });

    test('84: componentStyle uml2 + nested component containers + edge-case bracket names',
        () {
      _parse('''
@startuml
skinparam BackgroundColor transparent
skinparam componentStyle uml2
component A {
component "A.1" {
}
component A.44 {
[A4.1]
}
component "A.2"
[A.3]
component A.5
[ A.5]
component A.6
[ ]
}
[a]->[b]
@enduml
''');
    });
  });
}
