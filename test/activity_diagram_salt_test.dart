import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void _parse(String source) {
  final tokens = Lexer().tokenize(source);
  Parser().parse(tokens);
}

void main() {
  group('activity diagram Salt UI mockup integrations', () {
    test('activity diagram with !unquoted procedure + SALT macro calls', () {
      _parse('''
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
''');
    });

    test('activity diagram with multi-line salt-embedded quoted labels', () {
      _parse('''
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
''');
    });
  });
}
