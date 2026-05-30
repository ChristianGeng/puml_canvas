import '../ast/diagram.dart';
import 'activity_layout.dart';
import 'class_layout.dart';
import 'component_layout.dart';
import 'data_layout.dart';
import 'ebnf_layout.dart';
import 'gantt_layout.dart';
import 'graph/state_sugiyama_adapter.dart';
import 'mindmap_layout.dart';
import 'network_layout.dart';
import 'salt_layout.dart';
import 'scene.dart';
import 'sequence_layout.dart';
import 'state_layout.dart';
import 'text_measurer.dart';
import 'timing_layout.dart';
import 'usecase_layout.dart';
import 'wbs_layout.dart';

abstract class DiagramLayout {
  Scene layout(Diagram diagram, TextMeasurer measurer);
}

class AutoLayout implements DiagramLayout {
  /// Opt-in: when true, route state diagrams through the Sugiyama pipeline
  /// in `graph/state_sugiyama_adapter.dart` instead of the legacy
  /// [StateLayout]. Default is false so existing output is byte-identical.
  final bool useSugiyamaForStates;

  const AutoLayout({this.useSugiyamaForStates = false});

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    return switch (diagram) {
      SequenceDiagram() => const SequenceLayout().layout(diagram, measurer),
      ClassDiagram() => const ClassLayout().layout(diagram, measurer),
      UseCaseDiagram() => const UseCaseLayout().layout(diagram, measurer),
      ActivityDiagram() => const ActivityLayout().layout(diagram, measurer),
      StateDiagram() => useSugiyamaForStates
          ? layoutStateDiagramWithSugiyama(diagram, measurer)
          : const StateLayout().layout(diagram, measurer),
      ComponentDiagram() => const ComponentLayout().layout(diagram, measurer),
      TimingDiagram() => const TimingLayout().layout(diagram, measurer),
      MindmapDiagram() => const MindmapLayout().layout(diagram, measurer),
      WbsDiagram() => const WbsLayout().layout(diagram, measurer),
      DataDiagram() => const DataLayout().layout(diagram, measurer),
      SaltDiagram() => const SaltLayout().layout(diagram, measurer),
      GanttDiagram() => const GanttLayout().layout(diagram, measurer),
      NetworkDiagram() => const NetworkLayout().layout(diagram, measurer),
      EbnfDiagram() => const EbnfLayout().layout(diagram, measurer),
    };
  }
}
