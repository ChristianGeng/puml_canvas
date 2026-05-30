import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('activity diagram parser bugs 71-75', () {
    test('71: emoji `<:name:>` in while/action + standalone stereotypes', () {
      _parse('''
@startuml
while (<:cloud_with_rain:>)
:<:umbrella:>;
<<icon>>
endwhile
-<<icon>><:closed_umbrella:>
@enduml
''');
    });

    test('72: SDL shape stereotypes after :action;', () {
      _parse('''
@startuml
start
:SDL Shape;
:input;
<<input>>
:output;
<<output>>
:procedure;
<<procedure>>
:load;
<<load>>
:save;
<<save>>
:continuous;
<<continuous>>
:task;
<<task>>
end
@enduml
''');
    });

    test('73: split / split again / end split with stereotypes', () {
      _parse('''
@startuml
:Ready;
:next(o);
<<procedure>>
:Receiving;
split
:nak(i);
<<input>>
:ack(o);
<<output>>
split again
:ack(i);
<<input>>
:next(o) on several lines;
<<procedure>>
:i := i + 1;
<<task>>
:ack(o);
<<output>>
split again
:err(i);
<<input>>
:nak(o);
<<output>>
split again
:foo;
<<save>>
split again
:bar;
<<load>>
split again
:i > 5;
<<continuous>>
stop
end split
:finish;
@enduml
''');
    });

    test('74: UML object/signal stereotypes after actions', () {
      _parse('''
@startuml
:action;
:object;
<<object>>
:ObjectNode typed by signal;
<<objectSignal>>
:AcceptEventAction without TimeEvent trigger;
<<acceptEvent>>
:SendSignalAction;
<<sendSignal>>
:SendObjectAction with signal type;
<<sendSignal>>
:Trigger;
<<trigger>>
:\t\t\t\t\t\tAcceptEventAction \t\t\t\t\t\twith TimeEvent trigger;
<<timeEvent>>
:an action;
@enduml
''');
    });

    test('75: repeat ... repeatwhile (cond) with inline markup', () {
      _parse('''
@startuml
skinparam conditionStyle inside
start
repeat
  :act1;
  :act2;
repeatwhile (<b>end)
:act3;
@enduml
''');
    });
  });
}
