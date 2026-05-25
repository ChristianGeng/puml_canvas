import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:puml_canvas/puml_canvas.dart';

void main() => runApp(const ExampleApp());

const _samples = <_SampleDiagram>[
  _SampleDiagram(
    name: 'Sequence',
    source: '''
@startuml
participant "Web Client" as W
participant "API Server" as S
participant Database as DB

W -> S : POST /login
activate S
S -> DB : SELECT user
activate DB
DB --> S : row
deactivate DB
alt valid credentials
  S -> S : sign JWT
  S --> W : 200 OK
else invalid
  note right of S : log + rate-limit
  S --> W : 401 Unauthorized
end
deactivate S
@enduml
''',
  ),
  _SampleDiagram(
    name: 'Class',
    source: '''
@startuml
class Customer {
  +id: UUID
  +name: String
}

class Order {
  +number: String
  +total(): Money
}

class LineItem {
  +quantity: int
}

Customer "1" --> "*" Order
Order "1" *-- "*" LineItem
@enduml
''',
  ),
  _SampleDiagram(
    name: 'Use Case',
    source: '''
@startuml
left to right direction
actor Customer
actor Admin

rectangle Store {
  Customer --> (Browse catalog)
  Customer --> (Checkout)
  Admin --> (Manage inventory)
  (Checkout) .> (Validate payment) : include
}
@enduml
''',
  ),
  _SampleDiagram(
    name: 'Activity',
    source: '''
@startuml
start
:Receive order;
if (in stock?) then (yes)
  :Reserve item;
  :Charge card;
else (no)
  :Send backorder notice;
endif
:Send confirmation;
stop
@enduml
''',
  ),
  _SampleDiagram(
    name: 'State',
    source: '''
@startuml
[*] --> Draft
Draft --> Review : submit
Review --> Approved : approve
Review --> Draft : request changes
Approved --> Published : publish
Published --> [*]
@enduml
''',
  ),
  _SampleDiagram(
    name: 'Component',
    source: '''
@startuml
component Web
component API
database Postgres
queue Jobs

Web --> API : HTTPS
API --> Postgres : SQL
API --> Jobs : enqueue
@enduml
''',
  ),
];

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final _controller = TextEditingController(text: _samples.first.source);
  String _source = _samples.first.source;
  String _title = _samples.first.name;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFile() async {
    const typeGroup = XTypeGroup(
      label: 'PlantUML',
      extensions: <String>['puml', 'plantuml', 'txt'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return;

    final source = await file.readAsString();
    setState(() {
      _title = file.name;
      _source = source;
      _controller.text = source;
    });
  }

  void _loadSample(_SampleDiagram sample) {
    setState(() {
      _title = sample.name;
      _source = sample.source;
      _controller.text = sample.source;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'puml_canvas example',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('puml_canvas')),
        body: Column(
          children: [
            _Toolbar(
              title: _title,
              samples: _samples,
              onOpenFile: _openFile,
              onLoadSample: _loadSample,
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter PlantUML source',
                        ),
                        onChanged: (value) => setState(() => _source = value),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFFAFAFA),
                      padding: const EdgeInsets.all(12),
                      child: InteractiveViewer(
                        minScale: 0.2,
                        maxScale: 4,
                        child: PumlView(source: _source),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.samples,
    required this.onOpenFile,
    required this.onLoadSample,
  });

  final String title;
  final List<_SampleDiagram> samples;
  final VoidCallback onOpenFile;
  final ValueChanged<_SampleDiagram> onLoadSample;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: onOpenFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open PUML'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final sample in samples)
                      ChoiceChip(
                        label: Text(sample.name),
                        selected: title == sample.name,
                        onSelected: (_) => onLoadSample(sample),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SampleDiagram {
  const _SampleDiagram({required this.name, required this.source});

  final String name;
  final String source;
}
