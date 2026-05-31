import 'sample_models.dart';

const mindMapSubSamples = <SubSample>[
  SubSample(
    name: 'OrgMode syntax',
    source: r'''
@startmindmap
* Debian
** Ubuntu
*** Linux Mint
*** Kubuntu
*** Lubuntu
*** KDE Neon
** LMDE
** SolydXK
** SteamOS
** Raspbian with a very long name
*** <s>Raspmbc</s> => OSMC
*** <s>Raspyfi</s> => Volumio
@endmindmap
''',
  ),
  SubSample(
    name: 'Markdown Header',
    source: r'''
@startmindmap
# root node
## some first level node
### second level node
### another second level node
## another first level node
@endmindmap
''',
  ),
  SubSample(
    name: 'Markdown indented list',
    source: r'''
@startmindmap
* root node
* some first level node
* second level node
* another second level node
* another first level node
@endmindmap
''',
  ),
  SubSample(
    name: 'Arithmetic notation',
    source: r'''
@startmindmap
+ OS
++ Ubuntu
+++ Linux Mint
+++ Kubuntu
+++ Lubuntu
+++ KDE Neon
++ LMDE
++ SolydXK
++ SteamOS
++ Raspbian
-- Windows 95
-- Windows 98
-- Windows NT
--- Windows 8
--- Windows 10
@endmindmap
''',
  ),
  SubSample(
    name: 'Multilines (Example 1)',
    source: r'''
@startmindmap
* Class Templates
**:Example 1
<code>
template <typename T>
class cname{
void f1()<U+003B>
...
}
</code>
;
**:Example 2
<code>
other template <typename T>
class cname{
...
</code>
;
@endmindmap
''',
  ),
  SubSample(
    name: 'Multilines (Example 2)',
    source: r'''
@startmindmap
+ root
**:right_1.1
right_1.2;
++ right_2
left side
-- left_1
-- left_2
**:left_3.1
left_3.2;
@endmindmap
''',
  ),
  SubSample(
    name: 'Multiroot Mindmap',
    source: r'''
@startmindmap
* Root 1
** Foo
** Bar
* Root 2
** Lorem
** Ipsum
@endmindmap
''',
  ),
  SubSample(
    name: 'Colors - With inline color (OrgMode syntax)',
    source: r'''
@startmindmap
*[#Orange] Colors
**[#lightgreen] Green
**[#FFBBCC] Rose
**[#lightblue] Blue
@endmindmap
''',
  ),
  SubSample(
    name: 'Colors - With inline color (Arithmetic notation syntax)',
    source: r'''
@startmindmap
+[#Orange] Colors
++[#lightgreen] Green
++[#FFBBCC] Rose
--[#lightblue] Blue
@endmindmap
''',
  ),
  SubSample(
    name: 'Colors - With inline color (Markdown syntax)',
    source: r'''
@startmindmap
*[#Orange] root node
*[#lightgreen] some first level node
*[#FFBBCC] second level node
*[#lightblue] another second level node
*[#lightgreen] another first level node
@endmindmap
''',
  ),
  SubSample(
    name: 'Colors - With style color (OrgMode syntax)',
    source: r'''
@startmindmap
<style>
mindmapDiagram {
.green {
BackgroundColor lightgreen
}
.rose {
BackgroundColor #FFBBCC
}
.your_style_name {
BackgroundColor lightblue
}
}
</style>
* Colors
** Green <<green>>
** Rose <<rose>>
** Blue <<your_style_name>>
@endmindmap
''',
  ),
  SubSample(
    name: 'Colors - With style color (Arithmetic notation syntax)',
    source: r'''
@startmindmap
<style>
mindmapDiagram {
.green {
BackgroundColor lightgreen
}
.rose {
BackgroundColor #FFBBCC
}
.your_style_name {
BackgroundColor lightblue
}
}
</style>
+ Colors
++ Green <<green>>
++ Rose <<rose>>
-- Blue <<your_style_name>>
@endmindmap
''',
  ),
  SubSample(
    name: 'Colors - With style color (Markdown syntax)',
    source: r'''
@startmindmap
<style>
mindmapDiagram {
.green {
BackgroundColor lightgreen
}
.rose {
BackgroundColor #FFBBCC
}
.your_style_name {
BackgroundColor lightblue
}
}
</style>
* root node
* some first level node <<green>>
* second level node <<rose>>
* another second level node <<your_style_name>>
* another first level node <<green>>
@endmindmap
''',
  ),
  SubSample(
    name: 'Colors - Apply style to a branch',
    source: r'''
@startmindmap
<style>
mindmapDiagram {
.myStyle * {
BackgroundColor lightgreen
}
}
</style>
+ root
++ b1 <<myStyle>>
+++ b11
+++ b12
++ b2
@endmindmap
''',
  ),
  SubSample(
    name: 'Removing box (Example 1)',
    source: r'''
@startmindmap
* root node
** some first level node
***_ second level node
***_ another second level node
***_ foo
***_ bar
***_ foobar
** another first level node
@endmindmap
''',
  ),
  SubSample(
    name: 'Removing box (Example 2)',
    source: r'''
@startmindmap
*_ root node
**_ some first level node
***_ second level node
***_ another second level node
***_ foo
***_ bar
***_ foobar
**_ another first level node
@endmindmap
''',
  ),
  SubSample(
    name: 'Removing box (Example 3)',
    source: r'''
@startmindmap
+ root node
++ some first level node
+++_ second level node
+++_ another second level node
+++_ foo
+++_ bar
+++_ foobar
++_ another first level node
-- some first right level node
--_ another first right level node
@endmindmap
''',
  ),
  SubSample(
    name: 'Changing diagram direction',
    source: r'''
@startmindmap
* count
** 100
*** 101
*** 102
** 200 left side
** A
*** AA
*** AB
** B
@endmindmap
''',
  ),
  SubSample(
    name: 'Change diagram orientation - Left to right (by default)',
    source: r'''
@startmindmap
* 1
** 2
*** 4
*** 5
** 3
*** 6
*** 7
@endmindmap
''',
  ),
  SubSample(
    name: 'Change diagram orientation - Top to bottom direction',
    source: r'''
@startmindmap
top to bottom direction
* 1
** 2
*** 4
*** 5
** 3
*** 6
*** 7
@endmindmap
''',
  ),
  SubSample(
    name: 'Change diagram orientation - Right to left direction',
    source: r'''
@startmindmap
right to left direction
* 1
** 2
*** 4
*** 5
** 3
*** 6
*** 7
@endmindmap
''',
  ),
  SubSample(
    name: 'Change diagram orientation - Bottom to top direction',
    source: r'''
@startmindmap
top to bottom direction left side
* 1
** 2
*** 4
*** 5
** 3
*** 6
*** 7
@endmindmap
''',
  ),
  SubSample(
    name: 'Complete example',
    source: r'''
@startmindmap
caption figure 1
title My super title
* <&flag>Debian
** <&globe>Ubuntu
*** Linux Mint
*** Kubuntu
*** Lubuntu
*** KDE Neon
** <&graph>LMDE
** <&pulse>SolydXK
** <&people>SteamOS
** <&star>Raspbian with a very long name
*** <s>Raspmbc</s> => OSMC
*** <s>Raspyfi</s> => Volumio
header My super header endheader
center footer My super footer
legend right
Short legend
endlegend
@endmindmap
''',
  ),
  SubSample(
    name: 'Changing style - node, depth',
    source: r'''
@startmindmap
<style>
mindmapDiagram {
node {
BackgroundColor lightGreen
}
:depth(1) {
BackGroundColor white
}
}
</style>
* Linux
** NixOS
** Debian
*** Ubuntu
**** Linux Mint
**** Kubuntu
**** Lubuntu
**** KDE Neon
@endmindmap
''',
  ),
  SubSample(
    name: 'Changing style - boxless',
    source: r'''
@startmindmap
<style>
mindmapDiagram {
node {
BackgroundColor lightGreen
}
boxless {
FontColor darkgreen
}
}
</style>
* Linux
** NixOS
** Debian
***_ Ubuntu
**** Linux Mint
**** Kubuntu
**** Lubuntu
**** KDE Neon
@endmindmap
''',
  ),
  SubSample(
    name: 'Word Wrap',
    source: r'''
@startmindmap
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
**** but it could be cool if PlantUML was able to split long lines, maybe with an option
@endmindmap
''',
  ),
  SubSample(
    name: 'Creole on Mindmap diagram',
    source: r'''
@startmindmap
* Creole on Mindmap
left side
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
right side
**:==Creole line
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
@endmindmap
''',
  ),
];
