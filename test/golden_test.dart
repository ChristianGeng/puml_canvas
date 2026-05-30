@Tags(['golden'])
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'golden_helpers.dart';

void main() {
  group('PumlView goldens', () {
    testWidgets('single solid message', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\nA -> B : hello\n@enduml\n',
        'single_solid_message',
      );
    });

    testWidgets('mixed solid and dashed', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Alice -> Bob : Authentication Request\n'
        'Bob --> Alice : Authentication Response\n'
        '@enduml\n',
        'mixed_solid_dashed',
      );
    });

    testWidgets('three participants', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : ping\n'
        'B -> C : forward\n'
        'C --> A : ack\n'
        '@enduml\n',
        'three_participants',
      );
    });

    testWidgets('self-message', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : ask\n'
        'B -> B : think\n'
        'B --> A : reply\n'
        '@enduml\n',
        'self_message',
      );
    });

    testWidgets('notes', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : start\n'
        'note left of A : caller\n'
        'note right of B : callee\n'
        'note over A, B : shared context\n'
        '@enduml\n',
        'notes',
      );
    });

    testWidgets('multiline note', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : start\n'
        'note over A, B\n'
        'This is a multi-line\n'
        'note over both A and B.\n'
        'It can span any number of lines.\n'
        'end note\n'
        'B --> A : done\n'
        '@enduml\n',
        'multiline_note',
      );
    });

    testWidgets('activation bars', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : request\n'
        'activate B\n'
        'B -> C : forward\n'
        'activate C\n'
        'C --> B : ok\n'
        'deactivate C\n'
        'B --> A : ok\n'
        'deactivate B\n'
        '@enduml\n',
        'activation_bars',
      );
    });

    testWidgets('alt/else group', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : login\n'
        'alt valid\n'
        'B --> A : 200 OK\n'
        'else invalid\n'
        'B --> A : 401\n'
        'end\n'
        '@enduml\n',
        'alt_group',
      );
    });

    testWidgets('nested loop inside alt', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'alt has items\n'
        'loop each item\n'
        'A -> B : process\n'
        'end\n'
        'else empty\n'
        'A -> B : skip\n'
        'end\n'
        '@enduml\n',
        'nested_groups',
      );
    });

    testWidgets('actor kinds gallery', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'actor User\n'
        'boundary UI\n'
        'control Ctrl\n'
        'entity Model\n'
        'database DB\n'
        'collections Items\n'
        'queue MQ\n'
        'User -> UI : click\n'
        'UI -> Ctrl : event\n'
        'Ctrl -> Model : update\n'
        'Model -> DB : write\n'
        'Ctrl -> Items : push\n'
        'Items -> MQ : enqueue\n'
        '@enduml\n',
        'actor_kinds',
        size: const Size(900, 500),
      );
    });

    testWidgets('arrow variants gallery', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : ->\n'
        'A --> B : -->\n'
        'A ->> B : ->>\n'
        'A -->> B : -->>\n'
        'A ->o B : ->o\n'
        'A -->o B : -->o\n'
        'A ->x B : ->x\n'
        'A -->x B : -->x\n'
        'A <- B : <-\n'
        'A <-- B : <--\n'
        'A <<- B : <<-\n'
        'A <<-- B : <<--\n'
        '@enduml\n',
        'arrow_variants',
        size: const Size(640, 720),
      );
    });

    testWidgets('arrow modifiers gallery', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -[#red]-> B : red solid\n'
        'A --[#blue]-> B : blue dashed\n'
        'A -[hidden]-> C\n'
        '@enduml\n',
        'arrow_modifiers',
      );
    });

    testWidgets('inline activation suffixes', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B ++ : request\n'
        'B --> A -- : reply\n'
        'A -> C ** : create\n'
        'C -> A !! : crash\n'
        '@enduml\n',
        'inline_activation',
        size: const Size(640, 400),
      );
    });

    testWidgets('create and destroy keywords', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant A\n'
        'A -> A : init\n'
        'create participant B\n'
        'A -> B : spawn\n'
        'B --> A : ready\n'
        'destroy B\n'
        '@enduml\n',
        'create_destroy_keywords',
      );
    });

    testWidgets('ref over box', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : start\n'
        'ref over A, B : See login flow\n'
        'B --> A : done\n'
        '@enduml\n',
        'ref_box',
      );
    });

    testWidgets('participant box around groups', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'box "Backend" #LightBlue\n'
        'participant Service as S\n'
        'database DB\n'
        'end box\n'
        'box "Frontend"\n'
        'actor User\n'
        'end box\n'
        'participant Logger as L\n'
        'User -> S : request\n'
        'S -> DB : query\n'
        'DB --> S : row\n'
        'S --> User : response\n'
        'S -> L : log\n'
        '@enduml\n',
        'participant_box',
        size: const Size(720, 480),
      );
    });

    testWidgets('par/alt/loop with boxes and reordered participants',
        (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'actor Customer as C\n'
        'box "Edge" #LightBlue\n'
        '  participant "Web App" as Web\n'
        '  participant "API Gateway" as GW\n'
        'end box\n'
        'box "Core Services" #LightYellow\n'
        '  control "Order" as Order\n'
        '  database "Inv" as Inv\n'
        '  queue "PayQ" as PayQ\n'
        '  participant "PayW" as PayW\n'
        'end box\n'
        'participant "Fraud API" as Fraud\n'
        'collections "Audit" as Audit\n'
        'C -> Web : submitCart\n'
        'Web -> GW : POST /checkout\n'
        'GW -> Order : createOrder\n'
        'GW -> Audit : event\n'
        'Order -> Inv : reserve\n'
        'par fraud score\n'
        '  Order -> Fraud : score\n'
        '  Fraud --> Order : risk=medium\n'
        'else queue payment\n'
        '  Order -> PayQ : publish\n'
        '  PayQ --> PayW : deliver\n'
        '  PayW -> PayW : check\n'
        'end\n'
        'Order -> PayW : await result\n'
        'loop exponential backoff up to 3\n'
        '  PayW -> Fraud : enrich\n'
        '  alt provider timeout\n'
        '    PayW -> PayW : sleep\n'
        '  else accepted\n'
        '    PayW --> Order : PaymentAccepted\n'
        '  else declined\n'
        '    PayW --> Order : PaymentDeclined\n'
        '  end\n'
        'end\n'
        'Order -> Audit : event\n'
        '@enduml\n',
        'sequence_par_alt_loop',
        size: const Size(1300, 1100),
      );
    });

    testWidgets('separators gallery', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : login\n'
        '== Phase 1 ==\n'
        'B -> A : token\n'
        '||20||\n'
        'A -> B : refresh\n'
        '...\n'
        'B -> A : ok\n'
        '--\n'
        'A -> B : bye\n'
        '@enduml\n',
        'separators',
        size: const Size(640, 600),
      );
    });

    testWidgets('sequence separator divider spacing', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '== Initialization ==\n'
        'Alice -> Bob: Authentication Request\n'
        'Bob --> Alice: Authentication Response\n'
        '== Repetition ==\n'
        'Alice -> Bob: Another authentication Request\n'
        'Alice <-- Bob: another authentication Response\n'
        '@enduml\n',
        'sequence_separator_divider_spacing',
        size: const Size(640, 480),
      );
    });

    testWidgets('autonumber sequence', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'autonumber 10 5 "[%03d]"\n'
        'A -> B : login\n'
        'B -> C : forward\n'
        'autonumber stop\n'
        'C --> B : note\n'
        'autonumber resume\n'
        'B --> A : ok\n'
        '@enduml\n',
        'autonumber',
      );
    });

    testWidgets('decorated diagram with title/header/footer/caption',
        (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'header My Header\n'
        'title My Diagram Title\n'
        'A -> B : hello\n'
        'B --> A : world\n'
        'caption My Caption\n'
        'footer right Page 1\n'
        '@enduml\n',
        'decorated_diagram',
      );
    });

    testWidgets('legend block right-aligned', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : hello\n'
        'B --> A : world\n'
        'legend right\n'
        'This is a sample sequence diagram.\n'
        'Authentication happens server-side.\n'
        'endlegend\n'
        '@enduml\n',
        'legend_block',
      );
    });

    testWidgets('newpage divider with per-page title', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : page 1\n'
        'newpage\n'
        'A -> B : page 2\n'
        'newpage Page Three Title\n'
        'A -> B : page 3\n'
        '@enduml\n',
        'newpage_divider',
        size: const Size(640, 600),
      );
    });

    testWidgets('inline formatting on labels and notes', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A -> B : <b>bold</b> and //italic//\n'
        'B --> A : <color:red>red</color> <size:16>big</size>\n'
        'note over A, B\n'
        '__under__ and ~~strike~~\n'
        '<color:#0066CC>hex blue</color>\n'
        'end note\n'
        '@enduml\n',
        'inline_formatting',
        size: const Size(640, 480),
      );
    });

    testWidgets('skinparam styling', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'skinparam backgroundColor #FFF8E7\n'
        'skinparam defaultFontSize 14\n'
        'skinparam sequence {\n'
        '  ArrowColor #003366\n'
        '  LifeLineBackgroundColor #888888\n'
        '}\n'
        'skinparam participantBackgroundColor #DDEEFF\n'
        'skinparam participantBorderColor #003366\n'
        'skinparam noteBackgroundColor #FFE0B2\n'
        'skinparam noteBorderColor #663300\n'
        'A -> B : hello\n'
        'note right of B : styled\n'
        'B --> A : world\n'
        '@enduml\n',
        'skinparam_styling',
      );
    });

    testWidgets('class diagram basic', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'class Animal {\n'
        '  +name: String\n'
        '  -age: int\n'
        '  +eat()\n'
        '  +sleep()\n'
        '}\n'
        'class Dog\n'
        'Animal <|-- Dog\n'
        '@enduml\n',
        'class_diagram_basic',
        size: const Size(640, 480),
      );
    });

    testWidgets('class diagram inline members', (tester) async {
      // Verbatim source for the inline-member rendering bug: classes are
      // declared implicitly via the relationship line and members are added
      // with the `ClassName : member` shorthand. Each box should display its
      // title, a horizontal divider, and the listed members.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Object <|-- ArrayList\n'
        'Object : equals()\n'
        'ArrayList : Object[] elementData\n'
        'ArrayList : size()\n'
        '@enduml\n',
        'class_diagram_inline_members',
        size: const Size(640, 480),
      );
    });

    testWidgets('class diagram relationships', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'interface Drawable {\n'
        '  +draw()\n'
        '}\n'
        'abstract class Shape {\n'
        '  #color: String\n'
        '  +{abstract} area(): double\n'
        '}\n'
        'class Circle\n'
        'class Square\n'
        'enum Color {\n'
        '  RED\n'
        '  GREEN\n'
        '  BLUE\n'
        '}\n'
        'Drawable <|.. Shape\n'
        'Shape <|-- Circle\n'
        'Shape <|-- Square\n'
        'Shape o-- Color : uses\n'
        'Circle ..> Drawable\n'
        '@enduml\n',
        'class_diagram_relationships',
        size: const Size(720, 600),
      );
    });

    testWidgets('object diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'object alice {\n'
        '  name = "Alice"\n'
        '  age = 30\n'
        '}\n'
        'object bob : Person {\n'
        '  name = "Bob"\n'
        '}\n'
        'alice --> bob : knows\n'
        '@enduml\n',
        'object_diagram',
        size: const Size(640, 480),
      );
    });

    testWidgets('map diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'map config {\n'
        '  host => "localhost"\n'
        '  port => "8080"\n'
        '}\n'
        'object server\n'
        'server --> config : reads\n'
        '@enduml\n',
        'map_diagram',
        size: const Size(640, 480),
      );
    });

    testWidgets('er diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'entity Customer {\n'
        '  * id : int <<PK>>\n'
        '  --\n'
        '  * name : varchar\n'
        '  * email : varchar\n'
        '  phone : varchar\n'
        '}\n'
        'entity Order {\n'
        '  * id : int <<PK>>\n'
        '  * customer_id : int <<FK>>\n'
        '  --\n'
        '  * order_date : date\n'
        '  total : decimal\n'
        '}\n'
        'entity LineItem {\n'
        '  * id : int <<PK>>\n'
        '  * order_id : int <<FK>>\n'
        '  * product_id : int <<FK>>\n'
        '  --\n'
        '  quantity : int\n'
        '}\n'
        'Customer ||--o{ Order\n'
        'Order ||--|{ LineItem\n'
        '@enduml\n',
        'er_diagram',
        size: const Size(1500, 360),
      );
    });

    testWidgets('use case diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'actor User\n'
        'actor Admin\n'
        '\n'
        'rectangle System {\n'
        '  usecase "Browse Products" as UC1\n'
        '  usecase "Place Order" as UC2\n'
        '  usecase "Manage Inventory" as UC3\n'
        '  usecase Login as UC4\n'
        '}\n'
        '\n'
        'User --> UC1\n'
        'User --> UC2\n'
        'Admin --> UC3\n'
        'Admin --> UC4\n'
        'UC2 ..> UC4 : <<include>>\n'
        'UC3 ..> UC4 : <<include>>\n'
        '@enduml\n',
        'usecase_diagram',
        size: const Size(720, 600),
      );
    });

    testWidgets('use case multi-line label with separators', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'usecase UC1 as "You can use\n'
        'several lines to define your usecase.\n'
        'You can also use separators.\n'
        '--\n'
        'Several separators are possible.\n'
        '==\n'
        'And you can add titles:\n'
        '..Conclusion..\n'
        'This allows large description."\n'
        '@enduml\n',
        'usecase_multiline_label_separators',
        size: const Size(720, 420),
      );
    });

    testWidgets('use case actor connections with arrow lengths',
        (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'User -> (Start)\n'
        'User --> (Use the application) : A small label\n'
        '\n'
        ':Main Admin: ---> (Use the application) : This is\\nyet another\\nlabel\n'
        '@enduml\n',
        'usecase_actor_connections',
        size: const Size(640, 420),
      );
    });

    testWidgets('use case minimal actor + ellipse', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        ':user: --> (Use case 1)\n'
        ':user: -> (Use case 2)\n'
        '@enduml\n',
        'usecase_minimal',
        size: const Size(420, 320),
      );
    });

    testWidgets('use case with attached and floating notes', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        ':Main Admin: as Admin\n'
        '(Use the application) as (Use)\n'
        '\n'
        'User -> (Start)\n'
        'User --> (Use)\n'
        '\n'
        'Admin ---> (Use)\n'
        '\n'
        'note right of Admin : This is an example.\n'
        '\n'
        'note right of (Use)\n'
        '  A note can also\n'
        '  be on several lines\n'
        'end note\n'
        '\n'
        'note "This note is connected\\nto several objects." as N2\n'
        '(Start) .. N2\n'
        'N2 .. (Use)\n'
        '@enduml\n',
        'usecase_with_notes',
        size: const Size(1100, 460),
      );
    });

    testWidgets('usecase direction hint arrows', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        ':user: -left-> (dummyLeft)\n'
        ':user: -right-> (dummyRight)\n'
        ':user: -up-> (dummyUp)\n'
        ':user: -down-> (dummyDown)\n'
        '@enduml\n',
        'usecase_direction_hint_arrows',
        size: const Size(700, 600),
      );
    });

    testWidgets('usecase packages left to right', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'left to right direction\n'
        'actor Guest as g\n'
        'package Professional {\n'
        '  actor Chef as c\n'
        '  actor "Food Critic" as fc\n'
        '}\n'
        'package Restaurant {\n'
        '  usecase "Eat Food" as UC1\n'
        '  usecase "Pay for Food" as UC2\n'
        '  usecase "Drink" as UC3\n'
        '  usecase "Review" as UC4\n'
        '}\n'
        'fc --> UC4\n'
        'g --> UC1\n'
        'g --> UC2\n'
        'g --> UC3\n'
        '@enduml\n',
        'usecase_packages_left_to_right',
        size: const Size(900, 600),
      );
    });

    testWidgets('usecase skinparam hollow actor', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'skinparam actorStyle Hollow\n'
        ':User: --> (Use)\n'
        '"Main Admin" as Admin\n'
        '"Use the application" as (Use)\n'
        'Admin --> (Admin the application)\n'
        '@enduml\n',
        'usecase_skinparam_hollow_actor',
        size: const Size(700, 500),
      );
    });

    testWidgets('usecase skinparam awesome actor', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'skinparam actorStyle awesome\n'
        ':User: --> (Use)\n'
        '"Main Admin" as Admin\n'
        '"Use the application" as (Use)\n'
        'Admin --> (Admin the application)\n'
        '@enduml\n',
        'usecase_skinparam_awesome_actor',
        size: const Size(700, 500),
      );
    });

    testWidgets('usecase generalization', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        ':Main Admin: as Admin\n'
        '(Use the application) as (Use)\n'
        '\n'
        'User <|-- Admin\n'
        '(Start) <|-- (Use)\n'
        '@enduml\n',
        'usecase_generalization',
        size: const Size(700, 500),
      );
    });

    testWidgets('activity diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'start\n'
        ':Process Order;\n'
        'if (in stock?) then (yes)\n'
        '  :Ship item;\n'
        '  :Send email;\n'
        'else (no)\n'
        '  :Notify customer;\n'
        'endif\n'
        'while (more items?) is (yes)\n'
        '  :Next item;\n'
        'endwhile (no)\n'
        'fork\n'
        '  :Task A;\n'
        'fork again\n'
        '  :Task B;\n'
        'end fork\n'
        ':Final step;\n'
        'stop\n'
        '@enduml\n',
        'activity_diagram',
        size: const Size(720, 1100),
      );
    });

    testWidgets('activity nested if routing', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'start\n'
        'if (outer?) then (yes)\n'
        '  if (inner?) then (yes)\n'
        '    :Inner yes;\n'
        '  else (no)\n'
        '    :Inner no;\n'
        '  endif\n'
        'else (no)\n'
        '  :Outer no;\n'
        'endif\n'
        'stop\n'
        '@enduml\n',
        'activity_nested_if_routing',
        size: const Size(720, 720),
      );
    });

    testWidgets('state diagram basic', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '[*] --> Idle\n'
        'Idle --> Running : start\n'
        'Running --> Idle : stop\n'
        'Running --> Paused : pause\n'
        'Paused --> Running : resume\n'
        'Running --> [*] : crash\n'
        '@enduml\n',
        'state_diagram_basic',
        size: const Size(640, 600),
      );
    });

    testWidgets('state diagram composite with concurrent regions',
        (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '[*] --> Authenticated\n'
        'state Authenticated {\n'
        '  [*] --> Browsing\n'
        '  Browsing --> Editing : edit\n'
        '  Editing --> Browsing : save\n'
        '}\n'
        'state Composite {\n'
        '  [*] --> A\n'
        '  A --> B\n'
        '  --\n'
        '  [*] --> C\n'
        '  C --> D\n'
        '}\n'
        '@enduml\n',
        'state_diagram_composite',
        size: const Size(720, 720),
      );
    });

    testWidgets('component diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'component "Web Server" as Web\n'
        'interface "HTTP API" as HTTP\n'
        '() "REST" as REST\n'
        '\n'
        'package "Backend" {\n'
        '  [Service A]\n'
        '  [Service B]\n'
        '}\n'
        '\n'
        'node "Server 1" {\n'
        '  [Process]\n'
        '}\n'
        '\n'
        'cloud "AWS" {\n'
        '  [Lambda]\n'
        '}\n'
        '\n'
        'Web --> HTTP\n'
        'HTTP ..> REST : uses\n'
        '@enduml\n',
        'component_diagram',
        size: const Size(900, 800),
      );
    });

    testWidgets('component diagram with database and queue', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'package "Backend" {\n'
        '  [Order Service]\n'
        '  [Payment Adapter]\n'
        '}\n'
        'cloud "Payment Gateway" as PG\n'
        'database "Orders DB" as ODB\n'
        'queue "Events" as EVQ\n'
        '\n'
        '[Order Service] --> [Payment Adapter]\n'
        '[Payment Adapter] --> PG\n'
        '[Order Service] --> ODB\n'
        '[Order Service] --> EVQ\n'
        '@enduml\n',
        'component_db_queue',
        size: const Size(900, 700),
      );
    });

    testWidgets('deployment diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'node "Web Server" {\n'
        '  component Apache\n'
        '  artifact "config.yml" as Config\n'
        '}\n'
        '\n'
        'node "Database Server" {\n'
        '  [PostgreSQL]\n'
        '}\n'
        '\n'
        'cloud "AWS" {\n'
        '  [Lambda]\n'
        '}\n'
        '\n'
        'Apache --> PostgreSQL\n'
        'Apache --> Config\n'
        '@enduml\n',
        'deployment_diagram',
        size: const Size(900, 700),
      );
    });

    testWidgets('timing diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'robust "Web Browser" as WB\n'
        'concise "User"\n'
        '\n'
        '@0\n'
        'User is Idle\n'
        'WB is Idle\n'
        '\n'
        '@100\n'
        'User -> WB : open\n'
        'WB is Loading\n'
        'User is Waiting\n'
        '\n'
        '@300\n'
        'WB is Loaded\n'
        'User is Reading\n'
        '\n'
        '@500\n'
        'User is Idle\n'
        'WB is Idle\n'
        '@enduml\n',
        'timing_diagram',
        size: const Size(720, 360),
      );
    });

    testWidgets('mindmap', (tester) async {
      await expectPumlGolden(
        tester,
        '@startmindmap\n'
        '* Root\n'
        '-** Left Branch\n'
        '-*** Left Sub 1\n'
        '-*** Left Sub 2\n'
        '+** Right Branch\n'
        '+*** Right Sub 1\n'
        '@endmindmap\n',
        'mindmap',
        size: const Size(720, 360),
      );
    });

    testWidgets('wbs diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startwbs\n'
        '* Business Plan\n'
        '** Goals\n'
        '*** Increase sales\n'
        '*** Reduce costs\n'
        '** Risks\n'
        '*** Market risk\n'
        '*** Operational risk\n'
        '** Schedule\n'
        '@endwbs\n',
        'wbs_diagram',
        size: const Size(720, 360),
      );
    });

    testWidgets('json data diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startjson\n'
        '{\n'
        '  "name": "Alice",\n'
        '  "age": 30,\n'
        '  "active": true,\n'
        '  "tags": ["admin", "user"],\n'
        '  "address": {\n'
        '    "city": "Seoul",\n'
        '    "zip": "12345"\n'
        '  },\n'
        '  "ref": null\n'
        '}\n'
        '@endjson\n',
        'json_diagram',
        size: const Size(720, 480),
      );
    });

    testWidgets('salt wireframe diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startsalt\n'
        '{\n'
        '  Name | "Alice"\n'
        '  Age  | "30"\n'
        '  [Submit] | [Cancel]\n'
        '  (X) Option 1\n'
        '  ( ) Option 2\n'
        '  [X] Checked\n'
        '  [ ] Unchecked\n'
        '  --\n'
        '  Done\n'
        '}\n'
        '@endsalt\n',
        'salt_wireframe',
        size: const Size(640, 480),
      );
    });

    testWidgets('yaml data diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startyaml\n'
        'name: Alice\n'
        'age: 30\n'
        'active: true\n'
        'tags:\n'
        '  - admin\n'
        '  - user\n'
        'address:\n'
        '  city: Seoul\n'
        '  zip: "12345"\n'
        '@endyaml\n',
        'yaml_diagram',
        size: const Size(720, 480),
      );
    });

    testWidgets('gantt diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startgantt\n'
        'Project starts 2026-01-01\n'
        '[Design] lasts 10 days\n'
        '[Prototype] lasts 14 days\n'
        "[Prototype] starts at [Design]'s end\n"
        '[Implementation] lasts 21 days\n'
        "[Implementation] starts at [Prototype]'s end\n"
        '[Testing] lasts 7 days\n'
        "[Testing] starts at [Implementation]'s end\n"
        '-- Milestone --\n'
        "[Release] happens at [Testing]'s end\n"
        '@endgantt\n',
        'gantt_diagram',
        size: const Size(960, 360),
      );
    });

    testWidgets('network diagram', (tester) async {
      await expectPumlGolden(
        tester,
        '@startnwdiag\n'
        'network dmz {\n'
        '  address = "210.0.0.0/24"\n'
        '  web01 [address = "210.0.0.1"]\n'
        '  web02 [address = "210.0.0.2"]\n'
        '}\n'
        'network internal {\n'
        '  address = "172.0.0.0/24"\n'
        '  web01 [address = "172.0.0.1"]\n'
        '  db01 [address = "172.0.0.100"]\n'
        '}\n'
        '@endnwdiag\n',
        'network_diagram',
        size: const Size(720, 480),
      );
    });

    testWidgets('sequence autoactivate and return', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'autoactivate on\n'
        'alice -> bob : hello\n'
        'bob -> bob : self call\n'
        'bill -> bob #005500 : hello from thread 2\n'
        'bob -> george ** : create\n'
        'return done in thread 2\n'
        'return rc\n'
        'bob -> george !! : delete\n'
        'return success\n'
        '\n'
        '@enduml\n',
        'sequence_autoactivate_return',
        size: const Size(800, 700),
      );
    });

    testWidgets('sequence chained deactivate activate', (tester) async {
      // Verbatim source from the bug report: extra whitespace gaps between
      // tokens (must be tolerated by the lexer/parser) and a chained `--++`
      // suffix that simultaneously deactivates the source (bob) and
      // activates the target (charlie). The trailing `--` on the third line
      // deactivates charlie.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'alice   ->  bob     ++   : hello1\n'
        'bob     ->  charlie --++ : hello2\n'
        'charlie --> alice   --   : ok\n'
        '@enduml\n',
        'sequence_chained_deactivate_activate',
        size: const Size(600, 400),
      );
    });

    testWidgets('sequence explicit activation create destroy', (tester) async {
      // Same shape as the autoactivate golden but every call opts in via an
      // explicit `++` / `**` / `!!` suffix instead of `autoactivate on`. This
      // verifies the explicit-suffix push-onto-callstack path, color after
      // suffix (double space tolerated), and chained `return` unwinding.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'alice -> bob ++ : hello\n'
        'bob -> bob ++ : self call\n'
        'bob -> bib ++  #005500 : hello\n'
        'bob -> george ** : create\n'
        'return done\n'
        'return rc\n'
        'bob -> george !! : delete\n'
        'return success\n'
        '@enduml\n',
        'sequence_explicit_activation_create_destroy',
        size: const Size(800, 700),
      );
    });

    testWidgets('sequence activate with color', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant User\n'
        '\n'
        'User -> A: DoWork\n'
        'activate A #FFBBBB\n'
        '\n'
        'A -> A: Internal call\n'
        'activate A #DarkSalmon\n'
        '\n'
        'A -> B: << createRequest >>\n'
        'activate B\n'
        '\n'
        'B --> A: RequestCreated\n'
        'deactivate B\n'
        'deactivate A\n'
        'A -> User: Done\n'
        'deactivate A\n'
        '\n'
        '@enduml\n',
        'sequence_activate_color',
        size: const Size(700, 700),
      );
    });

    testWidgets('sequence delay separators', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '\n'
        'Alice -> Bob: message 1\n'
        'Bob --> Alice: ok\n'
        '|||\n'
        'Alice -> Bob: message 2\n'
        'Bob --> Alice: ok\n'
        '||45||\n'
        'Alice -> Bob: message 3\n'
        'Bob --> Alice: ok\n'
        '\n'
        '@enduml\n',
        'sequence_delay_separators',
        size: const Size(600, 600),
      );
    });

    testWidgets('sequence creole inline markup', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Alice\n'
        'participant "The **Famous** Bob" as Bob\n'
        '\n'
        'Alice -> Bob : hello --there--\n'
        '... Some ~~long delay~~ ...\n'
        'Bob -> Alice : ok\n'
        'note left\n'
        '  This is **bold**\n'
        '  This is //italics//\n'
        '  This is ""monospaced""\n'
        '  This is --stroked--\n'
        '  This is __underlined__\n'
        '  This is ~~waved~~\n'
        'end note\n'
        '\n'
        'Alice -> Bob : A //well formatted// message\n'
        '@enduml\n',
        'sequence_creole_markup',
        size: const Size(700, 600),
      );
    });

    testWidgets('sequence advanced markup', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Alice\n'
        'participant Bob\n'
        '\n'
        'note right of Alice\n'
        ' This is <back:cadetblue><size:18>displayed</size></back>\n'
        ' __left of__ Alice.\n'
        'end note\n'
        'note left of Bob\n'
        ' <u:red>This</u> is <color #118888>displayed</color>\n'
        ' **<color purple>left of</color> <s:red>Alice</strike> Bob**.\n'
        'end note\n'
        'note over Alice, Bob\n'
        ' <w:#FF33FF>This is hosted</w> by <img sourceforge.jpg>\n'
        'end note\n'
        '@enduml\n',
        'sequence_advanced_markup',
        size: const Size(700, 600),
      );
    });

    testWidgets('sequence combined creole and html markup', (tester) async {
      // Mirrors the verbatim bug-report source: a single diagram that mixes
      // creole shorthand (`**bold**`, `//italics//`, `""monospace""`,
      // `--strike--`, `__under__`, `~~wave~~`) with HTML-like tags
      // (`<back:cadetblue>`, `<size:18>`, `<color #hex>`, `<color name>`,
      // `<u:red>`, `<s:red>...</strike>`, `<w:#hex>`, `<img:URL>`).
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Alice\n'
        'participant "The **Famous** Bob" as Bob\n'
        'Alice -> Bob : hello --there--\n'
        'Bob -> Alice : ok\n'
        'note left\n'
        'This is **bold**\n'
        'This is //italics//\n'
        'This is ""monospaced""\n'
        'This is --stroked--\n'
        'This is __underlined__\n'
        'This is ~~waved~~\n'
        'end note\n'
        'Alice -> Bob : A //well formatted// message\n'
        'note right of Alice\n'
        'This is <back:cadetblue><size:18>displayed</size></back>\n'
        '__left of__ Alice.\n'
        'end note\n'
        'note left of Bob\n'
        '<u:red>This</u> is <color #118888>displayed</color>\n'
        '**<color purple>left of</color> <s:red>Alice</strike> Bob**.\n'
        'end note\n'
        'note over Alice, Bob\n'
        '<w:#FF33FF>This is hosted</w> by <img:https://plantuml.com/sourceforge.jpg>\n'
        'end note\n'
        '@enduml\n',
        'sequence_combined_creole_html_markup',
        size: const Size(700, 800),
      );
    });

    testWidgets('sequence partition as group', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant a\n'
        '\n'
        'partition p1\n'
        'b -> c: msg\n'
        'c --> b: OK\n'
        'note right: Some right note\n'
        'end\n'
        '\n'
        'partition p2\n'
        'a -> b: msg\n'
        'note left: Some left note\n'
        'end\n'
        '@enduml\n',
        'sequence_partition_groups',
        size: const Size(700, 700),
      );
    });

    testWidgets('sequence newpage with title', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '\n'
        'Alice -> Bob : message 1\n'
        'Alice -> Bob : message 2\n'
        '\n'
        'newpage\n'
        '\n'
        'Alice -> Bob : message 3\n'
        'Alice -> Bob : message 4\n'
        '\n'
        'newpage A title for the\\nlast page\n'
        '\n'
        'Alice -> Bob : message 5\n'
        'Alice -> Bob : message 6\n'
        '@enduml\n',
        'sequence_newpage_titles',
        size: const Size(600, 900),
      );
    });

    testWidgets('sequence header footer page placeholders', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '\n'
        'header Page Header\n'
        'footer Page %page% of %lastpage%\n'
        '\n'
        'title Example Title\n'
        '\n'
        'Alice -> Bob : message 1\n'
        'Alice -> Bob : message 2\n'
        '\n'
        '@enduml\n',
        'sequence_header_footer',
        size: const Size(600, 400),
      );
    });

    testWidgets('sequence autonumber stop resume format', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'autonumber 10 10 "<b>[000]"\n'
        'Bob -> Alice : Authentication Request\n'
        'Bob <- Alice : Authentication Response\n'
        '\n'
        'autonumber stop\n'
        'Bob -> Alice : dummy\n'
        '\n'
        'autonumber resume "<font color=red><b>Message 0  "\n'
        'Bob -> Alice : Yet another authentication Request\n'
        'Bob <- Alice : Yet another authentication Response\n'
        '\n'
        'autonumber stop\n'
        'Bob -> Alice : dummy\n'
        '\n'
        'autonumber resume 1 "<font color=blue><b>Message 0  "\n'
        'Bob -> Alice : Yet another authentication Request\n'
        'Bob <- Alice : Yet another authentication Response\n'
        '@enduml\n',
        'sequence_autonumber_stop_resume',
        size: const Size(900, 700),
      );
    });

    testWidgets('sequence autonumber multi-level inc', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'autonumber 1.1.1\n'
        'Alice -> Bob: Authentication request\n'
        'Bob --> Alice: Response\n'
        'autonumber inc A\n'
        'Alice -> Bob: Another authentication request\n'
        'Bob --> Alice: Response\n'
        'autonumber inc B\n'
        'Alice -> Bob: Another authentication request\n'
        'Bob --> Alice: Response\n'
        'autonumber inc A\n'
        'Alice -> Bob: Another authentication request\n'
        'autonumber inc B\n'
        'Bob --> Alice: Response\n'
        '@enduml\n',
        'sequence_autonumber_multilevel',
        size: const Size(800, 700),
      );
    });

    testWidgets('sequence note positions with colors', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Alice\n'
        'participant Bob\n'
        'note left of Alice #aqua\n'
        'This is displayed\n'
        'left of Alice.\n'
        'end note\n'
        '\n'
        'note right of Alice: This is displayed right of Alice.\n'
        '\n'
        'note over Alice: This is displayed over Alice.\n'
        '\n'
        'note over Alice, Bob #FFAAAA: This is displayed\\n over Bob and Alice.\n'
        '\n'
        'note over Bob, Alice\n'
        'This is yet another\n'
        'example of\n'
        'a long note.\n'
        'end note\n'
        '@enduml\n',
        'sequence_note_positions',
        size: const Size(700, 900),
      );
    });

    testWidgets('sequence alt else group loop nested', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Alice -> Bob: Authentication Request\n'
        '\n'
        'alt successful case\n'
        '    Bob -> Alice: Authentication Accepted\n'
        'else some kind of failure\n'
        '    Bob -> Alice: Authentication Failure\n'
        '    group My own label\n'
        '    Alice -> Log : Log attack start\n'
        '        loop 1000 times\n'
        '            Alice -> Bob: DNS Attack\n'
        '        end\n'
        '    Alice -> Log : Log attack end\n'
        '    end\n'
        'else Another type of failure\n'
        '   Bob -> Alice: Please repeat\n'
        'end\n'
        '@enduml\n',
        'sequence_alt_group_loop',
        size: const Size(800, 700),
      );
    });

    testWidgets('sequence alt else colors', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Alice -> Bob: Authentication Request\n'
        'alt#Gold #LightBlue Successful case\n'
        '    Bob -> Alice: Authentication Accepted\n'
        'else #Pink Failure\n'
        '    Bob -> Alice: Authentication Rejected\n'
        'end\n'
        '@enduml\n',
        'sequence_alt_else_colors',
        size: const Size(700, 400),
      );
    });

    testWidgets('sequence autonumber format strings', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'autonumber "<b>[000]"\n'
        'Bob -> Alice : Authentication Request\n'
        'Bob <- Alice : Authentication Response\n'
        '\n'
        'autonumber 15 "<b>(<u>##</u>)"\n'
        'Bob -> Alice : Another authentication Request\n'
        'Bob <- Alice : Another authentication Response\n'
        '\n'
        'autonumber 40 10 "<font color=red><b>Message 0  "\n'
        'Bob -> Alice : Yet another authentication Request\n'
        'Bob <- Alice : Yet another authentication Response\n'
        '@enduml\n',
        'sequence_autonumber_formats',
        size: const Size(800, 600),
      );
    });

    testWidgets('sequence autonumber and note no target', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'autonumber 10\n'
        'Alice -> Bob\n'
        'note right\n'
        '  the %autonumber% works everywhere.\n'
        '  Here, its value is ** %autonumber% **\n'
        'end note\n'
        'Bob --> Alice: //This is the response %autonumber%//\n'
        '@enduml\n',
        'sequence_autonumber_note',
        size: const Size(700, 500),
      );
    });

    testWidgets('sequence inline note right position', (tester) async {
      // Regression: a `note right` without `of <participant>` immediately
      // following a message should attach near that message's arrow Y, not
      // float halfway between consecutive arrows.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'autonumber 10\n'
        'Alice -> Bob\n'
        'note right\n'
        'the %autonumber% works everywhere.\n'
        'Here, its value is ** %autonumber% **\n'
        'end note\n'
        'Bob --> Alice: //This is the response %autonumber%//\n'
        '@enduml\n',
        'sequence_inline_note_right_position',
        size: const Size(700, 500),
      );
    });

    testWidgets('sequence colored arrows', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Bob -[#red]> Alice : hello\n'
        'Alice -[#0000FF]->Bob : ok\n'
        '@enduml\n',
        'sequence_colored_arrows',
        size: const Size(500, 350),
      );
    });

    testWidgets('sequence hide footbox directive', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'skinparam actorStyle awesome\n'
        'actor Alice\n'
        'actor Bob\n'
        'Alice -> Bob : hello\n'
        'hide footbox\n'
        '@enduml\n',
        'sequence_hide_footbox',
        size: const Size(500, 300),
      );
    });

    testWidgets('sequence hide unlinked drops Carol', (tester) async {
      // Carol has no incoming or outgoing messages, so `hide unlinked`
      // must filter her out — no header box, no lifeline, no footer box.
      // The golden should look identical to a two-participant Alice/Bob
      // diagram even though Carol is declared in the source.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '  hide unlinked\n'
        '  participant Alice\n'
        '  participant Bob\n'
        '  participant Carol\n'
        '\n'
        '  Alice -> Bob : hello\n'
        '@enduml\n',
        'sequence_hide_unlinked',
        size: const Size(500, 300),
      );
    });

    testWidgets('sequence mainframe wraps diagram in a labeled UML frame',
        (tester) async {
      // `mainframe <label>` draws an outer rectangle around the whole
      // diagram with a folded-corner tab in the top-left containing the
      // label. Inline markup like `**mainframe**` renders bold inside the
      // tab.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'mainframe This is a **mainframe**\n'
        'Alice->Bob : Hello\n'
        '@enduml\n',
        'sequence_mainframe',
        size: const Size(500, 300),
      );
    });

    testWidgets('sequence self message backward direction', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Alice <- Alice: This is a signal to self.\\nIt also demonstrates\\nmultiline \\ntext\n'
        '@enduml\n',
        'sequence_self_backward',
        size: const Size(500, 400),
      );
    });

    testWidgets('sequence multiline self message', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Alice -> Alice: This is a signal to self.\\nIt also demonstrates\\nmultiline \\ntext\n'
        '@enduml\n',
        'sequence_self_multiline',
        size: const Size(500, 400),
      );
    });

    testWidgets('sequence quoted participants and as alias', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Alice -> "Bob()" : Hello\n'
        '"Bob()" -> "This is very\\nlong" as Long\n'
        'Long --> "Bob()" : ok\n'
        '@enduml\n',
        'sequence_quoted_participants',
        size: const Size(700, 350),
      );
    });

    testWidgets('sequence participant rich label', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Participant [\n'
        '    =Title\n'
        '    ----\n'
        '    ""SubTitle""\n'
        ']\n'
        '\n'
        'participant Bob\n'
        '\n'
        'Participant -> Bob\n'
        '@enduml\n',
        'sequence_rich_label',
        size: const Size(600, 300),
      );
    });

    testWidgets('sequence inline actor declarations', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '\n'
        ':First Actor:\n'
        ':Another\\nactor: as Man2\n'
        'actor Woman3\n'
        'actor :Last actor: as Person1\n'
        '\n'
        '@enduml\n',
        'sequence_inline_actor_declarations',
        size: const Size(700, 350),
      );
    });

    testWidgets('sequence participant order directive', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Last order 30\n'
        'participant Middle order 20\n'
        'participant First order 10\n'
        '@enduml\n',
        'sequence_order_directive',
        size: const Size(500, 250),
      );
    });

    testWidgets('sequence participant colors and comments', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'actor Bob #red\n'
        "' The only difference between actor\n"
        "'and participant is the drawing\n"
        'participant Alice\n'
        'participant "I have a really\\nlong name" as L #99FF99\n'
        "/' You can also declare:\n"
        '   participant L as "I have a really\\nlong name"  #99FF99\n'
        "  '/\n"
        '\n'
        'Alice->Bob: Authentication Request\n'
        'Bob->Alice: Authentication Response\n'
        'Bob->L: Log transaction\n'
        '@enduml\n',
        'sequence_with_colors',
        size: const Size(800, 400),
      );
    });

    testWidgets('sequence arrow variants', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Bob ->x Alice\n'
        'Bob -> Alice\n'
        'Bob ->> Alice\n'
        'Bob -\\ Alice\n'
        'Bob \\\\- Alice\n'
        'Bob //-- Alice\n'
        '\n'
        'Bob ->o Alice\n'
        'Bob o\\\\-- Alice\n'
        '\n'
        'Bob <-> Alice\n'
        'Bob <->o Alice\n'
        '@enduml\n',
        'sequence_arrow_variants',
        size: const Size(600, 700),
      );
    });

    testWidgets('sequence arrow head variants — all 20 PlantUML forms',
        (tester) async {
      // Exercises every head/tail decoration combination used by PlantUML
      // sequence syntax: leading `o` / `x` (tail decoration), trailing
      // `o` / `x` (head decoration), `>` / `>>` head triangles, `\` / `/`
      // half-arrows, and bidirectional `<->`. Regression coverage for the
      // four lexer bugs (`o->o`, `o<->o`, `x<->x`, `x->o`) and the asymmetric
      // tail/head decoded by the parser.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Alice as a\n'
        'participant Bob   as b\n'
        'a ->     b : ""->   ""\n'
        'a ->>    b : ""->>  ""\n'
        'a -\\     b : ""-\\   ""\n'
        'a -\\\\    b : ""-\\\\\\\\""\n'
        'a -/     b : ""-/   ""\n'
        'a -//    b : ""-//  ""\n'
        'a ->x    b : ""->x  ""\n'
        'a x->    b : ""x->  ""\n'
        'a o->    b : ""o->  ""\n'
        'a ->o    b : ""->o  ""\n'
        'a o->o   b : ""o->o ""\n'
        'a <->    b : ""<->  ""\n'
        'a o<->o  b : ""o<->o""\n'
        'a x<->x  b : ""x<->x""\n'
        'a ->>o   b : ""->>o ""\n'
        'a -\\o    b : ""-\\o  ""\n'
        'a -\\\\o   b : ""-\\\\\\\\o""\n'
        'a -/o    b : ""-/o  ""\n'
        'a -//o   b : ""-//o ""\n'
        'a x->o   b : ""x->o ""\n'
        '@enduml\n',
        'sequence_arrow_head_variants',
        size: const Size(560, 880),
      );
    });

    testWidgets('sequence found / lost messages', (tester) async {
      // Exercises all four anonymous-endpoint forms (`?->`, `[->`, `->]`,
      // `->?`) plus the `""verbatim""` + `**bold**` + `\n` label markup that
      // is rendered alongside them.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '?-> Alice    : ""?->""\\n**short** to actor1\n'
        '[-> Alice    : ""[->""\\n**from start** to actor1\n'
        '[-> Bob      : ""[->""\\n**from start** to actor2\n'
        '?-> Bob      : ""?->""\\n**short** to actor2\n'
        'Alice ->]    : ""->]""\\nfrom actor1 **to end**\n'
        'Alice ->?    : ""->?""\\n**short** from actor1\n'
        'Alice -> Bob : ""->"" \\nfrom actor1 to actor2\n'
        '@enduml\n',
        'sequence_found_lost_messages',
        size: const Size(640, 520),
      );
    });

    testWidgets('sequence arrow variants with lost endpoint',
        (tester) async {
      // Verbatim source from the bug report: 20 arrow-head/tail variants
      // each terminated by a short-lost `?` stub, plus one full arrow with
      // an italic label. Before the fix the lexer rejected `-\?`, `o->o?`,
      // `<->?`, etc. — the lost-endpoint scan composed badly with the
      // `o`/`x` head-cap and half-arrow body scans. This golden locks in
      // the rendered output for the verbatim user-supplied source.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Alice as a\n'
        'participant Bob   as b\n'
        'a ->     b : //Long long label//\n'
        'a ->?      : ""->?   ""\n'
        'a ->>?     : ""->>?  ""\n'
        'a -\\?      : ""-\\?   ""\n'
        'a -\\\\?     : ""-\\\\\\\\?""\n'
        'a -/?      : ""-/?   ""\n'
        'a -//?     : ""-//?  ""\n'
        'a ->x?     : ""->x?  ""\n'
        'a x->?     : ""x->?  ""\n'
        'a o->?     : ""o->?  ""\n'
        'a ->o?     : ""->o?  ""\n'
        'a o->o?    : ""o->o? ""\n'
        'a <->?     : ""<->?  ""\n'
        'a o<->o?   : ""o<->o?""\n'
        'a x<->x?   : ""x<->x?""\n'
        'a ->>o?    : ""->>o? ""\n'
        'a -\\o?     : ""-\\o?  ""\n'
        'a -\\\\o?    : ""-\\\\\\\\o?""\n'
        'a -/o?     : ""-/o?  ""\n'
        'a -//o?    : ""-//o? ""\n'
        'a x->o?    : ""x->o? ""\n'
        '@enduml\n',
        'sequence_arrow_variants_with_lost_endpoint',
        size: const Size(560, 920),
      );
    });

    testWidgets('sequence arrow variants with found endpoint',
        (tester) async {
      // Verbatim source from the user bug report (Case B): 20 arrow-head/tail
      // variants each preceded by a short-found `?` stub on the LEFT, plus
      // one full arrow with an italic label. Before the fix the lexer
      // rejected `?-\`, `?o->o`, `?x<->x`, etc. — the found-endpoint scan
      // didn't accept leading `o`/`x` tail decorations or half-arrow body
      // endings without a `>` head. This golden locks in the rendered output
      // for the verbatim user-supplied source.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Alice as a\n'
        'participant Bob   as b\n'
        'a ->     b : //Long long label//\n'
        '?->      b : ""?->   ""\n'
        '?->>     b : ""?->>  ""\n'
        '?-\\      b : ""?-\\   ""\n'
        '?-\\\\     b : ""?-\\\\\\\\""\n'
        '?-/      b : ""?-/   ""\n'
        '?-//     b : ""?-//  ""\n'
        '?->x     b : ""?->x  ""\n'
        '?x->     b : ""?x->  ""\n'
        '?o->     b : ""?o->  ""\n'
        '?->o     b : ""?->o  ""\n'
        '?o->o    b : ""?o->o ""\n'
        '?<->     b : ""?<->  ""\n'
        '?o<->o   b : ""?o<->o""\n'
        '?x<->x   b : ""?x<->x""\n'
        '?->>o    b : ""?->>o ""\n'
        '?-\\o     b : ""?-\\o  ""\n'
        '?-\\\\o    b : ""?-\\\\\\\\o ""\n'
        '?-/o     b : ""?-/o  ""\n'
        '?-//o    b : ""?-//o ""\n'
        '?x->o    b : ""?x->o ""\n'
        '@enduml\n',
        'sequence_arrow_variants_with_found_endpoint',
        size: const Size(560, 920),
      );
    });

    testWidgets('sequence arrow variants with edge-lost endpoint',
        (tester) async {
      // Verbatim source from the user bug report (Case C): 20 arrow-head/tail
      // variants each terminated by an edge-lost `]` marker on the RIGHT. The
      // right-side `]` lost-endpoint already lexed and parsed correctly
      // before this task (the prior `consumeLostEnd` helper accepted both
      // `?` and `]`); this golden ensures it stays that way.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Alice as a\n'
        'participant Bob   as b\n'
        'a ->]      : ""->]   ""\n'
        'a ->>]     : ""->>]  ""\n'
        'a -\\]      : ""-\\]   ""\n'
        'a -\\\\]     : ""-\\\\\\\\]""\n'
        'a -/]      : ""-/]   ""\n'
        'a -//]     : ""-//]  ""\n'
        'a ->x]     : ""->x]  ""\n'
        'a x->]     : ""x->]  ""\n'
        'a o->]     : ""o->]  ""\n'
        'a ->o]     : ""->o]  ""\n'
        'a o->o]    : ""o->o] ""\n'
        'a <->]     : ""<->]  ""\n'
        'a o<->o]   : ""o<->o]""\n'
        'a x<->x]   : ""x<->x]""\n'
        'a ->>o]    : ""->>o] ""\n'
        'a -\\o]     : ""-\\o]  ""\n'
        'a -\\\\o]    : ""-\\\\\\\\o]""\n'
        'a -/o]     : ""-/o]  ""\n'
        'a -//o]    : ""-//o] ""\n'
        'a x->o]    : ""x->o] ""\n'
        '@enduml\n',
        'sequence_arrow_variants_with_edge_lost_endpoint',
        size: const Size(560, 920),
      );
    });

    testWidgets('sequence arrow variants with edge-found endpoint',
        (tester) async {
      // Verbatim source from the user bug report (Case D): 20 arrow-head/tail
      // variants each preceded by an edge-found `[` marker on the LEFT.
      // Before the fix the parser rejected `[x->`, `[o->`, `[<->`, `[-\`,
      // etc. — the lexer didn't absorb the leading `[` for head-variant
      // forms, and the parser's `_isArrowHeadOrBodyChar` didn't include
      // `o`/`x` as valid first chars after `[`. This golden locks in the
      // rendered output for the verbatim user-supplied source.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant Alice as a\n'
        'participant Bob   as b\n'
        '[->      b : ""[->   ""\n'
        '[->>     b : ""[->>  ""\n'
        '[-\\      b : ""[-\\   ""\n'
        '[-\\\\     b : ""[-\\\\\\\\""\n'
        '[-/      b : ""[-/   ""\n'
        '[-//     b : ""[-//  ""\n'
        '[->x     b : ""[->x  ""\n'
        '[x->     b : ""[x->  ""\n'
        '[o->     b : ""[o->  ""\n'
        '[->o     b : ""[->o  ""\n'
        '[o->o    b : ""[o->o ""\n'
        '[<->     b : ""[<->  ""\n'
        '[o<->o   b : ""[o<->o""\n'
        '[x<->x   b : ""[x<->x""\n'
        '[->>o    b : ""[->>o ""\n'
        '[-\\o     b : ""[-\\o  ""\n'
        '[-\\\\o    b : ""[-\\\\\\\\o""\n'
        '[-/o     b : ""[-/o  ""\n'
        '[-//o    b : ""[-//o ""\n'
        '[x->o    b : ""[x->o ""\n'
        '@enduml\n',
        'sequence_arrow_variants_with_edge_found_endpoint',
        size: const Size(560, 920),
      );
    });

    testWidgets('class relations extended arrow heads', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Class21 #-- Class22\n'
        'Class23 x-- Class24\n'
        'Class25 }-- Class26\n'
        'Class27 +-- Class28\n'
        'Class29 ^-- Class30\n'
        '@enduml\n',
        'class_relations_extended',
        size: const Size(1100, 250),
      );
    });

    testWidgets('class relations implicit declarations', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'Class01 <|-- Class02\n'
        'Class03 *-- Class04\n'
        'Class05 o-- Class06\n'
        'Class07 .. Class08\n'
        'Class09 -- Class10\n'
        '@enduml\n',
        'class_relations_implicit',
        size: const Size(1100, 250),
      );
    });

    testWidgets('class diagram kinds gallery', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'hide empty members\n'
        'abstract        abstract\n'
        'abstract class  "abstract class"\n'
        'annotation      annotation\n'
        'circle          circle\n'
        '()              circle_short_form\n'
        'class           class\n'
        'class           class_stereo  <<stereotype>>\n'
        'dataclass       dataclass\n'
        'diamond         diamond\n'
        '<>              diamond_short_form\n'
        'entity          entity\n'
        'enum            enum\n'
        'exception       exception\n'
        'interface       interface\n'
        'metaclass       metaclass\n'
        'protocol        protocol\n'
        'record          record\n'
        'stereotype      stereotype\n'
        'struct          struct\n'
        '@enduml\n',
        'class_diagram_kinds',
        size: const Size(3300, 200),
      );
    });

    testWidgets('explicit participant order with display name', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'participant "Web Client" as W\n'
        'participant "API Server" as S\n'
        'participant Database as DB\n'
        'W -> S : POST /login\n'
        'S -> DB : SELECT user\n'
        'DB --> S : row\n'
        'S --> W : 200 OK\n'
        '@enduml\n',
        'participant_declarations',
      );
    });

    testWidgets('sequence nested box with pragma', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '\n'
        '!pragma teoz true\n'
        'box "Internal Service" #LightBlue\n'
        'participant Bob\n'
        'box "Subteam"\n'
        'participant Alice\n'
        'participant John\n'
        'end box\n'
        '\n'
        'end box\n'
        'participant Other\n'
        '\n'
        'Bob -> Alice : hello\n'
        'Alice -> John : hello\n'
        'John -> Other: Hello\n'
        '\n'
        '@enduml\n',
        'sequence_nested_box_pragma',
        size: const Size(720, 360),
      );
    });

    testWidgets('sequence arrow duration basic', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A ->(10) B: text 10\n'
        'B ->(10) A: text 10\n'
        '\n'
        'A ->(10) B: text 10\n'
        'A (10)<- B: text 10\n'
        '@enduml\n',
        'sequence_arrow_duration_basic',
      );
    });

    testWidgets('sequence arrow duration with activation', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        'A ->(40) B++: Rq\n'
        'B -->(20) A--: Rs\n'
        '@enduml\n',
        'sequence_arrow_duration_with_activation',
      );
    });

    testWidgets('sequence arrow duration with sync', (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        "!pragma teoz true\n"
        "A ->(50) C: Starts\\nwhen 'B' sends\n"
        "& B ->(25) C: \\nBut B's message\\n arrives before A's\n"
        '@enduml\n',
        'sequence_arrow_duration_with_sync',
      );
    });

    testWidgets('sequence with <style> block and ... delay marker',
        (tester) async {
      // Verbatim user repro: a `<style>...</style>` block (consumed and
      // ignored — style application is deferred) followed by a forward
      // message, a `...` delay break, and a reverse message.
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '<style>\n'
        'lifeLine {\n'
        '  LineStyle 0\n'
        '}\n'
        'delay {\n'
        '  LineStyle 1-4\n'
        '}\n'
        '</style>\n'
        'Alice -> Bob : hello\n'
        '...\n'
        'Alice <- Bob : hello\n'
        '@enduml\n',
        'sequence_style_block_and_delay',
        size: const Size(400, 320),
      );
    });

    testWidgets('activity diagram with SALT procedure-call nodes',
        (tester) async {
      await expectPumlGolden(
        tester,
        '@startuml\n'
        '!unquoted procedure SALT(\$x)\n'
        '"{{salt %invoke_procedure("_"+\$x) }}" as \$x\n'
        '!endprocedure\n'
        '\n'
        '!procedure _choose()\n'
        '{+\n'
        '<b>an example\n'
        'choose one option\n'
        '()one\n'
        '()two\n'
        '[ok]\n'
        '}\n'
        '!endprocedure\n'
        '\n'
        '!procedure _wait()\n'
        '{+\n'
        '<b>please wait\n'
        'operation in progress <&clock>\n'
        '[cancel]\n'
        '}\n'
        '!endprocedure\n'
        '\n'
        '!procedure _success()\n'
        '{+\n'
        '<b>success\n'
        'congratulations!\n'
        '[ok]\n'
        '}\n'
        '!endprocedure\n'
        '\n'
        '!procedure _error()\n'
        '{+\n'
        '<b>error\n'
        'failed, sorry\n'
        '[ok]\n'
        '}\n'
        '!endprocedure\n'
        '\n'
        '(*) --> SALT(choose) -right-> SALT(wait)\n'
        'wait -right-> SALT(success)\n'
        'wait -down-> SALT(error)\n'
        '@enduml\n',
        'activity_salt_procedure_calls',
        size: const Size(720, 480),
      );
    });
  });
}
