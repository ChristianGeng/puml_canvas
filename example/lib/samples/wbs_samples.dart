import 'sample_models.dart';

const wbsSubSamples = <SubSample>[
  SubSample(
    name: 'OrgMode syntax',
    source: r'''
@startwbs
* Business Process Modelling WBS
** Launch the project
*** Complete Stakeholder Research
*** Initial Implementation Plan
** Design phase
*** Model of AsIs Processes Completed
**** Model of AsIs Processes Completed1
**** Model of AsIs Processes Completed2
*** Measure AsIs performance metrics
*** Identify Quick Wins
** Complete innovate phase
@endwbs
''',
  ),
  SubSample(
    name: 'Change direction',
    source: r'''
@startwbs
* Business Process Modelling WBS
** Launch the project
*** Complete Stakeholder Research
*** Initial Implementation Plan
** Design phase
*** Model of AsIs Processes Completed
****< Model of AsIs Processes Completed1
****> Model of AsIs Processes Completed2
***< Measure AsIs performance metrics
***< Identify Quick Wins
@endwbs
''',
  ),
  SubSample(
    name: 'Arithmetic notation',
    source: r'''
@startwbs
+ New Job
++ Decide on Job Requirements
+++ Identity gaps
+++ Review JDs
++++ Sign-Up for courses
++++ Volunteer
++++ Reading
++- Checklist
+++- Responsibilities
+++- Location
++ CV Upload Done
+++ CV Updated
++++ Spelling & Grammar
++++ Check dates
---- Skills
+++ Recruitment sites chosen
@endwbs
''',
  ),
  SubSample(
    name: 'Multilines',
    source: r'''
@startwbs
* <&flag> Debian
** <&globe> Ubuntu
***:Linux Mint
Open Source;
*** Kubuntu
*** ...
@endwbs
''',
  ),
  SubSample(
    name: 'Removing box - Several boxless node (Arithmetic notation)',
    source: r'''
@startwbs
+ Project
++ Part One
+++ Task 1.1
--- LeftTask 1.2
+++ Task 1.3
++ Part Two
+++ Task 2.1
+++ Task 2.2
----_ Task 2.2.1 To the left boxless
----_ Task 2.2.2 To the Left boxless
++++_ Task 2.2.3 To the right boxless
@endwbs
''',
  ),
  SubSample(
    name: 'Removing box - All boxless node (Arithmetic notation)',
    source: r'''
@startwbs
+_ Project
++_ Part One
+++_ Task 1.1
---_ LeftTask 1.2
+++_ Task 1.3
++_ Part Two
+++_ Task 2.1
+++_ Task 2.2
++++_ Task 2.2.1 To the left boxless
++++_ Task 2.2.2 To the Left boxless
++++_ Task 2.2.3 To the right boxless
@endwbs
''',
  ),
  SubSample(
    name: 'Removing box - Several boxless node (OrgMode syntax)',
    source: r'''
@startwbs
* World
** America
***_ Canada
***_ Mexico
***_ USA
** Europe
***_ England
***_ Germany
***_ Spain
@endwbs
''',
  ),
  SubSample(
    name: 'Removing box - All boxless node (OrgMode syntax)',
    source: r'''
@startwbs
*_ World
**_ America
***_ Canada
***_ Mexico
***_ USA
**_ Europe
***_ England
***_ Germany
***_ Spain
@endwbs
''',
  ),
  SubSample(
    name: 'Removing box - Skipping a layer',
    source: r'''
@startwbs
* Director
** Team Lead 1
*** Engineer 1
*** Engineer 2
** Team Lead 2
*** Engineer 3
*** Engineer 4
**_
*** Engineer 5 (reporting to Director)
*** Engineer 6 (reporting to Director)
@endwbs
''',
  ),
  SubSample(
    name: 'Colors - inline color (OrgMode syntax)',
    source: r'''
@startwbs
*[#SkyBlue] this is the partner workpackage
**[#pink] this is my workpackage
** this is another workpackage
@endwbs
''',
  ),
  SubSample(
    name: 'Colors - inline color (Arithmetic notation)',
    source: r'''
@startwbs
+[#SkyBlue] this is the partner workpackage
++[#pink] this is my workpackage
++ this is another workpackage
@endwbs
''',
  ),
  SubSample(
    name: 'Colors - style color (OrgMode syntax)',
    source: r'''
@startwbs
<style>
wbsDiagram {
  .pink { BackgroundColor pink }
  .your_style_name { BackgroundColor SkyBlue }
}
</style>
* this is the partner workpackage <<your_style_name>>
** this is my workpackage <<pink>>
**:This is on
multiple lines; <<pink>>
** this is another workpackage
@endwbs
''',
  ),
  SubSample(
    name: 'Colors - style color (Arithmetic notation)',
    source: r'''
@startwbs
<style>
wbsDiagram {
  .pink { BackgroundColor pink }
  .your_style_name { BackgroundColor SkyBlue }
}
</style>
+ this is the partner workpackage <<your_style_name>>
++ this is my workpackage <<pink>>
++:This is on
multiple lines; <<pink>>
++ this is another workpackage
@endwbs
''',
  ),
  SubSample(
    name: 'Using style',
    source: r'''
@startwbs
<style>
wbsDiagram {
  Linecolor black
  arrow {
    LineColor green
  }
  :depth(0) {
    BackgroundColor White
    RoundCorner 10
    LineColor red
  }
  arrow {
    :depth(2) {
      LineColor blue
      LineStyle 4
      LineThickness .5
    }
  }
  node {
    :depth(2) {
      LineStyle 2
      LineThickness 2.5
    }
  }
  boxless {
    FontColor darkgreen
  }
}
</style>
* World
** America
*** Canada
*** Mexico
**** Chihuahua
*** USA
**** Texas
***< New York
** Europe
***_ England
***_ Germany
***_ Spain
@endwbs
''',
  ),
  SubSample(
    name: 'Word Wrap',
    source: r'''
@startwbs
<style>
node {
  Padding 12
  Margin 3
  HorizontalAlignment center
  LineColor blue
  LineThickness 3.0
  BackgroundColor gold
  RoundCorner 40
  MaximumWidth 100
}
rootNode {
  LineStyle 8.0;3.0
  LineColor red
  BackgroundColor white
  LineThickness 1.0
  RoundCorner 0
  Shadowing 0.0
}
leafNode {
  LineColor gold
  RoundCorner 0
  Padding 3
}
arrow {
  LineStyle 4
  LineThickness 0.5
  LineColor green
}
</style>
* Hi =)
** sometimes i have node in wich i want to write a long text
*** this results in really huge diagram
**** of course, i can explicit split with a\nnew line
**** but it could be cool if PlantUML was able to split long lines, maybe with an option who specify the maximum width of a node
@endwbs
''',
  ),
  SubSample(
    name: "Add arrows between WBS elements - Using alias with 'as'",
    source: r'''
@startwbs
<style>
.foo {
  LineColor #00FF00;
}
</style>
* Test
** A topic
*** "common" as c1
*** "common2" as c2
** "Another topic" as t2
t2 -> c1 <<foo>>
t2 ..> c2 #blue
@endwbs
''',
  ),
  SubSample(
    name: 'Add arrows between WBS elements - Using alias in parentheses',
    source: r'''
@startwbs
* Test
**(b) A topic
***(c1) common
**(t2) Another topic
t2 --> c1
b -> t2 #blue
@endwbs
''',
  ),
  SubSample(
    name: 'Creole on WBS diagram',
    source: r'''
@startwbs
* Creole on WBS
**:==Creole
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
;
**:
<b>HTML Creole
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
;
**:==Creole line
You can have horizontal line
----
Or double line
====
Or strong line
____
Or dotted line
..My title..
Or dotted title //and title... //
==Title==
Or double-line title
--Another title--
Or single-line title
Enjoy!;
**:==Creole list item
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
;
@endwbs
''',
  ),
];
