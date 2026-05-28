import 'sample_models.dart';

const yamlSubSamples = <SubSample>[
  SubSample(
    name: 'Display YAML Data',
    source: r'''
@startyaml
fruit: Apple
size: Large
color:
  - Red
  - Green
@endyaml
''',
  ),
  SubSample(
    name: 'Complex example',
    source: r'''
@startyaml
doe: "a deer, a female deer"
ray: "a drop of golden sun"
pi: 3.14159
xmas: true
french-hens: 3
calling-birds:
  - huey
  - dewey
  - louie
  - fred
xmas-fifth-day:
  calling-birds: four
  french-hens: 3
  golden-rings: 5
partridges:
  count: 1
  location: "a pear tree"
turtle-doves: two
@endyaml
''',
  ),
  SubSample(
    name: 'Specific key (with symbols or unicode)',
    source: r'''
@startyaml
@fruit: Apple
$size: Large
&color: Red
❤: Heart
‰: Per mille
@endyaml
''',
  ),
  SubSample(
    name: 'Highlight parts - Normal style',
    source: r'''
@startyaml
#highlight "french-hens"
#highlight "xmas-fifth-day" / "partridges"
doe: "a deer, a female deer"
ray: "a drop of golden sun"
pi: 3.14159
xmas: true
french-hens: 3
calling-birds:
  - huey
  - dewey
  - louie
  - fred
xmas-fifth-day:
  calling-birds: four
  french-hens: 3
  golden-rings: 5
partridges:
  count: 1
  location: "a pear tree"
turtle-doves: two
@endyaml
''',
  ),
  SubSample(
    name: 'Highlight parts - Customised style',
    source: r'''
@startyaml
<style>
yamlDiagram {
  highlight {
    BackGroundColor red
    FontColor white
    FontStyle italic
  }
}
</style>
#highlight "french-hens"
#highlight "xmas-fifth-day" / "partridges"
doe: "a deer, a female deer"
ray: "a drop of golden sun"
pi: 3.14159
xmas: true
french-hens: 3
calling-birds:
  - huey
  - dewey
  - louie
  - fred
xmas-fifth-day:
  calling-birds: four
  french-hens: 3
  golden-rings: 5
partridges:
  count: 1
  location: "a pear tree"
turtle-doves: two
@endyaml
''',
  ),
  SubSample(
    name: 'Using different styles for highlight',
    source: r'''
@startyaml
<style>
.h1 {
  BackGroundColor green
  FontColor white
  FontStyle italic
}
.h2 {
  BackGroundColor red
  FontColor white
  FontStyle italic
}
</style>
#highlight "french-hens" <<h1>>
#highlight "xmas-fifth-day" / "partridges" <<h2>>
doe: "a deer, a female deer"
ray: "a drop of golden sun"
pi: 3.14159
xmas: true
french-hens: 3
calling-birds:
  - huey
  - dewey
  - louie
  - fred
xmas-fifth-day:
  calling-birds: four
  french-hens: 3
  golden-rings: 5
partridges:
  count: 1
  location: "a pear tree"
turtle-doves: two
@endyaml
''',
  ),
  SubSample(
    name: 'Using (global) style - Without style',
    source: r'''
@startyaml
- name: Mark McGwire
  hr: 65
  avg: 0.278
- name: Sammy Sosa
  hr: 63
  avg: 0.288
@endyaml
''',
  ),
  SubSample(
    name: 'Using (global) style - With style',
    source: r'''
@startyaml
<style>
yamlDiagram {
  node {
    BackGroundColor lightblue
    LineColor lightblue
    FontName Helvetica
    FontColor red
    FontSize 18
    FontStyle bold
    BackGroundColor Khaki
    RoundCorner 0
    LineThickness 2
    LineStyle 10-5
    separator {
      LineThickness 0.5
      LineColor black
      LineStyle 1-5
    }
  }
  arrow {
    BackGroundColor lightblue
    LineColor green
    LineThickness 2
    LineStyle 2-5
  }
}
</style>
- name: Mark McGwire
  hr: 65
  avg: 0.278
- name: Sammy Sosa
  hr: 63
  avg: 0.288
@endyaml
''',
  ),
  SubSample(
    name: 'Creole on YAML',
    source: r'''
@startyaml
Creole:
  wave: ~~wave~~
  bold: \*\*bold\*\*
  italics: //italics//
  monospaced: ""monospaced""
  stricken-out: --stricken-out--
  underlined: \_\_underlined\_\_
  not-underlined: ~\_\_not underlined\_\_
  wave-underlined: ~~wave-underlined~~
HTML Creole:
  bold: <b>bold
  italics: <i>italics
  monospaced: <font:monospaced>monospaced
  stroked: <s>stroked
  underlined: <u>underlined
  waved: <w>waved
  green-stroked: <s:green>stroked
  red-underlined: <u:red>underlined
  blue-waved: <w:#0000FF>waved
  Blue: <color:blue>Blue
  Orange: <back:orange>Orange background
  big: <size:20>big
Graphic:
  OpenIconic: account-login <&account-login>
  Unicode: This is <U+221E> long
  Emoji: <:calendar:> Calendar
  Image: <img:https://plantuml.com/logo3.png>
@endyaml
''',
  ),
];
