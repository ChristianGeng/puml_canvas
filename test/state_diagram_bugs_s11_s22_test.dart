import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

StateDiagram _parseStateDiagram(String source) {
  final tokens = Lexer().tokenize(source);
  final diagram = Parser().parse(tokens);
  if (diagram is! StateDiagram) {
    throw StateError('Expected StateDiagram, got ${diagram.runtimeType}');
  }
  return diagram;
}

void main() {
  group('state diagram bugs S11-S22', () {
    test('S11: note on link on transition', () {
      _parse('''
@startuml
[*] -> State1
State1 --> State2
note on link
this is a state-transition note
end note
@enduml
''');
    });

    test('S12: <<start>>/<<end>> stereotypes + state-attached notes', () {
      _parse('''
@startuml
state start <<start>>
start -> A
note left of start : this is a short note on start state
end <<end>>
A -> end
note right of end
note on end
end note
@enduml
''');
    });

    test('S13: note left of X inline + multi-line note right of X', () {
      _parse('''
@startuml
[*] --> Active
Active --> Inactive
note left of Active : this is a short\\nnote
note right of Inactive
A note can also be defined on several lines
end note
@enduml
''');
    });

    test('S14: arrows in label text', () {
      _parse('''
@startuml
state a
a -> b : -> c
x-> d : x-> e
->o f : <>->o g
x->o h : x->o
@enduml
''');
    });

    test('S15: color+direction+style modifiers on arrows', () {
      _parse('''
@startuml
State S1
State S2
S1 -[#DD00AA]-> S2
S1 -left[#yellow]-> S3
S1 -up[#red,dashed]-> S4
S1 -right[dotted,#blue]-> S5
X1 -[dashed]-> X2
Z1 -[dotted]-> Z2
Y1 -[#blue,bold]-> Y2
@enduml
''');
    });

    test('S16: direction hint arrows', () {
      _parse('''
@startuml
[*] -up-> First
First -right-> Second
Second --> Third
Third -left-> Last
@enduml
''');
    });

    test('S17: history stereotypes', () {
      _parse('''
@startuml
state A {
  state s1 as "Start 1" <<start>>
  state s2 as "H 2" <<history>>
  state s3 as "H 3" <<history*>>
}
@enduml
''');
    });

    test('S18: concurrent states with || separator', () {
      _parse('''
@startuml
[*] --> Active
state Active {
  [*] -> NumLockOff
  NumLockOff --> NumLockOn : EvNumLockPressed
  NumLockOn --> NumLockOff : EvNumLockPressed
  ||
  [*] -> CapsLockOff
  CapsLockOff --> CapsLockOn : EvCapsLockPressed
  CapsLockOn --> CapsLockOff : EvCapsLockPressed
  ||
  [*] -> ScrollLockOff
  ScrollLockOff --> ScrollLockOn : EvScrollLockPressed
  ScrollLockOn --> ScrollLockOff : EvScrollLockPressed
}
@enduml
''');
    });

    test('S19: composite + history [H], [H*], [H*]:DeepResume', () {
      _parse('''
@startuml
[*] -> State1
State1 --> State2 : Succeeded
State1 --> [*] : Aborted
State2 --> State3 : Succeeded
State2 --> [*] : Aborted
state State3 {
  state "Accumulate Enough Data" as long1
  long1 : Just a test
  [*] --> long1
  long1 --> long1 : New Data
  long1 --> ProcessData : Enough Data
  State2 --> [H]: Resume
}
State3 --> State2 : Pause
State2 --> State3[H*]: DeepResume
State3 --> State3 : Failed
State3 --> [*] : Succeeded / Save Result
State3 --> [*] : Aborted
@enduml
''');
    });

    test('S20: scale 600 width + composite states', () {
      _parse('''
@startuml
scale 600 width
[*] -> State1
State1 --> State2 : Succeeded
State1 --> [*] : Aborted
State2 --> State3 : Succeeded
State2 --> [*] : Aborted
state State3 {
  state "Accumulate Enough Data\\nLong State Name" as long1
  long1 : Just a test
  [*] --> long1
  long1 --> long1 : New Data
  long1 --> ProcessData : Enough Data
}
State3 --> State3 : Failed
State3 --> [*] : Succeeded / Save Result
State3 --> [*] : Aborted
@enduml
''');
    });

    test('S21: scale 350 width + nested composite states', () {
      _parse('''
@startuml
scale 350 width
[*] --> NotShooting
state NotShooting {
  [*] --> Idle
  Idle --> Configuring : EvConfig
  Configuring --> Idle : EvConfig
}
state Configuring {
  [*] --> NewValueSelection
  NewValueSelection --> NewValuePreview : EvNewValue
  NewValuePreview --> NewValueSelection : EvNewValueRejected
  NewValuePreview --> NewValueSelection : EvNewValueSaved
  state NewValuePreview {
    State1 -> State2
  }
}
@enduml
''');
    });

    test('pseudo-state stereotypes captured on StateDecl', () {
      // Every recognized pseudo-state stereotype (`start`, `choice`, `fork`,
      // `join`, `end`) must round-trip onto `StateDecl.stereotype` so the
      // state layout can dispatch to special shapes instead of rendering a
      // rounded box with the alias name.
      final diagram = _parseStateDiagram('''
@startuml
state start1 <<start>>
state choice1 <<choice>>
state fork1 <<fork>>
state join2 <<join>>
state end3 <<end>>
start1 --> choice1
choice1 --> fork1
fork1 --> join2
join2 --> end3
@enduml
''');
      final byName = {for (final s in diagram.states) s.name: s};
      expect(byName['start1']?.stereotype, 'start');
      expect(byName['choice1']?.stereotype, 'choice');
      expect(byName['fork1']?.stereotype, 'fork');
      expect(byName['join2']?.stereotype, 'join');
      expect(byName['end3']?.stereotype, 'end');
    });

    test('S22: hide empty description + multiple state descriptions', () {
      _parse('''
@startuml
hide empty description
[*] --> State1
State1 --> [*]
State1 : this is a string
State1 : this is another string
State1 -> State2
State2 --> [*]
@enduml
''');
    });
  });
}
