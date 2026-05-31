import 'sample_models.dart';

const sequenceSubSamples = <SubSample>[
  SubSample(
    name: 'Basic Examples',
    source: '''
@startuml
Alice -> Bob: Authentication Request
Bob --> Alice: Authentication Response
Alice -> Bob: Another authentication Request
Alice <-- Bob: Another authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Declaring participant',
    source: '''
@startuml
participant Participant as Foo
actor Actor as Foo1
boundary Boundary as Foo2
control Control as Foo3
entity Entity as Foo4
database Database as Foo5
collections Collections as Foo6
queue Queue as Foo7
Foo -> Foo1 : To actor
Foo -> Foo2 : To boundary
Foo -> Foo3 : To control
Foo -> Foo4 : To entity
Foo -> Foo5 : To database
Foo -> Foo6 : To collections
Foo -> Foo7: To queue
@enduml
''',
  ),
  SubSample(
    name: 'Declaring participant (with color)',
    source: '''
@startuml
actor Bob #red
' The only difference between actor 'and participant is the drawing
participant Alice
participant "I have a really\\nlong name" as L #99FF99
/' You can also declare:
participant L as "I have a really\\nlong name" #99FF99
'/
Alice->Bob: Authentication Request
Bob->Alice: Authentication Response
Bob->L: Log transaction
@enduml
''',
  ),
  SubSample(
    name: 'Declaring participant (order)',
    source: '''
@startuml
participant Last order 30
participant Middle order 20
participant First order 10
@enduml
''',
  ),
  SubSample(
    name: 'Declaring participant on multiline',
    source: '''
@startuml
participant Participant [
=Title
----
""SubTitle""
]
participant Bob
Participant -> Bob
@enduml
''',
  ),
  SubSample(
    name: 'Use non-letters in participants',
    source: '''
@startuml
Alice -> "Bob()" : Hello
"Bob()" -> "This is very\\nlong" as Long
' You can also declare:
' "Bob()" -> Long as "This is very\\nlong"
Long --> "Bob()" : ok
@enduml
''',
  ),
  SubSample(
    name: 'Message to Self',
    source: '''
@startuml
Alice -> Alice: This is a signal to self.\\nIt also demonstrates\\nmultiline \\ntext
@enduml
''',
  ),
  SubSample(
    name: 'Message to Self (reverse)',
    source: '''
@startuml
Alice <- Alice: This is a signal to self.\\nIt also demonstrates\\nmultiline \\ntext
@enduml
''',
  ),
  SubSample(
    name: 'Text alignment (right)',
    source: '''
@startuml
skinparam sequenceMessageAlign right
Bob -> Alice : Request
Alice -> Bob : Response
@enduml
''',
  ),
  SubSample(
    name: 'Text alignment (below arrow)',
    source: '''
@startuml
skinparam responseMessageBelowArrow true
Bob -> Alice : hello
Bob <- Alice : ok
@enduml
''',
  ),
  SubSample(
    name: 'Change Actor style (default)',
    source: '''
@startuml
actor Alice
actor Bob
Alice -> Bob : hello
hide footbox
@enduml
''',
  ),
  SubSample(
    name: 'Change Actor style (awesome)',
    source: '''
@startuml
skinparam actorStyle awesome
actor Alice
actor Bob
Alice -> Bob : hello
hide footbox
@enduml
''',
  ),
  SubSample(
    name: 'Change Actor style (Hollow)',
    source: '''
@startuml
skinparam actorStyle Hollow
actor Alice
actor Bob
Alice -> Bob : hello
hide footbox
@enduml
''',
  ),
  SubSample(
    name: 'Change arrow style',
    source: '''
@startuml
Bob ->x Alice
Bob -> Alice
Bob ->> Alice
Bob -\\ Alice
Bob \\\\- Alice
Bob //-- Alice
Bob ->o Alice
Bob o\\\\-- Alice
Bob <-> Alice
Bob <->o Alice
@enduml
''',
  ),
  SubSample(
    name: 'Change arrow color',
    source: '''
@startuml
Bob -[#red]> Alice : hello
Alice -[#0000FF]->Bob : ok
@enduml
''',
  ),
  SubSample(
    name: 'Message sequence numbering',
    source: '''
@startuml
autonumber
Bob -> Alice : Authentication Request
Bob <- Alice : Authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Message sequence numbering (with start)',
    source: '''
@startuml
autonumber
Bob -> Alice : Authentication Request
Bob <- Alice : Authentication Response
autonumber 15
Bob -> Alice : Another authentication Request
Bob <- Alice : Another authentication Response
autonumber 40 10
Bob -> Alice : Yet another authentication Request
Bob <- Alice : Yet another authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Message sequence numbering (formatted)',
    source: '''
@startuml
autonumber "<b>[000]"
Bob -> Alice : Authentication Request
Bob <- Alice : Authentication Response
autonumber 15 "<b>(<u>##</u>)"
Bob -> Alice : Another authentication Request
Bob <- Alice : Another authentication Response
autonumber 40 10 "<font color=red><b>Message 0  "
Bob -> Alice : Yet another authentication Request
Bob <- Alice : Yet another authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Message sequence numbering (stop/resume)',
    source: '''
@startuml
autonumber 10 10 "<b>[000]"
Bob -> Alice : Authentication Request
Bob <- Alice : Authentication Response
autonumber stop
Bob -> Alice : dummy
autonumber resume "<font color=red><b>Message 0  "
Bob -> Alice : Yet another authentication Request
Bob <- Alice : Yet another authentication Response
autonumber stop
Bob -> Alice : dummy
autonumber resume 1 "<font color=blue><b>Message 0  "
Bob -> Alice : Yet another authentication Request
Bob <- Alice : Yet another authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Message sequence numbering (hierarchical)',
    source: '''
@startuml
autonumber 1.1.1
Alice -> Bob: Authentication request
Bob --> Alice: Response
autonumber inc A
'Now we have 2.1.1
Alice -> Bob: Another authentication request
Bob --> Alice: Response
autonumber inc B
'Now we have 2.2.1
Alice -> Bob: Another authentication request
Bob --> Alice: Response
autonumber inc A
'Now we have 3.1.1
Alice -> Bob: Another authentication request
autonumber inc B
'Now we have 3.2.1
Bob --> Alice: Response
@enduml
''',
  ),
  SubSample(
    name: 'Message sequence numbering (in notes)',
    source: '''
@startuml
autonumber 10
Alice -> Bob
note right
the %autonumber% works everywhere.
Here, its value is ** %autonumber% **
end note
Bob --> Alice: //This is the response %autonumber%//
@enduml
''',
  ),
  SubSample(
    name: 'Page Title, Header and Footer',
    source: '''
@startuml
header Page Header
footer Page %page% of %lastpage%
title Example Title
Alice -> Bob : message 1
Alice -> Bob : message 2
@enduml
''',
  ),
  SubSample(
    name: 'Splitting diagrams (newpage)',
    source: '''
@startuml
Alice -> Bob : message 1
Alice -> Bob : message 2
newpage
Alice -> Bob : message 3
Alice -> Bob : message 4
newpage A title for the\\nlast page
Alice -> Bob : message 5
Alice -> Bob : message 6
@enduml
''',
  ),
  SubSample(
    name: 'Splitting diagrams (with footer)',
    source: '''
@startuml
footer This is %page% of %lastpage%
Alice --> Bob : A1
newpage
Alice --> Bob : A2
newpage
Alice --> Bob : A3
newpage
Alice --> Bob : A4
@enduml
''',
  ),
  SubSample(
    name: 'Splitting diagrams (ignore)',
    source: '''
@startuml
ignore newpage
Alice -> Bob : message 1
Alice -> Bob : message 2
newpage
Alice -> Bob : message 3
Alice -> Bob : message 4
newpage A title for the\\nlast page
Alice -> Bob : message 5
Alice -> Bob : message 6
@enduml
''',
  ),
  SubSample(
    name: 'Grouping message',
    source: '''
@startuml
Alice -> Bob: Authentication Request
alt successful case
Bob -> Alice: Authentication Accepted
else some kind of failure
Bob -> Alice: Authentication Failure
group My own label
Alice -> Log : Log attack start
loop 1000 times
Alice -> Bob: DNS Attack
end
Alice -> Log : Log attack end
end
else Another type of failure
Bob -> Alice: Please repeat
end
@enduml
''',
  ),
  SubSample(
    name: 'Secondary group label',
    source: '''
@startuml
Alice -> Bob: Authentication Request
Bob -> Alice: Authentication Failure
group My own label [My own label 2]
Alice -> Log : Log attack start
loop 1000 times
Alice -> Bob: DNS Attack
end
Alice -> Log : Log attack end
end
@enduml
''',
  ),
  SubSample(
    name: 'Partition across the entire width',
    source: '''
@startuml
participant a
partition p1
b -> c: msg
c --> b: OK
note right: Some right note
end
partition p2
a -> b: msg
note left: Some left note
end
@enduml
''',
  ),
  SubSample(
    name: 'Partition across the entire width (teoz)',
    source: '''
@startuml
!pragma teoz true
participant a
partition p1
b -> c: msg
c --> b: OK
note right: Some right note
end
partition p2
a -> b: msg
note left: Some left note
end
@enduml
''',
  ),
  SubSample(
    name: 'Notes on messages',
    source: '''
@startuml
Alice->Bob : hello
note left: this is a first note
Bob->Alice : ok
note right: this is another note
Bob->Bob : I am thinking
note left
a note can also be defined on several lines
end note
@enduml
''',
  ),
  SubSample(
    name: 'Some other notes',
    source: '''
@startuml
participant Alice
participant Bob
note left of Alice #aqua
This is displayed left of Alice.
end note
note right of Alice: This is displayed right of Alice.
note over Alice: This is displayed over Alice.
note over Alice, Bob #FFAAAA: This is displayed\\n over Bob and Alice.
note over Bob, Alice
This is yet another example of a long note.
end note
@enduml
''',
  ),
  SubSample(
    name: 'Changing notes shape',
    source: '''
@startuml
caller -> server : conReq
hnote over caller : idle
caller <- server : conConf
rnote over server
"r" as rectangle
"h" as hexagon
endrnote
rnote over server
this is on several lines
endrnote
hnote over caller
this is on several lines
endhnote
@enduml
''',
  ),
  SubSample(
    name: 'Note over all participants (across)',
    source: '''
@startuml
Alice->Bob:m1
Bob->Charlie:m2
note over Alice, Charlie: Old method for note over all part. with:\\n ""note over //FirstPart, LastPart//"".
note across: New method with:\\n""note across""
Bob->Alice
hnote across:Note across all part.
@enduml
''',
  ),
  SubSample(
    name: 'Several notes aligned at the same level',
    source: '''
@startuml
note over Alice : initial state of Alice
note over Bob : initial state of Bob
Bob -> Alice : hello
@enduml
''',
  ),
  SubSample(
    name: 'Several notes aligned at the same level (with /)',
    source: '''
@startuml
note over Alice : initial state of Alice
/
note over Bob : initial state of Bob
Bob -> Alice : hello
@enduml
''',
  ),
  SubSample(
    name: 'Creole and HTML',
    source: '''
@startuml
participant Alice
participant "The **Famous** Bob" as Bob
Alice -> Bob : hello --there--
...
Some ~~long delay~~
...
Bob -> Alice : ok
note left
This is **bold**
This is //italics//
This is ""monospaced""
This is --stroked--
This is __underlined__
This is ~~waved~~
end note
Alice -> Bob : A //well formatted// message
note right of Alice
This is <back:cadetblue><size:18>displayed</size></back>
__left of__ Alice.
end note
note left of Bob
<u:red>This</u> is <color #118888>displayed</color>
**<color purple>left of</color> <s:red>Alice</strike> Bob**.
end note
note over Alice, Bob
<w:#FF33FF>This is hosted</w> by <img:https://plantuml.com/sourceforge.jpg>
end note
@enduml
''',
  ),
  SubSample(
    name: 'Divider or separator',
    source: '''
@startuml
== Initialization ==
Alice -> Bob: Authentication Request
Bob --> Alice: Authentication Response
== Repetition ==
Alice -> Bob: Another authentication Request
Alice <-- Bob: another authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Reference',
    source: '''
@startuml
participant Alice
actor Bob
ref over Alice, Bob : init
Alice -> Bob : hello
ref over Bob
This can be on several lines
end ref
@enduml
''',
  ),
  SubSample(
    name: 'Delay',
    source: '''
@startuml
Alice -> Bob: Authentication Request
...
Bob --> Alice: Authentication Response
...5 minutes later...
Bob --> Alice: Good Bye !
@enduml
''',
  ),
  SubSample(
    name: 'Text wrapping',
    source: '''
@startuml
skinparam maxMessageSize 50
participant a
participant b
a -> b :this\\nis\\nmanually\\ndone
a -> b :this is a very long message on several words
@enduml
''',
  ),
  SubSample(
    name: 'Message text spans beyond participants',
    source: '''
@startuml
ParticipantNumber1 -> ParticipantNumber2 : this is a very long message that is very long
ParticipantNumber1 -> ParticipantNumber1 : this is a very long message that is very long
ParticipantNumber2 -> ParticipantNumber3 : foo2
@enduml
''',
  ),
  SubSample(
    name: 'Message text spans (teoz)',
    source: '''
@startuml
!pragma teoz true
!pragma sequenceMessageSpan true
ParticipantNumber1 -> ParticipantNumber2 : this is a very long message that is very long
ParticipantNumber1 -> ParticipantNumber1 : this is a very long message that is very long
ParticipantNumber2 -> ParticipantNumber3 : foo2
@enduml
''',
  ),
  SubSample(
    name: 'Space',
    source: '''
@startuml
Alice -> Bob: message 1
Bob --> Alice: ok
|||
Alice -> Bob: message 2
Bob --> Alice: ok
||45||
Alice -> Bob: message 3
Bob --> Alice: ok
@enduml
''',
  ),
  SubSample(
    name: 'Lifeline Activation and Destruction',
    source: '''
@startuml
participant User
User -> A: DoWork
activate A
A -> B: << createRequest >>
activate B
B -> C: DoWork
activate C
C --> B: WorkDone
destroy C
B --> A: RequestCreated
deactivate B
A -> User: Done
deactivate A
@enduml
''',
  ),
  SubSample(
    name: 'Lifeline Activation (nested colors)',
    source: '''
@startuml
participant User
User -> A: DoWork
activate A #FFBBBB
A -> A: Internal call
activate A #DarkSalmon
A -> B: << createRequest >>
activate B
B --> A: RequestCreated
deactivate B
deactivate A
A -> User: Done
deactivate A
@enduml
''',
  ),
  SubSample(
    name: 'Autoactivate on',
    source: '''
@startuml
autoactivate on
alice -> bob : hello
bob -> bob : self call
bill -> bob #005500 : hello from thread 2
bob -> george ** : create
return done in thread 2
return rc
bob -> george !! : delete
return success
@enduml
''',
  ),
  SubSample(
    name: 'Return',
    source: '''
@startuml
Bob -> Alice : hello
activate Alice
Alice -> Alice : some action
return bye
@enduml
''',
  ),
  SubSample(
    name: 'Participant creation',
    source: '''
@startuml
Bob -> Alice : hello
create Other
Alice -> Other : new
create control String
Alice -> String
note right : You can also put notes!
Alice --> Bob : ok
@enduml
''',
  ),
  SubSample(
    name: 'Shortcut syntax (activation, deactivation, creation)',
    source: '''
@startuml
alice -> bob ++ : hello
bob -> bob ++ : self call
bob -> bib ++ #005500 : hello
bob -> george ** : create
return done
return rc
bob -> george !! : delete
return success
@enduml
''',
  ),
  SubSample(
    name: 'Shortcut syntax (chained --++)',
    source: '''
@startuml
alice -> bob ++ : hello1
bob -> charlie --++ : hello2
charlie --> alice -- : ok
@enduml
''',
  ),
  SubSample(
    name: 'Shortcut syntax (with color)',
    source: '''
@startuml
alice -> bob --++ #gold: hello
bob -> alice --++ #gold: you too
alice -> bob --: step1
alice -> bob : step2
@enduml
''',
  ),
  SubSample(
    name: 'Incoming and outgoing messages',
    source: '''
@startuml
[-> A: DoWork
activate A
A -> A: Internal call
activate A
A ->] : << createRequest >>
A<--] : RequestCreated
deactivate A
[<- A: Done
deactivate A
@enduml
''',
  ),
  SubSample(
    name: 'Incoming and outgoing messages (variants)',
    source: '''
@startuml
participant Alice
participant Bob #lightblue
Alice -> Bob
Bob -> Carol
...
[-> Bob
[o-> Bob
[o->o Bob
[x-> Bob
...
[<- Bob
[x<- Bob
...
Bob ->]
Bob ->o]
Bob o->o]
Bob ->x]
...
Bob <-]
Bob x<-]
@enduml
''',
  ),
  SubSample(
    name: 'Short arrows for incoming and outgoing',
    source: '''
@startuml
?-> Alice : ""?->""\\n**short** to actor1
[-> Alice : ""[->""\\n**from start** to actor1
[-> Bob : ""[->""\\n**from start** to actor2
?-> Bob : ""?->""\\n**short** to actor2
Alice ->] : ""->]""\\nfrom actor1 **to end**
Alice ->? : ""->?""\\n**short** from actor1
Alice -> Bob : ""->"" \\nfrom actor1 to actor2
@enduml
''',
  ),
  SubSample(
    name: 'Anchors and Duration',
    source: '''
@startuml
!pragma teoz true
{start} Alice -> Bob : start doing things during duration
Bob -> Max : something
Max -> Bob : something else
{end} Bob -> Alice : finish
{start} <-> {end} : some time
@enduml
''',
  ),
  SubSample(
    name: 'Stereotypes and Spots',
    source: '''
@startuml
participant "Famous Bob" as Bob << Generated >>
participant Alice << (C,#ADD1B2) Testable >>
Bob->Alice: First message
@enduml
''',
  ),
  SubSample(
    name: 'Stereotypes (no guillemet)',
    source: '''
@startuml
skinparam guillemet false
participant "Famous Bob" as Bob << Generated >>
participant Alice << (C,#ADD1B2) Testable >>
Bob->Alice: First message
@enduml
''',
  ),
  SubSample(
    name: 'Stereotypes (spot only)',
    source: '''
@startuml
participant Bob << (C,#ADD1B2) >>
participant Alice << (C,#ADD1B2) >>
Bob->Alice: First message
@enduml
''',
  ),
  SubSample(
    name: 'Position of the stereotypes (top)',
    source: '''
@startuml
skinparam stereotypePosition top
participant A<<st1>>
participant B<<st2>>
A --> B : stereo test
@enduml
''',
  ),
  SubSample(
    name: 'Position of the stereotypes (bottom)',
    source: '''
@startuml
skinparam stereotypePosition bottom
participant A<<st1>>
participant B<<st2>>
A --> B : stereo test
@enduml
''',
  ),
  SubSample(
    name: 'More information on titles',
    source: '''
@startuml
title __Simple__ **communication** example
Alice -> Bob: Authentication Request
Bob -> Alice: Authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Titles (multi-line)',
    source: '''
@startuml
title __Simple__ communication example\\non several lines
Alice -> Bob: Authentication Request
Bob -> Alice: Authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Titles (HTML)',
    source: '''
@startuml
title <u>Simple</u> communication example on <i>several</i> lines and using <font color=red>html</font>
This is hosted by <img:sourceforge.jpg>
end title
Alice -> Bob: Authentication Request
Bob -> Alice: Authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Participants encompass (box)',
    source: '''
@startuml
box "Internal Service" #LightBlue
participant Bob
participant Alice
end box
participant Other
Bob -> Alice : hello
Alice -> Other : hello
@enduml
''',
  ),
  SubSample(
    name: 'Participants encompass (nested box)',
    source: '''
@startuml
!pragma teoz true
box "Internal Service" #LightBlue
participant Bob
box "Subteam"
participant Alice
participant John
end box
end box
participant Other
Bob -> Alice : hello
Alice -> John : hello
John -> Other: Hello
@enduml
''',
  ),
  SubSample(
    name: 'Removing Foot Boxes',
    source: '''
@startuml
hide footbox
title Foot Box removed
Alice -> Bob: Authentication Request
Bob --> Alice: Authentication Response
@enduml
''',
  ),
  SubSample(
    name: 'Skinparam',
    source: '''
@startuml
skinparam sequenceArrowThickness 2
skinparam roundcorner 20
skinparam maxmessagesize 60
skinparam sequenceParticipant underline
actor User
participant "First Class" as A
participant "Second Class" as B
participant "Last Class" as C
User -> A: DoWork
activate A
A -> B: Create Request
activate B
B -> C: DoWork
activate C
C --> B: WorkDone
destroy C
B --> A: Request Created
deactivate B
A --> User: Done
deactivate A
@enduml
''',
  ),
  SubSample(
    name: 'Skinparam (custom)',
    source: '''
@startuml
skinparam backgroundColor #EEEBDC
!option handwritten true
skinparam sequence {
ArrowColor DeepSkyBlue
ActorBorderColor DeepSkyBlue
LifeLineBorderColor blue
LifeLineBackgroundColor #A9DCDF
ParticipantBorderColor DeepSkyBlue
ParticipantBackgroundColor DodgerBlue
ParticipantFontName Impact
ParticipantFontSize 17
ParticipantFontColor #A9DCDF
ActorBackgroundColor aqua
ActorFontColor DeepSkyBlue
ActorFontSize 17
ActorFontName Aapex
}
actor User
participant "First Class" as A
participant "Second Class" as B
participant "Last Class" as C
User -> A: DoWork
activate A
A -> B: Create Request
activate B
B -> C: DoWork
activate C
C --> B: WorkDone
destroy C
B --> A: Request Created
deactivate B
A --> User: Done
deactivate A
@enduml
''',
  ),
  SubSample(
    name: 'Changing padding',
    source: '''
@startuml
skinparam ParticipantPadding 20
skinparam BoxPadding 10
box "Foo1"
participant Alice1
participant Alice2
end box
box "Foo2"
participant Bob1
participant Bob2
end box
Alice1 -> Bob1 : hello
Alice1 -> Out : out
@enduml
''',
  ),
  SubSample(
    name: 'All arrow types (a -> b)',
    source: '''
@startuml
participant Alice as a
participant Bob   as b
a ->     b : ""->   ""
a ->>    b : ""->>  ""
a -\\     b : ""-\\   ""
a -\\\\    b : ""-\\\\  ""
a -/     b : ""-/   ""
a -//    b : ""-//  ""
a ->x    b : ""->x  ""
a x->    b : ""x->  ""
a o->    b : ""o->  ""
a ->o    b : ""->o  ""
a o->o   b : ""o->o ""
a <->    b : ""<->  ""
a o<->o  b : ""o<->o""
a x<->x  b : ""x<->x""
a ->>o   b : ""->>o ""
a -\\o    b : ""-\\o  ""
a -\\\\o   b : ""-\\\\o ""
a -/o    b : ""-/o  ""
a -//o   b : ""-//o ""
a x->o   b : ""x->o ""
@enduml
''',
  ),
  SubSample(
    name: 'All arrow types (self)',
    source: '''
@startuml
participant Alice as a
participant Bob   as b
a ->     a : ""->   ""
a ->>    a : ""->>  ""
a -\\     a : ""-\\   ""
a -\\\\    a : ""-\\\\  ""
a -/     a : ""-/   ""
a -//    a : ""-//  ""
a ->x    a : ""->x  ""
a x->    a : ""x->  ""
a o->    a : ""o->  ""
a ->o    a : ""->o  ""
a o->o   a : ""o->o ""
a <->    a : ""<->  ""
a o<->o  a : ""o<->o""
a x<->x  a : ""x<->x""
a ->>o   a : ""->>o ""
a -\\o    a : ""-\\o  ""
a -\\\\o   a : ""-\\\\o ""
a -/o    a : ""-/o  ""
a -//o   a : ""-//o ""
a x->o   a : ""x->o ""
@enduml
''',
  ),
  SubSample(
    name: 'All arrow types (incoming from edge)',
    source: '''
@startuml
participant Alice as a
participant Bob   as b
[->      b : ""[->   ""
[->>     b : ""[->>  ""
[-\\      b : ""[-\\   ""
[-\\\\     b : ""[-\\\\  ""
[-/      b : ""[-/   ""
[-//     b : ""[-//  ""
[->x     b : ""[->x  ""
[x->     b : ""[x->  ""
[o->     b : ""[o->  ""
[->o     b : ""[->o  ""
[o->o    b : ""[o->o ""
[<->     b : ""[<->  ""
[o<->o   b : ""[o<->o""
[x<->x   b : ""[x<->x""
[->>o    b : ""[->>o ""
[-\\o     b : ""[-\\o  ""
[-\\\\o    b : ""[-\\\\o ""
[-/o     b : ""[-/o  ""
[-//o    b : ""[-//o ""
[x->o    b : ""[x->o ""
@enduml
''',
  ),
  SubSample(
    name: 'All arrow types (outgoing to edge)',
    source: '''
@startuml
participant Alice as a
participant Bob   as b
a ->]      : ""->]   ""
a ->>]     : ""->>]  ""
a -\\]      : ""-\\]   ""
a -\\\\]     : ""-\\\\]  ""
a -/]      : ""-/]   ""
a -//]     : ""-//]  ""
a ->x]     : ""->x]  ""
a x->]     : ""x->]  ""
a o->]     : ""o->]  ""
a ->o]     : ""->o]  ""
a o->o]    : ""o->o] ""
a <->]     : ""<->]  ""
a o<->o]   : ""o<->o]""
a x<->x]   : ""x<->x]""
a ->>o]    : ""->>o] ""
a -\\o]     : ""-\\o]  ""
a -\\\\o]    : ""-\\\\o] ""
a -/o]     : ""-/o]  ""
a -//o]    : ""-//o] ""
a x->o]    : ""x->o] ""
@enduml
''',
  ),
  SubSample(
    name: 'All arrow types (incoming short)',
    source: '''
@startuml
participant Alice as a
participant Bob   as b
a -> b : //Long long label//
?->      b : ""?->   ""
?->>     b : ""?->>  ""
?-\\      b : ""?-\\   ""
?-\\\\     b : ""?-\\\\  ""
?-/      b : ""?-/   ""
?-//     b : ""?-//  ""
?->x     b : ""?->x  ""
?x->     b : ""?x->  ""
?o->     b : ""?o->  ""
?->o     b : ""?->o  ""
?o->o    b : ""?o->o ""
?<->     b : ""?<->  ""
?o<->o   b : ""?o<->o""
?x<->x   b : ""?x<->x""
?->>o    b : ""?->>o ""
?-\\o     b : ""?-\\o  ""
?-\\\\o    b : ""?-\\\\o ""
?-/o     b : ""?-/o  ""
?-//o    b : ""?-//o ""
?x->o    b : ""?x->o ""
@enduml
''',
  ),
  SubSample(
    name: 'All arrow types (outgoing short)',
    source: '''
@startuml
participant Alice as a
participant Bob   as b
a -> b : //Long long label//
a ->?      : ""->?   ""
a ->>?     : ""->>?  ""
a -\\?      : ""-\\?   ""
a -\\\\?     : ""-\\\\?  ""
a -/?      : ""-/?   ""
a -//?     : ""-//?  ""
a ->x?     : ""->x?  ""
a x->?     : ""x->?  ""
a o->?     : ""o->?  ""
a ->o?     : ""->o?  ""
a o->o?    : ""o->o? ""
a <->?     : ""<->?  ""
a o<->o?   : ""o<->o?""
a x<->x?   : ""x<->x?""
a ->>o?    : ""->>o? ""
a -\\o?     : ""-\\o?  ""
a -\\\\o?    : ""-\\\\o? ""
a -/o?     : ""-/o?  ""
a -//o?    : ""-//o? ""
a x->o?    : ""x->o? ""
@enduml
''',
  ),
  SubSample(
    name: 'Specific SkinParameter (default)',
    source: '''
@startuml
Bob -> Alice : hello
...
Alice -> Bob : ok
@enduml
''',
  ),
  SubSample(
    name: 'Specific SkinParameter (strictuml)',
    source: '''
@startuml
skinparam style strictuml
Bob -> Alice : hello
...
Alice -> Bob : ok
@enduml
''',
  ),
  SubSample(
    name: 'Specific SkinParameter (style block)',
    source: '''
@startuml
<style>
lifeLine {
LineStyle 0
}
delay {
LineStyle 1-4
}
</style>
Bob -> Alice : hello
...
Alice -> Bob : ok
@enduml
''',
  ),
  SubSample(
    name: 'Hide unlinked participant (default)',
    source: '''
@startuml
participant Alice
participant Bob
participant Carol
Alice -> Bob : hello
@enduml
''',
  ),
  SubSample(
    name: 'Hide unlinked participant',
    source: '''
@startuml
hide unlinked
participant Alice
participant Bob
participant Carol
Alice -> Bob : hello
@enduml
''',
  ),
  SubSample(
    name: 'Color a group message',
    source: '''
@startuml
Alice -> Bob: Authentication Request
alt#Gold #LightBlue Successful case
Bob -> Alice: Authentication Accepted
else #Pink Failure
Bob -> Alice: Authentication Rejected
end
@enduml
''',
  ),
  SubSample(
    name: 'Mainframe',
    source: '''
@startuml
mainframe This is a **mainframe**
Alice->Bob : Hello
@enduml
''',
  ),
  SubSample(
    name: 'Slanted or odd arrows',
    source: '''
@startuml
A ->(10) B: text 10
B ->(10) A: text 10
A ->(10) B: text 10
A (10)<- B: text 10
@enduml
''',
  ),
  SubSample(
    name: 'Slanted arrows (with activation)',
    source: '''
@startuml
A ->(40) B++: Rq
B -->(20) A--: Rs
@enduml
''',
  ),
  SubSample(
    name: 'Slanted arrows (with sync)',
    source: '''
@startuml
!pragma teoz true
A ->(50) C: Starts\\nwhen 'B' sends
& B ->(25) C: \\nBut B's message\\n arrives before A's
@enduml
''',
  ),
  SubSample(
    name: 'Slanted arrows (parallel sync notes)',
    source: '''
@startuml
!pragma teoz true
S1 ->(30) S2: msg 1\\n
&
S2 ->(30) S1: msg 2
note left S1: msg\\nS2 to S1
&
note right S2: msg\\nS1 to S2
@enduml
''',
  ),
  SubSample(
    name: 'Parallel messages (teoz)',
    source: '''
@startuml
!pragma teoz true
Alice -> Bob : hello
&
Bob -> Charlie : hi
@enduml
''',
  ),
  SubSample(
    name: 'Solid Lifeline (default)',
    source: '''
@startuml
Alice -> Bob : hello
...
Alice <- Bob : hello
@enduml
''',
  ),
  SubSample(
    name: 'Solid Lifeline (style block)',
    source: '''
@startuml
<style>
lifeLine {
LineStyle 0
}
delay {
LineStyle 1-4
}
</style>
Alice -> Bob : hello
...
Alice <- Bob : hello
@enduml
''',
  ),
];
