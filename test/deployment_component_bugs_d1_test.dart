import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('deployment / component diagram bugs D1.1-D1.5', () {
    test('D1.1: multi-line bracketed descriptions on folder/node/database/usecase/card',
        () {
      _parse('''
@startuml
folder folder [
This is a <b>folder
----
You can use separator ====
of different kind ....
and style
]
node node [
This is a <b>node
----
You can use separator ====
of different kind ....
and style
]
database database [
This is a <b>database
----
You can use separator ====
of different kind ....
and style
]
usecase usecase [
This is a <b>usecase
----
You can use separator ====
of different kind ....
and style
]
card card [
This is a <b>card
----
You can use separator ====
of different kind ....
and style <i><color:blue>(add from V1.2020.7)</color></i>
]
@enduml
''');
    });

    test('D1.2: interface short forms + label', () {
      _parse('''
@startuml
interface interface1
() "interface2"
label "//interface example//"
@enduml
''');
    });

    test('D1.3: node arrow types -- .. ~~ ==', () {
      _parse('''
@startuml
node node1
node node2
node node3
node node4
node node5
node1 -- node2 : label1
node1 .. node3 : label2
node1 ~~ node4 : label3
node1 == node5
@enduml
''');
    });

    test('D1.4: artifact arrow tail types', () {
      _parse('''
@startuml
artifact artifact1
artifact artifact2
artifact artifact3
artifact artifact4
artifact artifact5
artifact artifact6
artifact artifact7
artifact artifact8
artifact artifact9
artifact artifact10
artifact1 --> artifact2
artifact1 --* artifact3
artifact1 --o artifact4
artifact1 --+ artifact5
artifact1 --# artifact6
artifact1 -->> artifact7
artifact1 --0 artifact8
artifact1 --^ artifact9
artifact1 --(0 artifact10
@enduml
''');
    });

    test('D1.5: cloud lollipop arrows', () {
      _parse('''
@startuml
cloud cloud1
cloud cloud2
cloud cloud3
cloud cloud4
cloud cloud5
cloud1 -0- cloud2
cloud1 -0)- cloud3
cloud1 -(0- cloud4
cloud1 -(0)- cloud5
@enduml
''');
    });

    test('D1.6: esoteric arrow combinations parse without error', () {
      // Aggregate of PlantUML deployment / component diagram arrow shapes
      // that previously crashed the lexer / parser: bidirectional lollipop
      // forms (`<-0->`, `<-(0)->`), direction-hint with embedded lollipop
      // (`-le(0)->`, `~up(0)~>`, `.up(0).>`), chained-lollipop component
      // arrows (`0)-(0-(0`, `)-0-(0`), hash-prefix arrows (`#~~(`,
      // `#-->>`), and mixed head/tail decorations (`*-0)-+`, `<-->>`).
      _parse('''
@startuml
actor foo1
actor foo2
foo1 <-0-> foo2
foo1 <-(0)-> foo2
(ac1) -le(0)-> left1
ac1 -ri(0)-> right1
ac1 .up(0).> up1
ac1 ~up(0)~> up2
ac1 -do(0)-> down1
ac1 -do(0)-> down2
actor1 -0)- actor2
component comp1
component comp2
comp1 *-0)-+ comp2
[comp3] <-->> [comp4]
boundary b1
control c1
b1 -(0)- c1
component comp1
interface interf1
comp1 #~~( interf1
:mode1actor: -0)- fooa1
:mode1actorl: -ri0)- foo1l
[component1] 0)-(0-(0 [componentC]
() component3 )-0-(0 "foo" [componentC]
[aze1] #-->> [aze2]
@enduml
''');
    });
  });
}
