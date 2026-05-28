import 'sample_models.dart';

const jsonSubSamples = <SubSample>[
  SubSample(
    name: 'Display JSON Data',
    source: r'''
@startjson
{
  "fruit":"Apple",
  "size":"Large",
  "color": ["Red", "Green"]
}
@endjson
''',
  ),
  SubSample(
    name: 'Complex example',
    source: r'''
@startjson
{
  "firstName": "John",
  "lastName": "Smith",
  "isAlive": true,
  "age": 27,
  "address": {
    "streetAddress": "21 2nd Street",
    "city": "New York",
    "state": "NY",
    "postalCode": "10021-3100"
  },
  "phoneNumbers": [
    {
      "type": "home",
      "number": "212 555-1234"
    },
    {
      "type": "office",
      "number": "646 555-4567"
    }
  ],
  "children": [],
  "spouse": null
}
@endjson
''',
  ),
  SubSample(
    name: 'Highlight parts',
    source: r'''
@startjson
#highlight "lastName"
#highlight "address" / "city"
#highlight "phoneNumbers" / "0" / "number"
{
  "firstName": "John",
  "lastName": "Smith",
  "isAlive": true,
  "age": 28,
  "address": {
    "streetAddress": "21 2nd Street",
    "city": "New York",
    "state": "NY",
    "postalCode": "10021-3100"
  },
  "phoneNumbers": [
    {
      "type": "home",
      "number": "212 555-1234"
    },
    {
      "type": "office",
      "number": "646 555-4567"
    }
  ],
  "children": [],
  "spouse": null
}
@endjson
''',
  ),
  SubSample(
    name: 'Using different styles for highlight',
    source: r'''
@startjson
<style>
.h1 {
  BackGroundColor green
  FontColor white
  FontStyle italic
}
.h2 {
  BackGroundColor red
  FontColor white
  FontStyle bold
}
</style>
#highlight "lastName"
#highlight "address" / "city" <<h1>>
#highlight "phoneNumbers" / "0" / "number" <<h2>>
{
  "firstName": "John",
  "lastName": "Smith",
  "isAlive": true,
  "age": 28,
  "address": {
    "streetAddress": "21 2nd Street",
    "city": "New York",
    "state": "NY",
    "postalCode": "10021-3100"
  },
  "phoneNumbers": [
    {
      "type": "home",
      "number": "212 555-1234"
    },
    {
      "type": "office",
      "number": "646 555-4567"
    }
  ],
  "children": [],
  "spouse": null
}
@endjson
''',
  ),
  SubSample(
    name: 'JSON basic element',
    source: r'''
@startjson
{
  "null": null,
  "true": true,
  "false": false,
  "JSON_Number": [-1, -1.1, "<color:green>TBC"],
  "JSON_String": "a\nb\rc\td <color:green>TBC...",
  "JSON_Object": {
    "{}": {},
    "k_int": 123,
    "k_str": "abc",
    "k_obj": {"k": "v"}
  },
  "JSON_Array" : [
    [],
    [true, false],
    [-1, 1],
    ["a", "b", "c"],
    ["mix", null, true, 1, {"k": "v"}]
  ]
}
@endjson
''',
  ),
  SubSample(
    name: 'Array type',
    source: r'''
@startjson
{
  "Numeric": [1, 2, 3],
  "String ": ["v1a", "v2b", "v3c"],
  "Boolean": [true, false, true]
}
@endjson
''',
  ),
  SubSample(
    name: 'Number array',
    source: r'''
@startjson
[1, 2, 3]
@endjson
''',
  ),
  SubSample(
    name: 'String array',
    source: r'''
@startjson
["1a", "2b", "3c"]
@endjson
''',
  ),
  SubSample(
    name: 'Boolean array',
    source: r'''
@startjson
[true, false, true]
@endjson
''',
  ),
  SubSample(
    name: 'JSON numbers',
    source: r'''
@startjson
{
  "DecimalNumber": [-1, 0, 1],
  "DecimalNumber . Digits": [-1.1, 0.1, 1.1],
  "DecimalNumber ExponentPart": [1E5]
}
@endjson
''',
  ),
  SubSample(
    name: 'JSON Unicode',
    source: r'''
@startjson
{
  "<color:blue><b>code": "<color:blue><b>value",
  "a\\u005Cb": "a\b",
  "\\uD83D\\uDE10": "😐",
  "😐": "😐"
}
@endjson
''',
  ),
  SubSample(
    name: 'JSON two-character escape sequence',
    source: r'''
@startjson
{
  "**legend**: character name": ["**two-character escape sequence**", "example (between 'a' and 'b')"],
  "quotation mark character (U+0022)": ["\\\"", "a\"b"],
  "reverse solidus character (U+005C)": ["\\\\", "a\\b"],
  "solidus character (U+002F)": ["\\/", "a/b"],
  "backspace character (U+0008)": ["\\b", "a\bb"],
  "form feed character (U+000C)": ["\\f", "a\fb"],
  "line feed character (U+000A)": ["\\n", "a\nb"],
  "carriage return character (U+000D)": ["\\r", "a\rb"],
  "character tabulation character (U+0009)": ["\\t", "a\tb"]
}
@endjson
''',
  ),
  SubSample(
    name: 'Escape sequences array',
    source: r'''
@startjson
[
  "\\\\",
  "\\n",
  "\\r",
  "\\t"
]
@endjson
''',
  ),
  SubSample(
    name: 'Minimal JSON example (string)',
    source: r'''
@startjson
"Hello world!"
@endjson
''',
  ),
  SubSample(
    name: 'Minimal JSON example (number)',
    source: r'''
@startjson
42
@endjson
''',
  ),
  SubSample(
    name: 'Minimal JSON example (boolean)',
    source: r'''
@startjson
true
@endjson
''',
  ),
  SubSample(
    name: 'Empty table or list',
    source: r'''
@startjson
{
  "empty_tab": [],
  "empty_list": {}
}
@endjson
''',
  ),
  SubSample(
    name: 'Without style (by default)',
    source: r'''
@startjson
#highlight "1" / "hr"
[
  {
    "name": "Mark McGwire",
    "hr": 65,
    "avg": 0.278
  },
  {
    "name": "Sammy Sosa",
    "hr": 63,
    "avg": 0.288
  }
]
@endjson
''',
  ),
  SubSample(
    name: 'With style',
    source: r'''
@startjson
<style>
jsonDiagram {
  node {
    BackGroundColor Khaki
    LineColor lightblue
    FontName Helvetica
    FontColor red
    FontSize 18
    FontStyle bold
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
  highlight {
    BackGroundColor red
    FontColor white
    FontStyle italic
  }
}
</style>
#highlight "1" / "hr"
[
  {
    "name": "Mark McGwire",
    "hr": 65,
    "avg": 0.278
  },
  {
    "name": "Sammy Sosa",
    "hr": 63,
    "avg": 0.288
  }
]
@endjson
''',
  ),
  SubSample(
    name: 'JSON on Class diagram',
    source: r'''
@startuml
class Class
object Object
json JSON {
  "fruit":"Apple",
  "size":"Large",
  "color": ["Red", "Green"]
}
@enduml
''',
  ),
  SubSample(
    name: 'Complex example with all JSON basic element',
    source: r'''
@startuml
json "<b>JSON basic element" as J {
  "null": null,
  "true": true,
  "false": false,
  "JSON_Number": [-1, -1.1, "<color:green>TBC"],
  "JSON_String": "a\nb\rc\td <color:green>TBC...",
  "JSON_Object": {
    "{}": {},
    "k_int": 123,
    "k_str": "abc",
    "k_obj": {"k": "v"}
  },
  "JSON_Array" : [
    [],
    [true, false],
    [-1, 1],
    ["a", "b", "c"],
    ["mix", null, true, 1, {"k": "v"}]
  ]
}
@enduml
''',
  ),
  SubSample(
    name: 'JSON with allowmixing',
    source: r'''
@startuml
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
@enduml
''',
  ),
  SubSample(
    name: 'Complex example with arrow',
    source: r'''
@startuml
allowmixing
agent Agent
stack {
  json "JSON_file.json" as J {
    "fruit":"Apple",
    "size":"Large",
    "color": ["Red", "Green"]
  }
}
database Database
Agent -> J
J -> Database
@enduml
''',
  ),
  SubSample(
    name: 'JSON on State diagram',
    source: r'''
@startuml
state "A" as stateA
state "C" as stateC
{
  state B
}
json J {
  "fruit":"Apple",
  "size":"Large",
  "color": ["Red", "Green"]
}
@enduml
''',
  ),
  SubSample(
    name: 'Creole on JSON',
    source: r'''
@startjson
{
  "Creole": {
    "wave": "~~wave~~",
    "bold": "**bold**",
    "italics": "//italics//",
    "stricken-out": "--stricken-out--",
    "underlined": "__underlined__",
    "not-underlined": "~__not underlined__",
    "wave-underlined": "~~wave-underlined~~"
  },
  "HTML Creole": {
    "bold": "<b>bold",
    "italics": "<i>italics",
    "monospaced": "<font:monospaced>monospaced",
    "stroked": "<s>stroked",
    "underlined": "<u>underlined",
    "waved": "<w>waved",
    "green-stroked": "<s:green>stroked",
    "red-underlined": "<u:red>underlined",
    "blue-waved": "<w:#0000FF>waved",
    "Blue": "<color:blue>Blue",
    "Orange": "<back:orange>Orange background",
    "big": "<size:20>big"
  },
  "Graphic": {
    "OpenIconic": "account-login <&account-login>",
    "Unicode": "This is <U+221E> long",
    "Emoji": "<:calendar:> Calendar",
    "Image": "<img:https://plantuml.com/logo3.png>"
  }
}
@endjson
''',
  ),
];
