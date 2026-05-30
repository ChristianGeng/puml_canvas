import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('deployment / component diagram bugs D5.1-D5.5', () {
    test('D5.1: all element kinds with long alias + quoted display', () {
      _parse('''
@startuml
actor actorVeryLOOOOOOOOOOOOOOOOOOOg as "actor"
agent agentVeryLOOOOOOOOOOOOOOOOOOOg as "agent"
artifact artifactVeryLOOOOOOOOOOOOOOOOOOOg as "artifact"
boundary boundaryVeryLOOOOOOOOOOOOOOOOOOOg as "boundary"
card cardVeryLOOOOOOOOOOOOOOOOOOOg as "card"
cloud cloudVeryLOOOOOOOOOOOOOOOOOOOg as "cloud"
collections collectionsVeryLOOOOOOOOOOOOOOOOOOOg as "collections"
component componentVeryLOOOOOOOOOOOOOOOOOOOg as "component"
control controlVeryLOOOOOOOOOOOOOOOOOOOg as "control"
database databaseVeryLOOOOOOOOOOOOOOOOOOOg as "database"
entity entityVeryLOOOOOOOOOOOOOOOOOOOg as "entity"
file fileVeryLOOOOOOOOOOOOOOOOOOOg as "file"
folder folderVeryLOOOOOOOOOOOOOOOOOOOg as "folder"
frame frameVeryLOOOOOOOOOOOOOOOOOOOg as "frame"
hexagon hexagonVeryLOOOOOOOOOOOOOOOOOOOg as "hexagon"
interface interfaceVeryLOOOOOOOOOOOOOOOOOOOg as "interface"
label labelVeryLOOOOOOOOOOOOOOOOOOOg as "label"
node nodeVeryLOOOOOOOOOOOOOOOOOOOg as "node"
package packageVeryLOOOOOOOOOOOOOOOOOOOg as "package"
person personVeryLOOOOOOOOOOOOOOOOOOOg as "person"
queue queueVeryLOOOOOOOOOOOOOOOOOOOg as "queue"
stack stackVeryLOOOOOOOOOOOOOOOOOOOg as "stack"
rectangle rectangleVeryLOOOOOOOOOOOOOOOOOOOg as "rectangle"
storage storageVeryLOOOOOOOOOOOOOOOOOOOg as "storage"
usecase usecaseVeryLOOOOOOOOOOOOOOOOOOOg as "usecase"
@enduml
''');
    });

    test('D5.2: skinparam rectangle roundCorner stereotype + nested stereotype rectangles',
        () {
      _parse('''
@startuml
skinparam rectangle {
roundCorner<<Concept>> 25
}
rectangle "Concept Model" <<Concept>> {
rectangle "Example 1" <<Concept>> as ex1
rectangle "Another rectangle"
}
@enduml
''');
    });

    test('D5.3: label conventions (~~, .., ==, --) + left to right', () {
      _parse('''
@startuml
left to right direction
skinparam nodesep 5
f3 ~~ b3 : ""~~""\\n//dotted//
f2 .. b2 : ""..""\\n//dashed//
f1 == b1 : ""==""\\n//bold//
f0 -- b0 : ""--""\\n//plain//
@enduml
''');
    });

    test('D5.4: massive arrow head matrix', () {
      _parse('''
@startuml
left to right direction
skinparam nodesep 5
label " "
f13 --0 b13 : ""--0""
f12 --@ b12 : ""--@""
f11 --:|> b11 : ""--:|>""
f10 --||> b10 : ""--||>""
f9 --|> b9 : ""--|>""
f8 --^ b8 : ""--^ ""
f7 --\\ b7 : ""--\\\\\\\\""
f6 --# b6 : ""--# ""
f5 --+ b5 : ""--+ ""
f4 --o b4 : ""--o ""
f3 --* b3 : ""--* ""
f2 -->> b2 : ""-->>""
f1 --> b1 : ""--> ""
f0 -- b0 : ""-- ""
@enduml
''');
    });

    test('D5.5: lollipop matrix', () {
      _parse('''
@startuml
left to right direction
skinparam nodesep 5
label " "
f10 0--0 b10 : "" 0--0 ""
f9 )--( b9 : "" )--( ""
f8 0)--(0 b8 : "" 0)--(0""
f7 0)-- b7 : "" 0)-- ""
f6 -0)- b6 : "" -0)- ""
f5 -(0)- b5 : "" -(0)-""
f4 -(0- b4 : "" -(0- ""
f3 --(0 b3 : "" --(0 ""
f2 --( b2 : "" --( ""
f1 --0 b1 : "" --0 ""
@enduml
''');
    });
  });
}
