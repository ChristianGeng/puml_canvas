import 'sample_models.dart';

const deploymentSubSamples = <SubSample>[
  SubSample(
    name: 'Declaring element',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Declaring element with long descriptions',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Actor short form',
    source: '''@startuml
actor actor1
:actor2:
@enduml''',
  ),
  SubSample(
    name: 'Component short form',
    source: '''@startuml
component component1
[component2]
@enduml''',
  ),
  SubSample(
    name: 'Interface short form',
    source: '''@startuml
interface interface1
() "interface2"
label "//interface example//"
@enduml''',
  ),
  SubSample(
    name: 'Usecase short form',
    source: '''@startuml
usecase usecase1
(usecase2)
@enduml''',
  ),
  SubSample(
    name: 'Linking or arrow - basic types',
    source: '''@startuml
node node1
node node2
node node3
node node4
node node5
node1 -- node2 : label1
node1 .. node3 : label2
node1 ~~ node4 : label3
node1 == node5
@enduml''',
  ),
  SubSample(
    name: 'Linking or arrow - arrow heads',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Linking or arrow - circle arrows',
    source: '''@startuml
cloud cloud1
cloud cloud2
cloud cloud3
cloud cloud4
cloud cloud5
cloud1 -0- cloud2
cloud1 -0)- cloud3
cloud1 -(0- cloud4
cloud1 -(0)- cloud5
@enduml''',
  ),
  SubSample(
    name: 'Linking or arrow - directional arrows',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Bracketed arrow style - line style without label',
    source: '''@startuml
node foo
title Bracketed line style without label
foo --> bar
foo -[bold]-> bar1
foo -[dashed]-> bar2
foo -[dotted]-> bar3
foo -[hidden]-> bar4
foo -[plain]-> bar5
@enduml''',
  ),
  SubSample(
    name: 'Bracketed arrow style - line style with label',
    source: '''@startuml
title Bracketed line style with label
node foo
foo --> bar : ∅
foo -[bold]-> bar1 : [bold]
foo -[dashed]-> bar2 : [dashed]
foo -[dotted]-> bar3 : [dotted]
foo -[hidden]-> bar4 : [hidden]
foo -[plain]-> bar5 : [plain]
@enduml''',
  ),
  SubSample(
    name: 'Bracketed arrow style - line color',
    source: '''@startuml
title Bracketed line color
node foo
foo --> bar
foo -[#red]-> bar1 : [#red]
foo -[#green]-> bar2 : [#green]
foo -[#blue]-> bar3 : [#blue]
foo -[#blue;#yellow;#green]-> bar4
@enduml''',
  ),
  SubSample(
    name: 'Bracketed arrow style - line thickness',
    source: '''@startuml
title Bracketed line thickness
node foo
foo --> bar : ∅
foo -[thickness=1]-> bar1 : [1]
foo -[thickness=2]-> bar2 : [2]
foo -[thickness=4]-> bar3 : [4]
foo -[thickness=8]-> bar4 : [8]
foo -[thickness=16]-> bar5 : [16]
@enduml''',
  ),
  SubSample(
    name: 'Bracketed arrow style - mixed styles',
    source: '''@startuml
title Bracketed line style mix
node foo
foo --> bar : ∅
foo -[#red,thickness=1]-> bar1 : [#red,1]
foo -[#red,dashed,thickness=2]-> bar2 : [#red,dashed,2]
foo -[#green,dashed,thickness=4]-> bar3 : [#green,dashed,4]
foo -[#blue,dotted,thickness=8]-> bar4 : [blue,dotted,8]
foo -[#blue,plain,thickness=16]-> bar5 : [blue,plain,16]
foo -[#blue;#green,dashed,thickness=4]-> bar6 : [blue;green,dashed,4]
@enduml''',
  ),
  SubSample(
    name: 'Change arrow color and style (inline style)',
    source: '''@startuml
node foo
foo --> bar : normal
foo --> bar1 #line:red;line.bold;text:red : red bold
foo --> bar2 #green;line.dashed;text:green : green dashed
foo --> bar3 #blue;line.dotted;text:blue : blue dotted
@enduml''',
  ),
  SubSample(
    name: 'Change element color and style (inline style)',
    source: '''@startuml
agent a
cloud c #pink;line:red;line.bold;text:red
file f #palegreen;line:green;line.dashed;text:green
node n #aliceblue;line:blue;line.dotted;text:blue
@enduml''',
  ),
  SubSample(
    name: 'Change element color and style with description',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Nestable elements',
    source: '''@startuml
action action {
}
artifact artifact {
}
card card {
}
cloud cloud {
}
component component {
}
database database {
}
file file {
}
folder folder {
}
frame frame {
}
hexagon hexagon {
}
node node {
}
package package {
}
process process {
}
queue queue {
}
rectangle rectangle {
}
stack stack {
}
storage storage {
}
@enduml''',
  ),
  SubSample(
    name: 'Packages and nested elements - one level',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Packages and nested elements - other example',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Packages and nested elements - cloud and storage nesting',
    source: '''@startuml
node Foo1 {
cloud Foo2
}
cloud Foo3 {
frame Foo4
}
database Foo5 {
storage Foo6
}
storage Foo7 {
storage Foo8
}
@enduml''',
  ),
  SubSample(
    name: 'Full nesting - alphabetical order',
    source: '''@startuml
action action {
artifact artifact {
card card {
cloud cloud {
component component {
database database {
file file {
folder folder {
frame frame {
hexagon hexagon {
node node {
package package {
process process {
queue queue {
rectangle rectangle {
stack stack {
storage storage {
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
@enduml''',
  ),
  SubSample(
    name: 'Full nesting - reverse alphabetical order',
    source: '''@startuml
storage storage {
stack stack {
rectangle rectangle {
queue queue {
process process {
package package {
node node {
hexagon hexagon {
frame frame {
folder folder {
file file {
database database {
component component {
cloud cloud {
card card {
artifact artifact {
action action {
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
@enduml''',
  ),
  SubSample(
    name: 'Alias - simple alias with as',
    source: '''@startuml
node Node1 as n1
node "Node 2" as n2
file f1 as "File 1"
cloud c1 as "this is a cloud"
cloud c2 as "this is another cloud"
n1 -> n2
n1 --> f1
f1 -> c1
c1 -> c2
@enduml''',
  ),
  SubSample(
    name: 'Alias - long alias examples (first variant)',
    source: '''@startuml
actor "actor" as actorVeryLOOOOOOOOOOOOOOOOOOOg
agent "agent" as agentVeryLOOOOOOOOOOOOOOOOOOOg
artifact "artifact" as artifactVeryLOOOOOOOOOOOOOOOOOOOg
boundary "boundary" as boundaryVeryLOOOOOOOOOOOOOOOOOOOg
card "card" as cardVeryLOOOOOOOOOOOOOOOOOOOg
cloud "cloud" as cloudVeryLOOOOOOOOOOOOOOOOOOOg
collections "collections" as collectionsVeryLOOOOOOOOOOOOOOOOOOOg
component "component" as componentVeryLOOOOOOOOOOOOOOOOOOOg
control "control" as controlVeryLOOOOOOOOOOOOOOOOOOOg
database "database" as databaseVeryLOOOOOOOOOOOOOOOOOOOg
entity "entity" as entityVeryLOOOOOOOOOOOOOOOOOOOg
file "file" as fileVeryLOOOOOOOOOOOOOOOOOOOg
folder "folder" as folderVeryLOOOOOOOOOOOOOOOOOOOg
frame "frame" as frameVeryLOOOOOOOOOOOOOOOOOOOg
hexagon "hexagon" as hexagonVeryLOOOOOOOOOOOOOOOOOOOg
interface "interface" as interfaceVeryLOOOOOOOOOOOOOOOOOOOg
label "label" as labelVeryLOOOOOOOOOOOOOOOOOOOg
node "node" as nodeVeryLOOOOOOOOOOOOOOOOOOOg
package "package" as packageVeryLOOOOOOOOOOOOOOOOOOOg
person "person" as personVeryLOOOOOOOOOOOOOOOOOOOg
queue "queue" as queueVeryLOOOOOOOOOOOOOOOOOOOg
stack "stack" as stackVeryLOOOOOOOOOOOOOOOOOOOg
rectangle "rectangle" as rectangleVeryLOOOOOOOOOOOOOOOOOOOg
storage "storage" as storageVeryLOOOOOOOOOOOOOOOOOOOg
usecase "usecase" as usecaseVeryLOOOOOOOOOOOOOOOOOOOg
@enduml''',
  ),
  SubSample(
    name: 'Alias - long alias examples (second variant)',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Round corner',
    source: '''@startuml
skinparam rectangle {
roundCorner<<Concept>> 25
}
rectangle "Concept Model" <<Concept>> {
rectangle "Example 1" <<Concept>> as ex1
rectangle "Another rectangle"
}
@enduml''',
  ),
  SubSample(
    name: 'Specific SkinParameter - roundCorner',
    source: '''@startuml
skinparam roundCorner 15
actor actor
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
queue queue
rectangle rectangle
stack stack
storage storage
usecase usecase
@enduml''',
  ),
  SubSample(
    name: 'Appendix - all type of arrow line',
    source: '''@startuml
left to right direction
skinparam nodesep 5
f3 ~~ b3 : ""~~""\\n//dotted//
f2 .. b2 : ""..""\\n//dashed//
f1 == b1 : ""==""\\n//bold//
f0 -- b0 : ""--""\\n//plain//
@enduml''',
  ),
  SubSample(
    name: 'Appendix - all type of arrow head',
    source: '''@startuml
left to right direction
skinparam nodesep 5
label " "
f13 --0 b13 : ""--0""
f12 --@ b12 : ""--@""
f11 --:|> b11 : ""--:|>""
f10 --||> b10 : ""--||>""
f9 --|> b9 : ""--|>""
f8 --^ b8 : ""--^ ""
f7 --\\\\ b7 : ""--\\\\\\\\""
f6 --# b6 : ""--# ""
f5 --+ b5 : ""--+ ""
f4 --o b4 : ""--o ""
f3 --* b3 : ""--* ""
f2 -->> b2 : ""-->>""
f1 --> b1 : ""--> ""
f0 -- b0 : ""-- ""
@enduml''',
  ),
  SubSample(
    name: 'Appendix - all type of circle arrow',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Appendix - inline style on all elements',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Display JSON Data on Deployment diagram',
    source: '''@startuml
allowmixing
component Component
actor Actor
usecase Usecase
() Interface
node Node
cloud Cloud
json JSON {
"fruit":"Apple",
"size":"Large",
"color": ["Red", "Green"]
}
@enduml''',
  ),
  SubSample(
    name: 'Mixing all elements',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Port',
    source: '''@startuml
[c]
node node {
port p1
port p2
port p3
file f1
}
c --> p1
c --> p2
c --> p3
p1 --> f1
p2 --> f1
@enduml''',
  ),
  SubSample(
    name: 'PortIn',
    source: '''@startuml
[c]
node node {
portin p1
portin p2
portin p3
file f1
}
c --> p1
c --> p2
c --> p3
p1 --> f1
p2 --> f1
@enduml''',
  ),
  SubSample(
    name: 'PortOut',
    source: '''@startuml
node node {
portout p1
portout p2
portout p3
file f1
}
[o]
p1 --> o
p2 --> o
p3 --> o
f1 --> p1
@enduml''',
  ),
  SubSample(
    name: 'Mixing PortIn & PortOut',
    source: '''@startuml
[i]
node node {
portin p1
portin p2
portin p3
portout po1
portout po2
portout po3
file f1
}
[o]
i --> p1
i --> p2
i --> p3
p1 --> f1
p2 --> f1
po1 --> o
po2 --> o
po3 --> o
f1 --> po1
@enduml''',
  ),
  SubSample(
    name: 'Change diagram orientation - top to bottom with Graphviz',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Change diagram orientation - top to bottom with Smetana',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Change diagram orientation - left to right with Graphviz',
    source: '''@startuml
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
@enduml''',
  ),
  SubSample(
    name: 'Change diagram orientation - left to right with Smetana',
    source: '''@startuml
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
@enduml''',
  ),
];
