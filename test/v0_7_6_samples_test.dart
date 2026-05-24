import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

class _M implements TextMeasurer {
  @override
  Size measure(String text, TextStyle style) => Size(text.length * 7.0, 14);
}

void _parseAndLayout(String source) {
  final tokens = Lexer().tokenize(source);
  final diagram = Parser().parse(tokens);
  const AutoLayout().layout(diagram, _M());
}

void main() {
  group('v0.7.6 sample smoke tests', () {
    test('timing diagram with binary lane and highlight', () {
      _parseAndLayout('''
@startuml
robust "Browser" as B
binary "Cache Hit" as C
clock "Retry Clock" as R with period 100

@0
B is Idle
C is low

@100
B is Loading
C is high

highlight 50 to 100 #LightYellow : window
@enduml
''');
    });

    test('state diagram with hide empty description and history pseudo-state',
        () {
      _parseAndLayout('''
@startuml
hide empty description

[*] --> Queued
Queued --> Running

state Running {
  [*] --> Working
  Working --> Done
  Done --> [*]

  Working --> H : resume
  state H <<history>>
}

Running --> Final
Final --> [*]
@enduml
''');
    });

    test('gantt with title, weekends-closed, and compound lasts/starts', () {
      _parseAndLayout('''
@startgantt
title Release train

Project starts 2026-05-25
saturday are closed
sunday are closed

[Spec freeze] lasts 2 days
[Parser] lasts 5 days and starts at [Spec freeze]'s end
[QA] lasts 3 days and starts at [Parser]'s end
[Release] happens at [QA]'s end

then [Patch] lasts 2 days
@endgantt
''');
    });

    test('json with #highlight directive', () {
      _parseAndLayout('''
@startjson
#highlight "services" / "1"
{
  "name": "viewer",
  "services": [
    {"id": "a"},
    {"id": "b"}
  ]
}
@endjson
''');
    });

    test('yaml with anchors, references, and merge keys', () {
      _parseAndLayout('''
@startyaml
#highlight "envs"
defaults: &defaults
  retries: 3
  timeout: 5s

envs:
  dev:
    <<: *defaults
    endpoint: http://localhost
  prod:
    <<: *defaults
    endpoint: https://api.example.com
@endyaml
''');
    });

    test('sequence with teoz pragma and box color and bidirectional arrow', () {
      _parseAndLayout('''
@startuml
!pragma teoz true
title Async checkout

box "Edge" #LightBlue
  participant "Web App\\nSPA" as Web
  participant GW
end box

participant Order

Web -> GW ++ : POST /checkout
GW -> Order ++ : createOrder
& GW -> Order : event
return reservationId

{start} Web -> GW : await
{end} GW -> Web : done
{start} <-> {end} : SLA window
@enduml
''');
    });

    test('preprocessor theme, procedure, and conditional blocks (lenient)', () {
      _parseAndLayout('''
@startuml
!theme spacelab
!pragma layout smetana

!\$env = "prod"
!procedure \$service(\$name, \$color)
  component "\$name" as \$name \$color
!endprocedure

package "Demo" {
  \$service("Gateway", #LightBlue)
  \$service("Renderer", #LightGreen)
}

Gateway --> Renderer : render

!if (\$env == "prod")
  cloud "Obs" as Obs {
    [Metrics]
    [Logs]
  }
  Gateway --> Obs : telemetry
!else
  note right of Gateway
    Local mode.
  end note
!endif
@enduml
''');
    });

    test('ebnf and regex diagram as code listing', () {
      _parseAndLayout('''
@startebnf
title Mini grammar

diagram = start , { statement } , end ;
statement = participant | message ;
arrow = "->" | "-->" ;
@endebnf
''');
      _parseAndLayout('''
@startregex
title File detector

^\\s*@start(?:uml|json|yaml)\\b
@endregex
''');
    });
  });
}
