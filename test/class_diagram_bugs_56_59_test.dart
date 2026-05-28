import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('class diagram parser bugs 56-59', () {
    test('56: lollipop interface `()-` notation', () {
      _parse('''
@startuml
class foo
bar ()- foo
@enduml
''');
    });

    test('57: direction hint arrows (`-left->`, `-right->`, etc.)', () {
      _parse('''
@startuml
left to right direction
foo -left-> dummyLeft
foo -right-> dummyRight
foo -up-> dummyUp
foo -down-> dummyDown
@enduml
''');
    });

    test('58: multiplicity + association class with `..` connector', () {
      _parse('''
@startuml
class Student {
  Name
}
Student "0..*" - "1..*" Course
(Student, Course) .. Enrollment
class Enrollment {
  drop()
  cancel()
}
@enduml
''');
    });

    test('59: multiplicity + association class with `--` / `.` connectors',
        () {
      _parse('''
@startuml
class Student {
  Name
}
Student "0..*" -- "1..*" Course
(Student, Course) . Enrollment
class Enrollment {
  drop()
  cancel()
}
@enduml
''');
    });
  });
}
