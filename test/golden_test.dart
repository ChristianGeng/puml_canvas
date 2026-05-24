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
        size: const Size(640, 1200),
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
  });
}
