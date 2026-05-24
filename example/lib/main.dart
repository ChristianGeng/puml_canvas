import 'package:flutter/material.dart';
import 'package:puml_canvas/puml_canvas.dart';

void main() => runApp(const ExampleApp());

const _sample = '''
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
''';

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});
  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final _controller = TextEditingController(text: _sample);
  String _source = _sample;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'puml_canvas example',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('puml_canvas')),
        body: Row(
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
                  child: PumlView(source: _source),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
