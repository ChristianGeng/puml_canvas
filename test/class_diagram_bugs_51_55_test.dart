import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('class diagram parser bugs 51-55', () {
    test('51: package "Name" #color + dotted package name', () {
      _parse('''
@startuml
package "Classic Collections" #DDDDDD {
  Object <|-- ArrayList
}
package com.plantuml {
  Object <|-- Demo1
  Demo1 *- Demo2
}
@enduml
''');
    });

    test('52: scale W width + package X <<Stereo>>', () {
      _parse('''
@startuml
scale 750 width
package foo1 <<Node>> {
  class Class1
}
package foo2 <<Rectangle>> {
  class Class2
}
package foo3 <<Folder>> { class Class3 }
package foo4 <<Frame>> { class Class4 }
package foo5 <<Cloud>> { class Class5 }
package foo6 <<Database>> { class Class6 }
@enduml
''');
    });

    test('53: dotted package names + +-- containment', () {
      _parse('''
@startuml
skinparam packageStyle rectangle
package foo1.foo2 { }
package foo1.foo2.foo3 {
  class Object
}
foo1.foo2 +-- foo1.foo2.foo3
@enduml
''');
    });

    test('54: set separator ::', () {
      _parse('''
@startuml
set separator ::
class X1::X2::foo {
  some info
}
@enduml
''');
    });

    test('55: set separator none', () {
      _parse('''
@startuml
set separator none
class X1.X2.foo {
  some info
}
@enduml
''');
    });
  });
}
