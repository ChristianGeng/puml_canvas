import 'sample_models.dart';

const wireframeSubSamples = <SubSample>[
  SubSample(
    name: 'Basic widgets',
    source: '''
@startsalt
{
Just plain text
[This is my button]
() Unchecked radio
(X) Checked radio
[] Unchecked box
[X] Checked box
"Enter text here "
^This is a droplist^
}
@endsalt
''',
  ),
  SubSample(
    name: 'Text area',
    source: '''
@startsalt
{+
This is a long text in a textarea
.
"  "
}
@endsalt
''',
  ),
  SubSample(
    name: 'Text area with vertical scrollbar',
    source: '''
@startsalt
{SI
This is a long text in a textarea
.
"  "
}
@endsalt
''',
  ),
  SubSample(
    name: 'Text area with horizontal scrollbar',
    source: '''
@startsalt
{S-
This is a long text in a textarea
.
"  "
}
@endsalt
''',
  ),
  SubSample(
    name: 'Open, close droplist',
    source: '''
@startsalt
{
^This is a closed droplist^ | ^This is an open droplist^^
item 1^^
item 2^
|
^This is another open droplist^
item 1^
item 2^
}
@endsalt
''',
  ),
  SubSample(
    name: 'Using grid with default layout',
    source: '''
@startsalt
{
Login | "MyName "
Password | "****  "
[Cancel] | [ OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Using grid with external lines only',
    source: '''
@startsalt
{+
Login | "MyName "
Password | "****  "
[Cancel] | [ OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Group box',
    source: '''
@startsalt
{^"My group box"
Login | "MyName "
Password | "****  "
[Cancel] | [ OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Using separator',
    source: '''
@startsalt
{
Text1
..
"Some field"
==
Note on usage
~~
Another text
--
[Ok]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Tree widget',
    source: '''
@startsalt
{
{T
+ World
++ America
+++ Canada
+++ USA
++++ New York
++++ Boston
+++ Mexico
++ Europe
+++ Italy
+++ Germany
++++ Berlin
++ Africa
}
}
@endsalt
''',
  ),
  SubSample(
    name: 'Tree table',
    source: '''
@startsalt
{
{T
+Region | Population | Age
+ World | 7.13 billion | 30
++ America | 964 million | 30
+++ Canada | 35 million | 30
+++ USA | 319 million | 30
++++ NYC | 8 million | 30
++++ Boston | 617 thousand | 30
+++ Mexico | 117 million | 30
++ Europe | 601 million | 30
+++ Italy | 61 million | 30
+++ Germany | 82 million | 30
++++ Berlin | 3 million | 30
++ Africa | 1 billion | 30
}
}
@endsalt
''',
  ),
  SubSample(
    name: 'Tree table with vertical lines',
    source: '''
@startsalt
{
..
==
with T!
{T!
+Region | Population | Age
+ World | 7.13 billion | 30
++ America | 964 million | 30
}
..
==
with T-
{T-
+Region | Population | Age
+ World | 7.13 billion | 30
++ America | 964 million | 30
}
..
==
with T+
{T+
+Region | Population | Age
+ World | 7.13 billion | 30
++ America | 964 million | 30
}
..
==
with T#
{T#
+Region | Population | Age
+ World | 7.13 billion | 30
++ America | 964 million | 30
}
..
}
@endsalt
''',
  ),
  SubSample(
    name: 'Enclosing brackets',
    source: '''
@startsalt
{
Name | " "
Modifiers: | {
(X) public
() default
() private
() protected
[] abstract
[] final
[] static
}
Superclass: | {
"java.lang.Object "
| [Browse...]
}
}
@endsalt
''',
  ),
  SubSample(
    name: 'Adding tabs',
    source: '''
@startsalt
{+
{/
<b>General | Fullscreen | Behavior | Saving
}
{
{
Open image in: | ^Smart Mode^
}
[X] Smooth images when zoomed
[X] Confirm image deletion
[ ] Show hidden images
}
[Close]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Adding tabs vertically oriented',
    source: '''
@startsalt
{+
{/
<b>General
Fullscreen
Behavior
Saving
}
| {
{
Open image in: | ^Smart Mode^
}
[X] Smooth images when zoomed
[X] Confirm image deletion
[ ] Show hidden images
[Close]
}
}
@endsalt
''',
  ),
  SubSample(
    name: 'Using menu',
    source: '''
@startsalt
{+
{*
File | Edit | Source | Refactor
}
{/
General | Fullscreen | Behavior | Saving
}
{
{
Open image in: | ^Smart Mode^
}
[X] Smooth images when zoomed
[X] Confirm image deletion
[ ] Show hidden images
}
[Close]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Using menu with open submenu',
    source: '''
@startsalt
{+
{*
File | Edit | Source | Refactor
Refactor | New | Open File | - | Close | Close All
}
{/
General | Fullscreen | Behavior | Saving
}
{
{
Open image in: | ^Smart Mode^
}
[X] Smooth images when zoomed
[X] Confirm image deletion
[ ] Show hidden images
}
[Close]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Using menu with open droplist',
    source: '''
@startsalt
{+
{*
File | Edit | Source | Refactor
}
{/
General | Fullscreen | Behavior | Saving
}
{
{
Open image in: | ^Smart Mode^^Normal Mode^
}
[X] Smooth images when zoomed
[X] Confirm image deletion
[ ] Show hidden images
}
[Close]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Advanced table with cell span',
    source: '''
@startsalt
{#
. | Column 2 | Column 3
Row header 1 | value 1 | value 2
Row header 2 | A long cell | *
}
@endsalt
''',
  ),
  SubSample(
    name: 'Scroll Bars horizontal and vertical',
    source: '''
@startsalt
{S
Message
.
.
.
.
}
@endsalt
''',
  ),
  SubSample(
    name: 'Scroll Bars vertical only',
    source: '''
@startsalt
{SI
Message
.
.
.
.
}
@endsalt
''',
  ),
  SubSample(
    name: 'Scroll Bars horizontal only',
    source: '''
@startsalt
{S-
Message
.
.
.
.
}
@endsalt
''',
  ),
  SubSample(
    name: 'Colors',
    source: '''
@startsalt
{
<color:Blue>Just plain text
[This is my default button]
[<color:green>This is my green button]
[<color:#9a9a9a>This is my disabled button]
[] <color:red>Unchecked box
[X] <color:green>Checked box
"Enter text here "
^This is a droplist^
^<color:#9a9a9a>This is a disabled droplist^
^<color:red>This is a red droplist^
}
@endsalt
''',
  ),
  SubSample(
    name: 'Creole on Salt',
    source: '''
@startsalt
{
{^==Creole
This is **bold**
This is //italics//
This is ""monospaced""
This is --stricken-out--
This is __underlined__
This is ~~wave-underlined~~
--test Unicode and icons--
This is <U+221E> long
This is a <&code> icon
Use image : <img:https://plantuml.com/logo3.png>
}|
{^<b>HTML Creole
This is <b>bold</b>
This is <i>italics</i>
This is <font:monospaced>monospaced</font>
This is <s>stroked</s>
This is <u>underlined</u>
This is <w>waved</w>
This is <s:green>stroked</s>
This is <u:red>underlined</u>
This is <w:#0000FF>waved</w>
-- other examples --
This is <color:blue>Blue</color>
This is <back:orange>Orange background</back>
This is <size:20>big</size>
}|
{^Creole line
You can have horizontal line
----
Or double line
====
Or strong line
____
Or dotted line
..My title..
Or dotted title
//and title... //
==Title==
Or double-line title
--Another title--
Or single-line title
Enjoy!
}|
{^Creole list item
**test list 1**
* Bullet list
* Second item
** Sub item
*** Sub sub item
* Third item
----
**test list 2**
# Numbered list
# Second item
## Sub item
## Another sub item
# Third item
}|
{^Mix on salt
==<color:Blue>Just plain text
[This is my default button]
[<b><color:green>This is my green button]
[ ---<color:#9a9a9a>This is my disabled button-- ]
[]
<size:20><color:red>Unchecked box
[X] <color:green>Checked box
"//Enter text here// "
^This is a droplist^
^<color:#9a9a9a>This is a disabled droplist^
^<b><color:red>This is a red droplist^
}
}
@endsalt
''',
  ),
  SubSample(
    name: 'Pseudo sprite',
    source: '''
@startsalt
{
[X] checkbox|[] checkbox
() radio | (X) radio
This is a text|[This is my button]|This is another text
"A field"|"Another long Field"|[A button]
<<folder
..............
.XXXXX......
.X...X......
.XXXXXXXXXX.
.X........X.
.X........X.
.X........X.
.X........X.
.XXXXXXXXXX.
..............
>>|<color:blue>other folder|<<folder>>
^Droplist^
}
@endsalt
''',
  ),
  SubSample(
    name: 'OpenIconic',
    source: '''
@startsalt
{
Login<&person> | "MyName "
Password<&key> | "****  "
[Cancel <&circle-x>] | [OK <&account-login>]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Add title, header, footer, caption or legend',
    source: '''
@startsalt
title My title
header some header
footer some footer
caption This is caption
legend
The legend
end legend
{+
Login | "MyName "
Password | "****  "
[Cancel] | [ OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Zoom without scale (default)',
    source: '''
@startsalt
{
<&person> Login | "MyName "
<&key> Password | "****  "
[<&circle-x> Cancel ] | [ <&account-login> OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Scale',
    source: '''
@startsalt
scale 2
{
<&person> Login | "MyName "
<&key> Password | "****  "
[<&circle-x> Cancel ] | [ <&account-login> OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'DPI',
    source: '''
@startsalt
skinparam dpi 200
{
<&person> Login | "MyName "
<&key> Password | "****  "
[<&circle-x> Cancel ] | [ <&account-login> OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Skinparam with background color',
    source: '''
@startsalt
skinparam Backgroundcolor palegreen
{+
Login | "MyName "
Password | "****  "
[Cancel] | [ OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Skinparam with handwritten option',
    source: '''
@startsalt
!option handwritten true
{+
Login | "MyName "
Password | "****  "
[Cancel] | [ OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Skinparam with font name',
    source: '''
@startsalt
skinparam defaultFontName monospaced
{+
Login | "MyName "
Password | "****  "
[Cancel] | [ OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Style with background color',
    source: '''
@startsalt
<style>
saltDiagram {
BackgroundColor palegreen
}
</style>
{+
Login | "MyName "
Password | "****  "
[Cancel] | [ OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Style with font properties',
    source: '''
@startsalt
<style>
saltDiagram {
Fontname Monospaced
FontSize 10
FontStyle italic
LineThickness 0.5
LineColor red
}
</style>
{+
Login | "MyName "
Password | "****  "
[Cancel] | [ OK ]
}
@endsalt
''',
  ),
  SubSample(
    name: 'Include Salt on activity diagram',
    source: '''
@startuml
(*) --> " {{salt
{+
<b>an example
choose one option
()one
()two
[ok]
}
}} " as choose

choose -right-> " {{salt
{+
<b>please wait
operation in progress <&clock>
[cancel]
}
}} " as wait

wait -right-> " {{salt
{+
<b>success
congratulations!
[ok]
}
}} " as success

wait -down-> " {{salt
{+
<b>error
failed, sorry
[ok]
}
}} "

@enduml
''',
  ),
  SubSample(
    name: 'Include Salt on activity diagram with macro',
    source: '''
@startuml
!unquoted procedure SALT(\$x)
"{{salt %invoke_procedure("_"+\$x) }}" as \$x
!endprocedure

!procedure _choose()
{+
<b>an example
choose one option
()one
()two
[ok]
}
!endprocedure

!procedure _wait()
{+
<b>please wait
operation in progress <&clock>
[cancel]
}
!endprocedure

!procedure _success()
{+
<b>success
congratulations!
[ok]
}
!endprocedure

!procedure _error()
{+
<b>error
failed, sorry
[ok]
}
!endprocedure

(*) --> SALT(choose) -right-> SALT(wait)
wait -right-> SALT(success)
wait -down-> SALT(error)

@enduml
''',
  ),
  SubSample(
    name: 'Include salt on while condition of activity diagram',
    source: '''
@startuml
start
while (\\n{{salt\\n{+\\nPassword | "****  "\\n[Cancel] | [ OK ]}\\n}}\\n) is (Incorrect)
:log attempt;
:attempt_count++;
if (attempt_count > 4) then (yes)
:increase delay timer;
:wait for timer to expire;
else (no)
endif
endwhile (correct)
:log request;
:disable service;

@enduml
''',
  ),
  SubSample(
    name: 'Include salt on repeat while condition of activity diagram',
    source: '''
@startuml
start
repeat
:read data;
:generate diagrams;
repeat while (\\n{{salt\\n{^"Next step"\\n Do you want to continue? \\n[Yes]|[No]\\n}\\n}}\\n)
stop

@enduml
''',
  ),
];
