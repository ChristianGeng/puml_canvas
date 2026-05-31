import 'sample_models.dart';

const objectSubSamples = <SubSample>[
  SubSample(
    name: 'Definition of objects',
    source: '''@startuml
object firstObject
object "My Second Object" as o2
@enduml''',
  ),
  SubSample(
    name: 'Relations between objects',
    source: '''@startuml
object Object01
object Object02
object Object03
object Object04
object Object05
object Object06
object Object07
object Object08
Object01 <|-- Object02
Object03 *-- Object04
Object05 o-- "4" Object06
Object07 .. Object08 : some labels
@enduml''',
  ),
  SubSample(
    name: 'Associations objects',
    source: '''@startuml
object o1
object o2
diamond dia
object o3
o1 --> dia
o2 --> dia
dia --> o3
@enduml''',
  ),
  SubSample(
    name: 'Adding fields',
    source: '''@startuml
object user
user : name = "Dummy"
user : id = 123
@enduml''',
  ),
  SubSample(
    name: 'Adding fields (multiple objects)',
    source: '''@startuml
object user1
object user2
user1 : name = "User A"
user2 : name = "User B"
user1 : id = 123
user2 : id = 456
@enduml''',
  ),
  SubSample(
    name: 'Adding fields (grouped)',
    source: '''@startuml
object user {
  name = "Dummy"
  id = 123
}
@enduml''',
  ),
  SubSample(
    name: 'Map table or associative array',
    source: '''@startuml
map CapitalCity {
  UK => London
  USA => Washington
  Germany => Berlin
}
@enduml''',
  ),
  SubSample(
    name: 'Map table with title',
    source: '''@startuml
map "Map **Contry => CapitalCity**" as CC {
  UK => London
  USA => Washington
  Germany => Berlin
}
@enduml''',
  ),
  SubSample(
    name: 'Map table with type',
    source: '''@startuml
map "map: Map<Integer, String>" as users {
  1 => Alice
  2 => Bob
  3 => Charlie
}
@enduml''',
  ),
  SubSample(
    name: 'Map table with object link',
    source: '''@startuml
object London
map CapitalCity {
  UK *-> London
  USA => Washington
  Germany => Berlin
}
@enduml''',
  ),
  SubSample(
    name: 'Map table with multiple object links',
    source: '''@startuml
object London
object Washington
object Berlin
object NewYork
map CapitalCity {
  UK *-> London
  USA *--> Washington
  Germany *---> Berlin
}
NewYork --> CapitalCity::USA
@enduml''',
  ),
  SubSample(
    name: 'Map table with packages',
    source: '''@startuml
package foo {
  object baz
}
package bar {
  map A {
    b *-> foo.baz
    c =>
  }
}
A::c --> foo
@enduml''',
  ),
  SubSample(
    name: 'Map table with object and labeled relations',
    source: '''@startuml
object Foo
map Bar {
  abc=>
  def=>
}
object Baz
Bar::abc --> Baz : Label one
Foo --> Bar::def : Label two
@enduml''',
  ),
  SubSample(
    name: 'Program evaluation and review technique (PERT) with map',
    source: '''@startuml
left to right direction
' Horizontal lines: -->, <--, <-->
' Vertical lines: ->, <-, <->
title PERT: Project Name
map Kick.Off {
}
map task.1 {
  Start => End
}
map task.2 {
  Start => End
}
map task.3 {
  Start => End
}
map task.4 {
  Start => End
}
map task.5 {
  Start => End
}
Kick.Off --> task.1 : Label 1
Kick.Off --> task.2 : Label 2
Kick.Off --> task.3 : Label 3
task.1 --> task.4
task.2 --> task.4
task.3 --> task.4
task.4 --> task.5 : Label 4
@enduml''',
  ),
  SubSample(
    name: 'Display JSON Data on Class or Object diagram',
    source: '''@startuml
class Class
object Object
json JSON {
  "fruit":"Apple",
  "size":"Large",
  "color": ["Red", "Green"]
}
@enduml''',
  ),
];
