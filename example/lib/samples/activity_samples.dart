import 'sample_models.dart';

const activitySubSamples = <SubSample>[
  SubSample(
    name: 'Simple action',
    source: '''
@startuml
:Hello world;
:This is defined on several **lines**;
@enduml
''',
  ),
  SubSample(
    name: 'Simple action list separated by `-`',
    source: '''
@startuml
- Action 1
- Action 2
- Action 3
@enduml
''',
  ),
  SubSample(
    name: 'Simple action list separated by `*` (one level)',
    source: '''
@startuml
* Action 1
* Action 2
* Action 3
@enduml
''',
  ),
  SubSample(
    name: 'Simple action list separated by `*` (several levels)',
    source: '''
@startuml
<style>
element {MinimumWidth 150}
</style>
* Action 1
** Sub-Action 1.1
** Sub-Action 1.2
*** Sub-Action 1.2.1
*** Sub-Action 1.2.2
* Action 2
@enduml
''',
  ),
  SubSample(
    name: 'Start/Stop/End (stop keyword)',
    source: '''
@startuml
start
:Hello world;
:This is defined on several **lines**;
stop
@enduml
''',
  ),
  SubSample(
    name: 'Start/Stop/End (end keyword)',
    source: '''
@startuml
start
:Hello world;
:This is defined on several **lines**;
end
@enduml
''',
  ),
  SubSample(
    name: 'Conditional (if, then, else, endif)',
    source: '''
@startuml
start
if (Graphviz installed?) then (yes)
  :process all\\ndiagrams;
else (no)
  :process only __sequence__ and __activity__ diagrams;
endif
stop
@enduml
''',
  ),
  SubSample(
    name: 'Conditional with `is` syntax',
    source: '''
@startuml
if (color?) is (<color:red>red) then
  :print red;
else
  :print not red;
endif
@enduml
''',
  ),
  SubSample(
    name: 'Conditional with `equals` syntax',
    source: '''
@startuml
if (counter?) equals (5) then
  :print 5;
else
  :print not 5;
endif
@enduml
''',
  ),
  SubSample(
    name: 'Several tests (horizontal mode)',
    source: '''
@startuml
start
if (condition A) then (yes)
  :Text 1;
(no) elseif (condition B) then (yes)
  :Text 2;
stop
(no) elseif (condition C) then (yes)
  :Text 3;
(no) elseif (condition D) then (yes)
  :Text 4;
else (nothing)
  :Text else;
endif
stop
@enduml
''',
  ),
  SubSample(
    name: 'Several tests (vertical mode)',
    source: '''
@startuml
!pragma useVerticalIf on
start
if (condition A) then (yes)
  :Text 1;
elseif (condition B) then (yes)
  :Text 2;
stop
elseif (condition C) then (yes)
  :Text 3;
elseif (condition D) then (yes)
  :Text 4;
else (nothing)
  :Text else;
endif
stop
@enduml
''',
  ),
  SubSample(
    name: 'Switch and case',
    source: '''
@startuml
start
switch (test?)
case ( condition A )
  :Text 1;
case ( condition B )
  :Text 2;
case ( condition C )
  :Text 3;
case ( condition D )
  :Text 4;
case ( condition E )
  :Text 5;
endswitch
stop
@enduml
''',
  ),
  SubSample(
    name: 'Conditional with stop on an action (using stop)',
    source: '''
@startuml
if (condition?) then
  :error;
  stop
endif
#palegreen:action;
@enduml
''',
  ),
  SubSample(
    name: 'Conditional with stop on an action (using kill)',
    source: '''
@startuml
if (condition?) then
  #pink:error;
  kill
endif
#palegreen:action;
@enduml
''',
  ),
  SubSample(
    name: 'Conditional with stop on an action (using detach)',
    source: '''
@startuml
if (condition?) then
  #pink:error;
  detach
endif
#palegreen:action;
@enduml
''',
  ),
  SubSample(
    name: 'Simple repeat loop',
    source: '''
@startuml
start
repeat
  :read data;
  :generate diagrams;
repeat while (more data?) is (yes) not (no)
stop
@enduml
''',
  ),
  SubSample(
    name: 'Repeat loop with repeat action and backward action',
    source: '''
@startuml
start
repeat
  :foo as starting label;
  :read data;
  :generate diagrams;
  backward:This is backward;
repeat while (more data?) is (yes) ->no;
stop
@enduml
''',
  ),
  SubSample(
    name: 'Break on a repeat loop',
    source: '''
@startuml
start
repeat
  :Test something;
  if (Something went wrong?) then (no)
    #palegreen:OK;
    break
  endif
  ->NOK;
  :Alert "Error with long text";
repeat while (Something went wrong with long text?) is (yes) not (no)
->//merged step//;
:Alert "Success";
stop
@enduml
''',
  ),
  SubSample(
    name: 'Goto and Label Processing',
    source: '''
@startuml
title Point two queries to same activity\\nwith `goto`
start
if (Test Question?) then (yes)
'space label only for alignment
label sp_lab0
label sp_lab1
'real label
label lab
  :shared;
else (no)
  if (Second Test Question?) then (yes)
    label sp_lab2
    goto sp_lab1
  else
    :nonShared;
  endif
endif
:merge;
@enduml
''',
  ),
  SubSample(
    name: 'Simple while loop',
    source: '''
@startuml
start
while (data available?)
  :read data;
  :generate diagrams;
endwhile
stop
@enduml
''',
  ),
  SubSample(
    name: 'While loop with labels',
    source: '''
@startuml
while (check filesize ?) is (not empty)
  :read file;
endwhile (empty)
:close file;
@enduml
''',
  ),
  SubSample(
    name: 'While loop with backward action',
    source: '''
@startuml
while (check filesize ?) is (not empty)
  :read file;
  backward:log;
endwhile (empty)
:close file;
@enduml
''',
  ),
  SubSample(
    name: 'Infinite while loop',
    source: '''
@startuml
:Step 1;
if (condition1) then
  while (loop forever)
    :Step 2;
  endwhile
  -[hidden]->
  detach
else
  :end normally;
  stop
endif
@enduml
''',
  ),
  SubSample(
    name: 'Simple `fork`',
    source: '''
@startuml
start
fork
  :action 1;
fork again
  :action 2;
end fork
stop
@enduml
''',
  ),
  SubSample(
    name: '`fork` with end merge',
    source: '''
@startuml
start
fork
  :action 1;
fork again
  :action 2;
end merge
stop
@enduml
''',
  ),
  SubSample(
    name: 'Multiple fork with end merge',
    source: '''
@startuml
start
fork
  :action 1;
fork again
  :action 2;
fork again
  :action 3;
fork again
  :action 4;
end merge
stop
@enduml
''',
  ),
  SubSample(
    name: 'Nested fork with end merge',
    source: '''
@startuml
start
fork
  :action 1;
fork again
  :action 2;
end merge
stop
@enduml
''',
  ),
  SubSample(
    name: 'Label on `end fork` (or UML joinspec with `or`)',
    source: '''
@startuml
start
fork
  :action A;
fork again
  :action B;
end fork {or}
stop
@enduml
''',
  ),
  SubSample(
    name: 'Label on `end fork` (or UML joinspec with `and`)',
    source: '''
@startuml
start
fork
  :action A;
fork again
  :action B;
end fork {and}
stop
@enduml
''',
  ),
  SubSample(
    name: 'Fork with conditional',
    source: '''
@startuml
start
if (multiprocessor?) then (yes)
  fork
    :Treatment 1;
  fork again
    :Treatment 2;
  end fork
else (monoproc)
  :Treatment 1;
  :Treatment 2;
endif
@enduml
''',
  ),
  SubSample(
    name: 'Split',
    source: '''
@startuml
start
split
  :A;
split again
  :B;
split again
  :C;
split again
  :a;
  :b;
end split
:D;
end
@enduml
''',
  ),
  SubSample(
    name: 'Input split (multi-start)',
    source: '''
@startuml
split
-[hidden]-> :A;
split again
-[hidden]-> :B;
split again
-[hidden]-> :C;
end split
:D;
@enduml
''',
  ),
  SubSample(
    name: 'Input split with connector',
    source: '''
@startuml
split
-[hidden]-> :A;
split again
-[hidden]-> :a;
:b;
split again
-[hidden]-> (Z)
end split
:D;
@enduml
''',
  ),
  SubSample(
    name: 'Output split (multi-end)',
    source: '''
@startuml
start
split
  :A;
  kill
split again
  :B;
  detach
split again
  :C;
  kill
end split
@enduml
''',
  ),
  SubSample(
    name: 'Output split with nested elements',
    source: '''
@startuml
start
split
  :A;
  kill
split again
  :b;
  :c;
  detach
split again
  (Z)
  detach
split again
  split
    :d;
  split again
    :e;
    stop
  end split
end split
@enduml
''',
  ),
  SubSample(
    name: 'Notes',
    source: '''
@startuml
start
:foo1;
floating note left: This is a note
:foo2;
note right
This note is on several //lines//
and can contain <b>HTML</b>
====
* Calling the method ""foo()"" is prohibited
end note
stop
@enduml
''',
  ),
  SubSample(
    name: 'Notes on backward activity',
    source: '''
@startuml
start
repeat
  :Enter data;
  :Submit;
  backward :Warning;
  note right: Note
repeat while (Valid?) is (No) not (Yes)
stop
@enduml
''',
  ),
  SubSample(
    name: 'Notes on partition activity',
    source: '''
@startuml
start
partition "**process** HelloWorld" {
  note
  This is my note
  ----
  //Creole test//
  end note
  :Ready;
  :HelloWorld(i); <<output>>
  :Hello-Sent;
}
@enduml
''',
  ),
  SubSample(
    name: 'Colors',
    source: '''
@startuml
start
:starting progress;
#HotPink:reading configuration files
These files should be edited at this point!;
#AAAAAA:ending of the process;
@enduml
''',
  ),
  SubSample(
    name: 'Gradient color',
    source: '''
@startuml
start
partition #red/white testPartition {
  #blue\\green:testActivity;
}
@enduml
''',
  ),
  SubSample(
    name: 'Lines without arrows',
    source: '''
@startuml
skinparam ArrowHeadColor none
start
:Hello world;
:This is on defined on several **lines**;
stop
@enduml
''',
  ),
  SubSample(
    name: 'Lines without arrows (repeat)',
    source: '''
@startuml
skinparam ArrowHeadColor none
start
repeat
  :Enter data;
  :Submit;
  backward :Warning;
repeat while (Valid?) is (No) not (Yes)
stop
@enduml
''',
  ),
  SubSample(
    name: 'Arrows',
    source: '''
@startuml
:foo1;
-> You can put text on arrows;
if (test) then
-[#blue]-> :foo2;
-[#green,dashed]-> The text can also be on several lines and **very** long...;
:foo3;
else
-[#black,dotted]-> :foo4;
endif
-[#gray,bold]-> :foo5;
@enduml
''',
  ),
  SubSample(
    name: 'Simple colored arrow [link]',
    source: '''
@startuml
:a;
link #blue
:b;
@enduml
''',
  ),
  SubSample(
    name: 'Multiple colored arrow',
    source: '''
@startuml
skinparam colorArrowSeparationSpace 1
start
-[#red;#green;#orange;#blue]-> :activity 1;
-[#blue,dashed;dotted]-> :activity 2;
stop
@enduml
''',
  ),
  SubSample(
    name: 'Connector (or Circle)',
    source: '''
@startuml
start
:Some activity;
(A)
detach
(A)
:Other activity;
@enduml
''',
  ),
  SubSample(
    name: 'Color on connector',
    source: '''
@startuml
start
:The connector below wishes he was blue;
#blue:(B)
:This next connector feels that she would be better off green;
#green:(G)
stop
@enduml
''',
  ),
  SubSample(
    name: 'Style on Circle',
    source: '''
@startuml
<style>
circle {
  Backgroundcolor palegreen
  LineColor green
  LineThickness 2
}
</style>
(1)
:a;
(A)
@enduml
''',
  ),
  SubSample(
    name: 'Group',
    source: '''
@startuml
start
group Initialization {
  :read config file;
  :init internal variable;
}
group Running group {
  :wait for user interaction;
  :print information;
}
stop
@enduml
''',
  ),
  SubSample(
    name: 'Partition',
    source: '''
@startuml
start
partition Initialization {
  :read config file;
  :init internal variable;
}
partition Running {
  :wait for user interaction;
  :print information;
}
stop
@enduml
''',
  ),
  SubSample(
    name: 'Partition with color',
    source: '''
@startuml
start
partition #lightGreen "Input Interface" {
  :read config file;
  :init internal variable;
}
partition Running {
  :wait for user interaction;
  :print information;
}
stop
@enduml
''',
  ),
  SubSample(
    name: 'Partition with link',
    source: '''
@startuml
start
partition "[[http://plantuml.com partition_name]]" {
  :read doc. on [[http://plantuml.com plantuml_website]];
  :test diagram;
}
end
@enduml
''',
  ),
  SubSample(
    name: 'Group, Partition, Package, Rectangle or Card',
    source: '''
@startuml
start
group Group {
  :Activity;
}
floating note: Note on Group
partition Partition {
  :Activity;
}
floating note: Note on Partition
package Package {
  :Activity;
}
floating note: Note on Package
rectangle Rectangle {
  :Activity;
}
floating note: Note on Rectangle
card Card {
  :Activity;
}
floating note: Note on Card
end
@enduml
''',
  ),
  SubSample(
    name: 'Swimlanes',
    source: '''
@startuml
|Swimlane1|
start
:foo1;
|#AntiqueWhite|Swimlane2|
:foo2;
:foo3;
|Swimlane1|
:foo4;
|Swimlane2|
:foo5;
stop
@enduml
''',
  ),
  SubSample(
    name: 'Swimlanes with conditional',
    source: '''
@startuml
|#pink|Actor_For_red|
start
if (color?) is (red) then
#pink:\\**action red**;
:foo1;
else (not red)
|#lightgray|Actor_For_no_red|
#lightgray:\\**action not red**;
:foo2;
endif
|Next_Actor|
#lightblue:foo3;
:foo4;
|Final_Actor|
#palegreen:foo5;
stop
@enduml
''',
  ),
  SubSample(
    name: 'Swimlanes with alias',
    source: '''
@startuml
|#palegreen|f| fisherman
|c| cook
|#gold|e| eater
|f|
start
:go fish;
|c|
:fry fish;
|e|
:eat fish;
stop
@enduml
''',
  ),
  SubSample(
    name: 'Detach',
    source: '''
@startuml
:start;
fork
  :foo1;
  :foo2;
fork again
  :foo3;
  detach
endfork
if (foo4) then
  :foo5;
  detach
endif
:foo6;
detach
:foo7;
stop
@enduml
''',
  ),
  SubSample(
    name: 'Kill',
    source: '''
@startuml
:start;
fork
  :foo1;
  :foo2;
fork again
  :foo3;
  kill
endfork
if (foo4) then
  :foo5;
  kill
endif
:foo6;
kill
:foo7;
stop
@enduml
''',
  ),
  SubSample(
    name: 'Emoji as action (with `icon` stereotype)',
    source: '''
@startuml
while (<:cloud_with_rain:>)
:<:umbrella:>; <<icon>>
endwhile
:<:closed_umbrella:>; <<icon>>
@enduml
''',
  ),
  SubSample(
    name: 'SDL using stereotype',
    source: '''
@startuml
start
:SDL Shape;
:input; <<input>>
:output; <<output>>
:procedure; <<procedure>>
:load; <<load>>
:save; <<save>>
:continuous; <<continuous>>
:task; <<task>>
end
@enduml
''',
  ),
  SubSample(
    name: 'SDL complex example',
    source: '''
@startuml
:Ready;
:next(o); <<procedure>>
:Receiving;
split
:nak(i); <<input>>
:ack(o); <<output>>
split again
:ack(i); <<input>>
:next(o) on several lines; <<procedure>>
:i := i + 1; <<task>>
:ack(o); <<output>>
split again
:err(i); <<input>>
:nak(o); <<output>>
split again
:foo; <<save>>
split again
:bar; <<load>>
split again
:i > 5; <<continuous>>
stop
end split
:finish;
@enduml
''',
  ),
  SubSample(
    name: 'UML Shape Example using Stereotype',
    source: '''
@startuml
:action;
:object; <<object>>
:ObjectNode typed by signal; <<objectSignal>>
:AcceptEventAction without TimeEvent trigger; <<acceptEvent>>
:SendSignalAction; <<sendSignal>>
:SendObjectAction with signal type; <<sendSignal>>
:Trigger; <<trigger>>
:\\t\\t\\t\\t\\t\\tAcceptEventAction \\t\\t\\t\\t\\t\\twith TimeEvent trigger; <<timeEvent>>
:an action;
@enduml
''',
  ),
  SubSample(
    name: 'Complete example',
    source: '''
@startuml
start
:ClickServlet.handleRequest();
:new page;
if (Page.onSecurityCheck) then (true)
  :Page.onInit();
  if (isForward?) then (no)
    :Process controls;
    if (continue processing?) then (no)
      stop
    endif
    if (isPost?) then (yes)
      :Page.onPost();
    else (no)
      :Page.onGet();
    endif
    :Page.onRender();
  endif
else (false)
endif
if (do redirect?) then (yes)
  :redirect process;
else
  if (do forward?) then (yes)
    :Forward request;
  else (no)
    :Render page template;
  endif
endif
stop
@enduml
''',
  ),
  SubSample(
    name: 'Condition Style (inside)',
    source: '''
@startuml
skinparam conditionStyle inside
start
repeat
  :act1;
  :act2;
repeatwhile (<b>end)
:act3;
@enduml
''',
  ),
  SubSample(
    name: 'Condition Style (diamond)',
    source: '''
@startuml
skinparam conditionStyle diamond
start
repeat
  :act1;
  :act2;
repeatwhile (<b>end)
:act3;
@enduml
''',
  ),
  SubSample(
    name: 'Condition Style (InsideDiamond)',
    source: '''
@startuml
skinparam conditionStyle InsideDiamond
start
repeat
  :act1;
  :act2;
repeatwhile (<b>end)
:act3;
@enduml
''',
  ),
  SubSample(
    name: 'Condition End Style (diamond, one branch)',
    source: '''
@startuml
skinparam ConditionEndStyle diamond
:A;
if (decision) then (yes)
  :B1;
else (no)
endif
:C;
@enduml
''',
  ),
  SubSample(
    name: 'Condition End Style (diamond, two branches)',
    source: '''
@startuml
skinparam ConditionEndStyle diamond
:A;
if (decision) then (yes)
  :B1;
else (no)
  :B2;
endif
:C;
@enduml
''',
  ),
  SubSample(
    name: 'Condition End Style (hline, one branch)',
    source: '''
@startuml
skinparam ConditionEndStyle hline
:A;
if (decision) then (yes)
  :B1;
else (no)
endif
:C;
@enduml
''',
  ),
  SubSample(
    name: 'Condition End Style (hline, two branches)',
    source: '''
@startuml
skinparam ConditionEndStyle hline
:A;
if (decision) then (yes)
  :B1;
else (no)
  :B2;
endif
:C;
@enduml
''',
  ),
  SubSample(
    name: 'Using (global) style - Without style',
    source: '''
@startuml
start
:init;
-> test of color;
if (color?) is (<color:red>red) then
  :print red;
else
  :print not red;
  note right: no color
endif
partition End {
  :end;
}
-> this is the end;
end
@enduml
''',
  ),
  SubSample(
    name: 'Using (global) style - With style',
    source: '''
@startuml
<style>
activityDiagram {
  BackgroundColor #33668E
  BorderColor #33668E
  FontColor #888
  FontName arial
  diamond {
    BackgroundColor #ccf
    LineColor #00FF00
    FontColor green
    FontName arial
    FontSize 15
  }
  arrow {
    FontColor gold
    FontName arial
    FontSize 15
  }
  partition {
    LineColor red
    FontColor green
    RoundCorner 10
    BackgroundColor PeachPuff
  }
  note {
    FontColor Blue
    LineColor Navy
    BackgroundColor #ccf
  }
}
document {
  BackgroundColor transparent
}
</style>
start
:init;
-> test of color;
if (color?) is (<color:red>red) then
  :print red;
else
  :print not red;
  note right: no color
endif
partition End {
  :end;
}
-> this is the end;
end
@enduml
''',
  ),
  SubSample(
    name: 'Creole on Activity',
    source: '''
@startuml
:Creole: wave: ~~wave~~ bold: **bold** italics: //italics// monospaced: ""monospaced"" stricken-out: --stricken-out-- underlined: __underlined__ not-underlined: ~__not underlined__ wave-underlined: ~~wave-underlined~~;
:HTML Creole: bold: <b>bold italics: <i>italics monospaced: <font:monospaced>monospaced stroked: <s>stroked underlined: <u>underlined waved: <w>waved green-stroked: <s:green>stroked red-underlined: <u:red>underlined blue-waved: <w:#0000FF>waved Blue: <color:blue>Blue Orange: <back:orange>Orange background big: <size:20>big;
:Graphic: OpenIconic: account-login <&account-login> Unicode: This is <U+221E> long Emoji: <:calendar:> Calendar Image: <img:https://plantuml.com/logo3.png>;
@enduml
''',
  ),
];
