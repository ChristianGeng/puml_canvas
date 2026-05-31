import 'sample_models.dart';

const classSubSamples = <SubSample>[
  SubSample(name: 'Declarative element', source: '''
@startuml
hide empty members
abstract        abstract
abstract class  "abstract class"
annotation      annotation
circle          circle
()              circle_short_form
class           class
class           class_stereo  <<stereotype>>
dataclass       dataclass
diamond         diamond
<>              diamond_short_form
entity          entity
enum            enum
exception       exception
interface       interface
metaclass       metaclass
protocol        protocol
record          record
stereotype      stereotype
struct          struct
@enduml
'''),
  SubSample(name: 'Relations between classes', source: '''
@startuml
Class01 <|-- Class02
Class03 *-- Class04
Class05 o-- Class06
Class07 .. Class08
Class09 -- Class10
@enduml
'''),
  SubSample(name: 'Relations between classes (2)', source: '''
@startuml
Class11 <|.. Class12
Class13 --> Class14
Class15 ..> Class16
Class17 ..|> Class18
Class19 <--* Class20
@enduml
'''),
  SubSample(name: 'Relations between classes (3)', source: '''
@startuml
Class21 #-- Class22
Class23 x-- Class24
Class25 }-- Class26
Class27 +-- Class28
Class29 ^-- Class30
@enduml
'''),
  SubSample(name: 'Label on relations', source: '''
@startuml
Class01 "1" *-- "many" Class02 : contains
Class03 o-- Class04 : aggregation
Class05 --> "1" Class06
@enduml
'''),
  SubSample(name: 'Label on relations (with direction)', source: '''
@startuml
class Car
Driver - Car : drives >
Car *- Wheel : have 4 >
Car -- Person : < owns
@enduml
'''),
  SubSample(name: 'Using non-letters in element names', source: '''
@startuml
class "This is my class" as class1
class class2 as "It works this way too"
class2 *-- "foo/dummy" : use
@enduml
'''),
  SubSample(name: 'Using non-letters with dollar names', source: '''
@startuml
class \$C1
class \$C2
class "\$C2" as dollarC2
remove \$C1
remove \$C2
remove dollarC2
@enduml
'''),
  SubSample(name: 'Adding methods', source: '''
@startuml
Object <|-- ArrayList
Object : equals()
ArrayList : Object[] elementData
ArrayList : size()
@enduml
'''),
  SubSample(name: 'Adding methods (with braces)', source: '''
@startuml
class Dummy {
  String data
  void methods()
}
class Flight {
  flightNumber : Integer
  departureTime : Date
}
@enduml
'''),
  SubSample(name: 'Adding methods (with field/method tags)', source: '''
@startuml
class Dummy {
  {field} A field (despite parentheses)
  {method} Some method
}
@enduml
'''),
  SubSample(name: 'Defining visibility', source: '''
@startuml
class Dummy {
  -field1
  #field2
  ~method1()
  +method2()
}
@enduml
'''),
  SubSample(name: 'Defining visibility (no icons)', source: '''
@startuml
skinparam classAttributeIconSize 0
class Dummy {
  -field1
  #field2
  ~method1()
  +method2()
}
@enduml
'''),
  SubSample(name: 'Defining visibility (default)', source: '''
@startuml
class Dummy {
  field1
  field2
  method1()
  method2()
}
@enduml
'''),
  SubSample(name: 'Defining visibility (destructor)', source: '''
@startuml
class Dummy {
  field1
  \\~Dummy()
  method1()
}
@enduml
'''),
  SubSample(name: 'Defining visibility (on class)', source: '''
@startuml
-class "private Class" { }
#class "protected Class" { }
~class "package private Class" { }
+class "public Class" { }
@enduml
'''),
  SubSample(name: 'Visibility on compositions and aggregations', source: '''
@startuml
class Aaa {
  -bbb : int
  +ccc : string
  #aa : float
  +void addEntry(mmm : Entry)
  +int setFactory(ddd : string)
}
class Factory {
  #fff : string
}
class Entry {
  -yyy : int
}
class Parent { }
Aaa *--> "1..100" Entry : -entries
Aaa o--> Factory : #factory
Aaa o--> Parent : +parent
@enduml
'''),
  SubSample(name: 'Abstract and Static', source: '''
@startuml
class Dummy {
  {static} String id
  {abstract} void methods()
}
@enduml
'''),
  SubSample(name: 'Advanced class body', source: '''
@startuml
class Foo1 {
  You can use several lines .. as you want and group == things together.
  __ You can have as many groups as you want
  -- End of class
}
class User {
  .. Simple Getter ..
  + getName()
  + getAddress()
  .. Some setter ..
  + setName()
  __ private data __
  int age
  -- encrypted --
  String password
}
@enduml
'''),
  SubSample(name: 'Notes and stereotypes', source: '''
@startuml
class Object << general >>
Object <|--- ArrayList
note top of Object : In java, every class\\nextends this one.
note "This is a floating note" as N1
note "This note is connected\\nto several objects." as N2
Object .. N2
N2 .. ArrayList
class Foo
note left: On last defined class
@enduml
'''),
  SubSample(name: 'More on notes', source: '''
@startuml
class Foo
note left: On last defined class
note top of Foo
  In java, <size:18>every</size> <u>class</u>
  <b>extends</b> <i>this</i> one.
end note
note as N1
  This note is <u>also</u> <b><color:royalBlue>on
  several</color> <s>words</s> lines
  And this is hosted by <img:https://plantuml.com/sourceforge.jpg>
end note
@enduml
'''),
  SubSample(name: 'Note on field or method', source: '''
@startuml
class A {
  {static} int counter
  +void {abstract} start(int timeout)
}
note right of A::counter
  This member is annotated
end note
note right of A::start
  This method is now explained in a UML note
end note
@enduml
'''),
  SubSample(name: 'Note on field or method (overloaded)', source: '''
@startuml
class A {
  {static} int counter
  +void {abstract} start(int timeoutms)
  +void {abstract} start(Duration timeout)
}
note left of A::counter
  This member is annotated
end note
note right of A::"start(int timeoutms)"
  This method with int
end note
note right of A::"start(Duration timeout)"
  This method with Duration
end note
@enduml
'''),
  SubSample(name: 'Note on links', source: '''
@startuml
class Dummy
Dummy --> Foo : A link
note on link #red: note that is red
Dummy --> Foo2 : Another link
note right on link #blue
  this is my note on right link and in blue
end note
@enduml
'''),
  SubSample(name: 'Abstract class and interface', source: '''
@startuml
abstract class AbstractList
abstract AbstractCollection
interface List
interface Collection
List <|-- AbstractList
Collection <|-- AbstractCollection
Collection <|- List
AbstractCollection <|- AbstractList
AbstractList <|-- ArrayList
class ArrayList {
  Object[] elementData
  size()
}
enum TimeUnit {
  DAYS
  HOURS
  MINUTES
}
annotation SuppressWarnings
annotation Annotation {
  annotation with members
  String foo()
  String bar()
}
@enduml
'''),
  SubSample(name: 'Hide attributes, methods', source: '''
@startuml
class Dummy1 {
  +myMethods()
}
class Dummy2 {
  +hiddenMethod()
}
class Dummy3 <<Serializable>> {
  String name
}
hide members
hide <<Serializable>> circle
show Dummy1 methods
show <<Serializable>> fields
@enduml
'''),
  SubSample(name: 'Hide by visibility', source: '''
@startuml
hide private members
hide protected members
hide package members
class Foo {
  - private
  # protected
  ~ package
}
@enduml
'''),
  SubSample(name: 'Hide classes', source: '''
@startuml
class Foo1
class Foo2
Foo2 *-- Foo1
hide Foo2
@enduml
'''),
  SubSample(name: 'Remove classes', source: '''
@startuml
class Foo1
class Foo2
Foo2 *-- Foo1
remove Foo2
@enduml
'''),
  SubSample(name: 'Tagged element (base)', source: '''
@startuml
class C1 \$tag13
enum E1
interface I1 \$tag13
C1 -- I1
@enduml
'''),
  SubSample(name: 'Tagged element (hide)', source: '''
@startuml
class C1 \$tag13
enum E1
interface I1 \$tag13
C1 -- I1
hide \$tag13
@enduml
'''),
  SubSample(name: 'Tagged element (remove)', source: '''
@startuml
class C1 \$tag13
enum E1
interface I1 \$tag13
C1 -- I1
remove \$tag13
@enduml
'''),
  SubSample(name: 'Tagged element (remove + restore)', source: '''
@startuml
class C1 \$tag13 \$tag1
enum E1
interface I1 \$tag13
C1 -- I1
remove \$tag13
restore \$tag1
@enduml
'''),
  SubSample(name: 'Tagged element (remove wildcard + restore)', source: '''
@startuml
class C1 \$tag13 \$tag1
enum E1
interface I1 \$tag13
C1 -- I1
remove *
restore \$tag1
@enduml
'''),
  SubSample(name: 'Unlinked class (base)', source: '''
@startuml
class C1
class C2
class C3
C1 -- C2
@enduml
'''),
  SubSample(name: 'Unlinked class (hide)', source: '''
@startuml
class C1
class C2
class C3
C1 -- C2
hide @unlinked
@enduml
'''),
  SubSample(name: 'Unlinked class (remove)', source: '''
@startuml
class C1
class C2
class C3
C1 -- C2
remove @unlinked
@enduml
'''),
  SubSample(name: 'Use generics', source: '''
@startuml
class Foo<? extends Element> {
  int size()
}
Foo *- Element
@enduml
'''),
  SubSample(name: 'Specific Spot', source: '''
@startuml
class System << (S,#FF7700) Singleton >>
class Date << (D,orchid) >>
@enduml
'''),
  SubSample(name: 'Packages', source: '''
@startuml
package "Classic Collections" #DDDDDD {
  Object <|-- ArrayList
}
package com.plantuml {
  Object <|-- Demo1
  Demo1 *- Demo2
}
@enduml
'''),
  SubSample(name: 'Packages style', source: '''
@startuml
scale 750 width
package foo1 <<Node>> {
  class Class1
}
package foo2 <<Rectangle>> {
  class Class2
}
package foo3 <<Folder>> {
  class Class3
}
package foo4 <<Frame>> {
  class Class4
}
package foo5 <<Cloud>> {
  class Class5
}
package foo6 <<Database>> {
  class Class6
}
@enduml
'''),
  SubSample(name: 'Packages style (rectangle)', source: '''
@startuml
skinparam packageStyle rectangle
package foo1.foo2 { }
package foo1.foo2.foo3 {
  class Object
}
foo1.foo2 +-- foo1.foo2.foo3
@enduml
'''),
  SubSample(name: 'Automatic package creation', source: '''
@startuml
set separator ::
class X1::X2::foo {
  some info
}
@enduml
'''),
  SubSample(name: 'Automatic package creation (none)', source: '''
@startuml
set separator none
class X1.X2.foo {
  some info
}
@enduml
'''),
  SubSample(name: 'Lollipop interface', source: '''
@startuml
class foo
bar ()- foo
@enduml
'''),
  SubSample(name: 'Changing arrows orientation', source: '''
@startuml
Room o- Student
Room *-- Chair
@enduml
'''),
  SubSample(name: 'Changing arrows orientation (flip)', source: '''
@startuml
Student -o Room
Chair --* Room
@enduml
'''),
  SubSample(name: 'Changing arrows orientation (directions)', source: '''
@startuml
foo -left-> dummyLeft
foo -right-> dummyRight
foo -up-> dummyUp
foo -down-> dummyDown
@enduml
'''),
  SubSample(name: 'Changing arrows orientation (left to right)', source: '''
@startuml
left to right direction
foo -left-> dummyLeft
foo -right-> dummyRight
foo -up-> dummyUp
foo -down-> dummyDown
@enduml
'''),
  SubSample(name: 'Association classes', source: '''
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
'''),
  SubSample(name: 'Association classes (alt)', source: '''
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
'''),
  SubSample(name: 'Association on same class', source: '''
@startuml
class Station {
  +name: string
}
class StationCrossing {
  +cost: TimeInterval
}
<> diamond
StationCrossing . diamond
diamond - "from 0..*" Station
diamond - "to 0..*" Station
@enduml
'''),
  SubSample(name: 'Skinparam', source: '''
@startuml
skinparam class {
  BackgroundColor PaleGreen
  ArrowColor SeaGreen
  BorderColor SpringGreen
}
skinparam stereotypeCBackgroundColor YellowGreen
Class01 "1" *-- "many" Class02 : contains
Class03 o-- Class04 : aggregation
@enduml
'''),
  SubSample(name: 'Skinned Stereotypes', source: '''
@startuml
skinparam class {
  BackgroundColor PaleGreen
  ArrowColor SeaGreen
  BorderColor SpringGreen
  BackgroundColor<<Foo>> Wheat
  BorderColor<<Foo>> Tomato
}
skinparam stereotypeCBackgroundColor YellowGreen
skinparam stereotypeCBackgroundColor<<Foo>> DimGray
class Class01 <<Foo>>
class Class03 <<Foo>>
Class01 "1" *-- "many" Class02 : contains
Class03 o-- Class04 : aggregation
@enduml
'''),
  SubSample(name: 'Color gradient', source: '''
@startuml
skinparam backgroundcolor AntiqueWhite/Gold
skinparam classBackgroundColor Wheat|CornflowerBlue
class Foo #red-green
note left of Foo #blue\\9932CC
  this is my note on this class
end note
package example #GreenYellow/LightGoldenRodYellow {
  class Dummy
}
@enduml
'''),
  SubSample(name: 'Help on layout', source: '''
@startuml
class Bar1
class Bar2
together {
  class Together1
  class Together2
  class Together3
}
Together1 - Together2
Together2 - Together3
Together2 -[hidden]--> Bar1
Bar1 -[hidden]> Bar2
@enduml
'''),
  SubSample(name: 'Extends and implements', source: '''
@startuml
class ArrayList implements List
class ArrayList extends AbstractList
@enduml
'''),
  SubSample(name: 'Extends and implements (multiple)', source: '''
@startuml
class A extends B, C { }
@enduml
'''),
  SubSample(name: 'Bracketed relations style', source: '''
@startuml
title Bracketed line style without label
class foo
class bar
bar1 : [bold]
bar2 : [dashed]
bar3 : [dotted]
bar4 : [hidden]
bar5 : [plain]
foo --> bar
foo -[bold]-> bar1
foo -[dashed]-> bar2
foo -[dotted]-> bar3
foo -[hidden]-> bar4
foo -[plain]-> bar5
@enduml
'''),
  SubSample(name: 'Bracketed relations color', source: '''
@startuml
title Bracketed line color
class foo
class bar
bar1 : [#red]
bar2 : [#green]
bar3 : [#blue]
foo --> bar
foo -[#red]-> bar1 : [#red]
foo -[#green]-> bar2 : [#green]
foo -[#blue]-> bar3 : [#blue]
@enduml
'''),
];
