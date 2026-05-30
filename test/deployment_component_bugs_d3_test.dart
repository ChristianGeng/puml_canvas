import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('deployment / component diagram bugs D3.1-D3.3', () {
    test('D3.1: inline styles on component/deployment relations', () {
      _parse('''
@startuml
node foo
foo --> bar : normal
foo --> bar1 #line:red;line.bold;text:red : red bold
foo --> bar2 #green;line.dashed;text:green : green dashed
foo --> bar3 #blue;line.dotted;text:blue : blue dotted
@enduml
''');
    });

    test('D3.2: inline styles on deployment element declarations', () {
      _parse('''
@startuml
agent a
cloud c #pink;line:red;line.bold;text:red
file f #palegreen;line:green;line.dashed;text:green
node n #aliceblue;line:blue;line.dotted;text:blue
@enduml
''');
    });

    test(
        'D3.3: inline styles + multi-line bracket label + container nesting',
        () {
      _parse('''
@startuml
agent a
cloud c #pink;line:red;line.bold;text:red [
c cloud description
]
file f #palegreen;line:green;line.dashed;text:green {
[c1]
[c2]
}
frame frame {
node n #aliceblue;line:blue;line.dotted;text:blue
}
@enduml
''');
    });
  });
}
