import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('activity diagram arrow-label / if-is / partition / note / style', () {
    test('A1: stand-alone arrow label, if-is, note attachment, partition', () {
      _parse('''
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
''');
    });

    test('A2: same as A1 with surrounding <style> block', () {
      _parse('''
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
''');
    });
  });
}
