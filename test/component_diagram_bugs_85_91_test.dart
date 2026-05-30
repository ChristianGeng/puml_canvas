import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('component diagram parser bugs 85-91', () {
    test('85: componentStyle rectangle + nested component containers + edge-case bracket names',
        () {
      _parse('''
@startuml
skinparam BackgroundColor transparent
skinparam componentStyle rectangle
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

    test('86: component with multiple \$tags + remove/restore by tag', () {
      _parse(r'''
@startuml
component C1 $tag13 $tag1
component C2
component C3 $tag13
C1 -- C2
remove $tag13
restore $tag1
@enduml
''');
    });

    test('87: component with multiple \$tags + remove * wildcard + restore by tag',
        () {
      _parse(r'''
@startuml
component C1 $tag13 $tag1
component C2
component C3 $tag13
C1 -- C2
remove *
restore $tag1
@enduml
''');
    });

    test('88: port declarations inside component container', () {
      _parse('''
@startuml
[c]
component C {
port p1
port p2
port p3
component c1
}
c --> p1
c --> p2
c --> p3
p1 --> c1
p2 --> c1
@enduml
''');
    });

    test('89: portin (input port) declarations inside component container',
        () {
      _parse('''
@startuml
[c]
component C {
portin p1
portin p2
portin p3
component c1
}
c --> p1
c --> p2
c --> p3
p1 --> c1
p2 --> c1
@enduml
''');
    });

    test('90: portout (output port) declarations inside component container',
        () {
      _parse('''
@startuml
component C {
portout p1
portout p2
portout p3
component c1
}
[o]
p1 --> o
p2 --> o
p3 --> o
c1 --> p1
@enduml
''');
    });

    test('91: mixed portin / portout declarations inside component container',
        () {
      _parse('''
@startuml
[i]
component C {
portin p1
portin p2
portin p3
portout po1
portout po2
portout po3
component c1
}
[o]
i --> p1
i --> p2
i --> p3
po1 --> o
po2 --> o
po3 --> o
c1 --> po1
@enduml
''');
    });
  });
}
