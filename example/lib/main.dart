import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'samples/sample_models.dart';
import 'samples/sequence_samples.dart';
import 'samples/use_case_samples.dart';
import 'samples/class_samples.dart';
import 'samples/activity_samples.dart';
import 'samples/component_samples.dart';
import 'samples/state_samples.dart';
import 'samples/object_samples.dart';
import 'samples/deployment_samples.dart';
import 'samples/timing_samples.dart';
import 'samples/regex_samples.dart';
import 'samples/network_samples.dart';
import 'samples/wireframe_samples.dart';
import 'samples/archimate_samples.dart';
import 'samples/gantt_samples.dart';
import 'samples/mindmap_samples.dart';
import 'samples/wbs_samples.dart';
import 'samples/ebnf_samples.dart';
import 'samples/json_samples.dart';
import 'samples/yaml_samples.dart';
import 'package:puml_canvas/puml_canvas.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _ignoreKnownMacosKeyboardAssertion();
  runApp(const ExampleApp());
}

void _ignoreKnownMacosKeyboardAssertion() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    final isKeyboardStateMismatch =
        message.contains('A KeyUpEvent is dispatched') &&
        message.contains('physical key is pressed on a different logical key');
    if (isKeyboardStateMismatch) return;
    previous?.call(details);
  };
}

const _samples = <SampleDiagram>[
  SampleDiagram(name: 'Sequence',   source: '', subSamples: sequenceSubSamples),
  SampleDiagram(name: 'Use Case',   source: '', subSamples: useCaseSubSamples),
  SampleDiagram(name: 'Class',      source: '', subSamples: classSubSamples),
  SampleDiagram(name: 'Activity',   source: '', subSamples: activitySubSamples),
  SampleDiagram(name: 'Component',  source: '', subSamples: componentSubSamples),
  SampleDiagram(name: 'State',      source: '', subSamples: stateSubSamples),
  SampleDiagram(name: 'Object',     source: '', subSamples: objectSubSamples),
  SampleDiagram(name: 'Deployment', source: '', subSamples: deploymentSubSamples),
  SampleDiagram(name: 'Timing',     source: '', subSamples: timingSubSamples),
  SampleDiagram(name: 'Regex',      source: '', subSamples: regexSubSamples),
  SampleDiagram(name: 'Network',    source: '', subSamples: networkSubSamples),
  SampleDiagram(name: 'Wireframe',  source: '', subSamples: wireframeSubSamples),
  SampleDiagram(name: 'Archimate',  source: '', subSamples: archimateSubSamples),
  SampleDiagram(name: 'Gantt',      source: '', subSamples: ganttSubSamples),
  SampleDiagram(name: 'MindMap',    source: '', subSamples: mindMapSubSamples),
  SampleDiagram(name: 'WBS',        source: '', subSamples: wbsSubSamples),
  SampleDiagram(name: 'EBNF',       source: '', subSamples: ebnfSubSamples),
  SampleDiagram(name: 'JSON',       source: '', subSamples: jsonSubSamples),
  SampleDiagram(name: 'YAML',       source: '', subSamples: yamlSubSamples),
];

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final _controller = TextEditingController(text: _initialSource);
  String _source = _initialSource;
  String _title = _initialTitle;
  String? _selectedSampleName = _samples.first.name;
  Timer? _renderDebounce;

  static String get _initialSource {
    final first = _samples.first;
    if (first.subSamples != null && first.subSamples!.isNotEmpty) {
      return first.subSamples!.first.source;
    }
    return first.source;
  }

  static String get _initialTitle {
    final first = _samples.first;
    if (first.subSamples != null && first.subSamples!.isNotEmpty) {
      return '${first.name}: ${first.subSamples!.first.name}';
    }
    return first.name;
  }

  @override
  void dispose() {
    _renderDebounce?.cancel();
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
      _selectedSampleName = null;
      _setEditorText(source);
    });
  }

  void _loadSample(SampleDiagram sample) {
    final subs = sample.subSamples;
    if (subs != null && subs.isNotEmpty) {
      // Sample with sub-examples: render them all in the scrollable list
      // below; no single source is loaded into the editor.
      setState(() {
        _selectedSampleName = sample.name;
        _title = sample.name;
      });
      return;
    }
    setState(() {
      _selectedSampleName = sample.name;
      _title = sample.name;
      _source = sample.source;
      _setEditorText(sample.source);
    });
  }

  void _setEditorText(String source) {
    _renderDebounce?.cancel();
    _controller.value = TextEditingValue(
      text: source,
      selection: TextSelection.collapsed(offset: source.length),
    );
  }

  void _selectAllText() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _scheduleRender(String value) {
    _renderDebounce?.cancel();
    _renderDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _source = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final SampleDiagram? selectedSample = _selectedSampleName == null
        ? null
        : _samples.firstWhere(
            (s) => s.name == _selectedSampleName,
            orElse: () => _samples.first,
          );
    final showSubSamplesList = selectedSample != null &&
        selectedSample.subSamples != null &&
        selectedSample.subSamples!.isNotEmpty;

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
              selectedSampleName: _selectedSampleName,
              onOpenFile: _openFile,
              onLoadSample: _loadSample,
            ),
            const Divider(height: 1),
            Expanded(
              child: showSubSamplesList
                  ? _SubSamplesList(subs: selectedSample.subSamples!)
                  : _SingleSampleView(
                      controller: _controller,
                      source: _source,
                      onSelectAll: _selectAllText,
                      onChanged: _scheduleRender,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleSampleView extends StatelessWidget {
  const _SingleSampleView({
    required this.controller,
    required this.source,
    required this.onSelectAll,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String source;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.keyA, control: true):
                    onSelectAll,
                const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
                    onSelectAll,
              },
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter PlantUML source',
                ),
                onChanged: onChanged,
              ),
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
              child: PumlView(source: source),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubSamplesList extends StatelessWidget {
  const _SubSamplesList({required this.subs});

  final List<SubSample> subs;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: subs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final sub = subs[index];
        return _SubSampleCard(
          // Key on the source so reloading the demo with new initial source
          // re-creates the card state (controllers, debounce).
          key: ValueKey('${sub.name}#$index'),
          index: index,
          sub: sub,
        );
      },
    );
  }
}

class _SubSampleCard extends StatefulWidget {
  const _SubSampleCard({
    super.key,
    required this.index,
    required this.sub,
  });

  final int index;
  final SubSample sub;

  @override
  State<_SubSampleCard> createState() => _SubSampleCardState();
}

class _SubSampleCardState extends State<_SubSampleCard> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.sub.source);
  late String _source = widget.sub.source;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _source = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '${widget.index + 1}. ${widget.sub.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 900,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.all(8),
                      ),
                      onChanged: _onChanged,
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Container(
                    color: const Color(0xFFFAFAFA),
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: PumlView(source: _source),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.samples,
    required this.selectedSampleName,
    required this.onOpenFile,
    required this.onLoadSample,
  });

  final String title;
  final List<SampleDiagram> samples;
  final String? selectedSampleName;
  final VoidCallback onOpenFile;
  final ValueChanged<SampleDiagram> onLoadSample;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                            selected: selectedSampleName == sample.name,
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
          ],
        ),
      ),
    );
  }
}

