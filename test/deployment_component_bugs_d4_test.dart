import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('deployment / component diagram bugs D4.1-D4.3', () {
    test(
        'D4.1: every container keyword with long alias + quoted display + nested file',
        () {
      _parse('''
@startuml
artifact artifactVeryLOOOOOOOOOOOOOOOOOOOg as "artifact" {
file f1
}
card cardVeryLOOOOOOOOOOOOOOOOOOOg as "card" {
file f2
}
cloud cloudVeryLOOOOOOOOOOOOOOOOOOOg as "cloud" {
file f3
}
component componentVeryLOOOOOOOOOOOOOOOOOOOg as "component" {
file f4
}
database databaseVeryLOOOOOOOOOOOOOOOOOOOg as "database" {
file f5
}
file fileVeryLOOOOOOOOOOOOOOOOOOOg as "file" {
file f6
}
folder folderVeryLOOOOOOOOOOOOOOOOOOOg as "folder" {
file f7
}
frame frameVeryLOOOOOOOOOOOOOOOOOOOg as "frame" {
file f8
}
hexagon hexagonVeryLOOOOOOOOOOOOOOOOOOOg as "hexagon" {
file f9
}
node nodeVeryLOOOOOOOOOOOOOOOOOOOg as "node" {
file f10
}
package packageVeryLOOOOOOOOOOOOOOOOOOOg as "package" {
file f11
}
queue queueVeryLOOOOOOOOOOOOOOOOOOOg as "queue" {
file f12
}
rectangle rectangleVeryLOOOOOOOOOOOOOOOOOOOg as "rectangle" {
file f13
}
stack stackVeryLOOOOOOOOOOOOOOOOOOOg as "stack" {
file f14
}
storage storageVeryLOOOOOOOOOOOOOOOOOOOg as "storage" {
file f15
}
@enduml
''');
    });

    test('D4.2: heterogeneous nested containers (artifact, folder, frame, '
        'cloud > node > stack)', () {
      _parse('''
@startuml
artifact Foo1 {
folder Foo2
}
folder Foo3 {
artifact Foo4
}
frame Foo5 {
database Foo6
}
cloud vpc {
node ec2 {
stack stack
}
}
@enduml
''');
    });

    test('D4.3: alias forms (identifier-as-alias, quoted-display-as-alias, '
        'bracket label) + relations', () {
      _parse('''
@startuml
node Node1 as n1
node "Node 2" as n2
file f1 as "File 1"
cloud c1 as "this is a cloud"
cloud c2 [this is another cloud]
n1 -> n2
n1 --> f1
f1 -> c1
c1 -> c2
@enduml
''');
    });
  });
}
