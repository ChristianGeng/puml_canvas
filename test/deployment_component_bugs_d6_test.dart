import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('deployment / component diagram bugs D6.1-D6.6', () {
    test('D6.1: inline styles on ALL 30 element types', () {
      _parse('''
@startuml
action action #aliceblue;line:blue;line.dotted;text:blue
actor actor #aliceblue;line:blue;line.dotted;text:blue
actor/ "actor/" #aliceblue;line:blue;line.dotted;text:blue
agent agent #aliceblue;line:blue;line.dotted;text:blue
artifact artifact #aliceblue;line:blue;line.dotted;text:blue
boundary boundary #aliceblue;line:blue;line.dotted;text:blue
card card #aliceblue;line:blue;line.dotted;text:blue
circle circle #aliceblue;line:blue;line.dotted;text:blue
cloud cloud #aliceblue;line:blue;line.dotted;text:blue
collections collections #aliceblue;line:blue;line.dotted;text:blue
component component #aliceblue;line:blue;line.dotted;text:blue
control control #aliceblue;line:blue;line.dotted;text:blue
database database #aliceblue;line:blue;line.dotted;text:blue
entity entity #aliceblue;line:blue;line.dotted;text:blue
file file #aliceblue;line:blue;line.dotted;text:blue
folder folder #aliceblue;line:blue;line.dotted;text:blue
frame frame #aliceblue;line:blue;line.dotted;text:blue
hexagon hexagon #aliceblue;line:blue;line.dotted;text:blue
interface interface #aliceblue;line:blue;line.dotted;text:blue
label label #aliceblue;line:blue;line.dotted;text:blue
node node #aliceblue;line:blue;line.dotted;text:blue
package package #aliceblue;line:blue;line.dotted;text:blue
person person #aliceblue;line:blue;line.dotted;text:blue
process process #aliceblue;line:blue;line.dotted;text:blue
queue queue #aliceblue;line:blue;line.dotted;text:blue
rectangle rectangle #aliceblue;line:blue;line.dotted;text:blue
stack stack #aliceblue;line:blue;line.dotted;text:blue
storage storage #aliceblue;line:blue;line.dotted;text:blue
usecase usecase #aliceblue;line:blue;line.dotted;text:blue
usecase/ "usecase/" #aliceblue;line:blue;line.dotted;text:blue
@enduml
''');
    });

    test('D6.2: allowmixing MASSIVE matrix', () {
      _parse('''
@startuml
allowmixing
skinparam nodesep 10
hide empty members
abstract abstract
abstract class "abstract class"
annotation annotation
circle circle
() circle_short_form
class class
class class_stereo <<stereotype>>
dataclass dataclass
diamond diamond
<> diamond_short_form
entity entity
enum enum
exception exception
interface interface
metaclass metaclass
protocol protocol
record record
stereotype stereotype
struct struct
object object
map map {
key => value
}
json JSON {
"fruit":"Apple",
"size":"Large",
"color": ["Red", "Green"]
}
action action
actor actor
actor/ "actor/"
agent agent
artifact artifact
boundary boundary
card card
circle circle
cloud cloud
collections collections
component component
control control
database database
entity entity
file file
folder folder
frame frame
hexagon hexagon
interface interface
label label
node node
package package
person person
process process
queue queue
rectangle rectangle
stack stack
storage storage
usecase usecase
usecase/ "usecase/"
state state
@enduml
''');
    });

    test('D6.3: card/package nested + sub_a/sub_b', () {
      _parse('''
@startuml
card a
card b
package A {
card a1
card a2
card a3
card a4
card a5
package sub_a {
card sa1
card sa2
card sa3
}
}
package B {
card b1
card b2
card b3
card b4
card b5
package sub_b {
card sb1
card sb2
card sb3
}
}
@enduml
''');
    });

    test('D6.4: D6.3 + !pragma layout smetana', () {
      _parse('''
@startuml
!pragma layout smetana
card a
card b
package A {
card a1
card a2
card a3
card a4
card a5
package sub_a {
card sa1
card sa2
card sa3
}
}
package B {
card b1
card b2
card b3
card b4
card b5
package sub_b {
card sb1
card sb2
card sb3
}
}
@enduml
''');
    });

    test('D6.5: D6.3 + left to right direction', () {
      _parse('''
@startuml
left to right direction
card a
card b
package A {
card a1
card a2
card a3
card a4
card a5
package sub_a {
card sa1
card sa2
card sa3
}
}
package B {
card b1
card b2
card b3
card b4
card b5
package sub_b {
card sb1
card sb2
card sb3
}
}
@enduml
''');
    });

    test('D6.6: D6.3 + !pragma layout smetana + left to right direction', () {
      _parse('''
@startuml
!pragma layout smetana
left to right direction
card a
card b
package A {
card a1
card a2
card a3
card a4
card a5
package sub_a {
card sa1
card sa2
card sa3
}
}
package B {
card b1
card b2
card b3
card b4
card b5
package sub_b {
card sb1
card sb2
card sb3
}
}
@enduml
''');
    });
  });
}
