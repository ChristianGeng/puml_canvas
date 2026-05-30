import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/lexer/lexer.dart';
import 'package:puml_canvas/src/parser/parser.dart';

/// Regression test for ArchiMate source sample A2. Exercises sprite
/// definitions with `jar:archimate/X` references, rectangle declarations
/// with multiple stereotypes (`<<$bProcess>><<behavior>>`), composite /
/// open-headed / dashed arrows with direction qualifiers
/// (`*-down-`, `-right->>`, `.up.|>`), and a `legend left` block whose
/// body is separated by `====` rulers.
void main() {
  test('A2 — ArchiMate composite (sprites, stereotypes, arrows, legend left)',
      () {
    const source = '@startuml\n'
        'skinparam rectangle<<behavior>> {\n'
        '    roundCorner 25\n'
        '}\n'
        'sprite \$bProcess jar:archimate/business-process\n'
        'sprite \$aService jar:archimate/application-service\n'
        'sprite \$aComponent jar:archimate/application-component\n'
        'rectangle "Handle claim" as HC <<\$bProcess>><<behavior>> #Business\n'
        'rectangle "Capture Information" as CI <<\$bProcess>><<behavior>> #Business\n'
        'rectangle "Notify\\nAdditional Stakeholders" as NAS <<\$bProcess>><<behavior>> #Business\n'
        'rectangle "Validate" as V <<\$bProcess>><<behavior>> #Business\n'
        'rectangle "Investigate" as I <<\$bProcess>><<behavior>> #Business\n'
        'rectangle "Pay" as P <<\$bProcess>><<behavior>> #Business\n'
        'HC *-down- CI\n'
        'HC *-down- NAS\n'
        'HC *-down- V\n'
        'HC *-down- I\n'
        'HC *-down- P\n'
        'CI -right->> NAS\n'
        'NAS -right->> V\n'
        'V -right->> I\n'
        'I -right->> P\n'
        'rectangle "Scanning" as scanning <<\$aService>><<behavior>> #Application\n'
        'rectangle "Customer administration" as customerAdministration <<\$aService>><<behavior>> #Application\n'
        'rectangle "Claims administration" as claimsAdministration <<\$aService>><<behavior>> #Application\n'
        'rectangle Printing <<\$aService>><<behavior>> #Application\n'
        'rectangle Payment <<\$aService>><<behavior>> #Application\n'
        'scanning -up-> CI\n'
        'customerAdministration -up-> CI\n'
        'claimsAdministration -up-> NAS\n'
        'claimsAdministration -up-> V\n'
        'claimsAdministration -up-> I\n'
        'Payment -up-> P\n'
        'Printing -up-> V\n'
        'Printing -up-> P\n'
        'rectangle "Document\\nManagement\\nSystem" as DMS <<\$aComponent>> #Application\n'
        'rectangle "General\\nCRM\\nSystem" as CRM <<\$aComponent>> #Application\n'
        'rectangle "Home & Away\\nPolicy\\nAdministration" as HAPA <<\$aComponent>> #Application\n'
        'rectangle "Home & Away\\nFinancial\\nAdministration" as HFPA <<\$aComponent>> #Application\n'
        'DMS .up.|> scanning\n'
        'DMS .up.|> Printing\n'
        'CRM .up.|> customerAdministration\n'
        'HAPA .up.|> claimsAdministration\n'
        'HFPA .up.|> Payment\n'
        'legend left\n'
        '    Example from the "Archisurance case study" (OpenGroup). See\n'
        '    ====\n'
        '    <\$bProcess> :business process\n'
        '    ====\n'
        '    <\$aService> : application service\n'
        '    ====\n'
        '    <\$aComponent> : application component\n'
        'endlegend\n'
        '@enduml\n';
    final tokens = Lexer().tokenize(source);
    final diagram = Parser().parse(tokens);
    expect(diagram, isNotNull);
  });
}
