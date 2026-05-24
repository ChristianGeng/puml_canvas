import 'package:flutter/painting.dart';

sealed class Diagram {
  const Diagram();

  DiagramDecorations get decorations;
}

class DiagramDecorations {
  final String? title;
  final String? caption;
  final HeaderFooter? header;
  final HeaderFooter? footer;
  final Legend? legend;
  final SkinParams skin;

  const DiagramDecorations({
    this.title,
    this.caption,
    this.header,
    this.footer,
    this.legend,
    this.skin = const SkinParams(),
  });
}

class SequenceDiagram extends Diagram {
  final List<Participant> participants;
  final List<SequenceEvent> events;
  final List<ParticipantBox> boxes;
  @override
  final DiagramDecorations decorations;

  const SequenceDiagram({
    this.participants = const [],
    this.events = const [],
    this.boxes = const [],
    this.decorations = const DiagramDecorations(),
  });

  /// Returns participants in the order they should appear left-to-right.
  ///
  /// Boxed participants come first (in box declaration order, then by their
  /// declaration order within each box), followed by any top-level
  /// participants not contained in a box, followed by aliases referenced by
  /// events but not declared anywhere.
  List<Participant> participantsInOrder() {
    final byAlias = <String, Participant>{
      for (final p in participants) p.alias: p,
    };
    final order = <Participant>[];
    final seen = <String>{};

    for (final box in boxes) {
      for (final p in box.participants) {
        if (seen.add(p.alias)) {
          order.add(byAlias[p.alias] ?? p);
        }
      }
    }
    for (final p in participants) {
      if (seen.add(p.alias)) {
        order.add(p);
      }
    }

    void touch(String alias) {
      if (seen.add(alias)) {
        order.add(byAlias[alias] ?? Participant(alias: alias));
      }
    }

    void visit(List<SequenceEvent> list) {
      for (final e in list) {
        switch (e) {
          case Message():
            touch(e.from);
            touch(e.to);
          case Note():
            for (final alias in e.participants) {
              touch(alias);
            }
          case RefBox():
            for (final alias in e.participants) {
              touch(alias);
            }
          case Activate():
            touch(e.participant);
          case Deactivate():
            touch(e.participant);
          case Create():
            touch(e.participant);
          case Destroy():
            touch(e.participant);
          case Group():
            for (final b in e.branches) {
              visit(b.events);
            }
          case Separator():
            break;
          case NewPage():
            break;
        }
      }
    }

    visit(events);
    return order;
  }

  /// Returns the box containing the participant with the given alias, or
  /// null if the participant is not declared inside any box.
  ParticipantBox? boxOf(String alias) {
    for (final box in boxes) {
      for (final p in box.participants) {
        if (p.alias == alias) return box;
      }
    }
    return null;
  }
}

class SkinParams {
  final Color? backgroundColor;
  final double? defaultFontSize;
  final Color? sequenceArrowColor;
  final Color? sequenceLifeLineBackgroundColor;
  final Color? participantBackgroundColor;
  final Color? participantBorderColor;
  final Color? noteBackgroundColor;
  final Color? noteBorderColor;

  const SkinParams({
    this.backgroundColor,
    this.defaultFontSize,
    this.sequenceArrowColor,
    this.sequenceLifeLineBackgroundColor,
    this.participantBackgroundColor,
    this.participantBorderColor,
    this.noteBackgroundColor,
    this.noteBorderColor,
  });

  SkinParams merge(SkinParams other) {
    return SkinParams(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      defaultFontSize: other.defaultFontSize ?? defaultFontSize,
      sequenceArrowColor: other.sequenceArrowColor ?? sequenceArrowColor,
      sequenceLifeLineBackgroundColor: other.sequenceLifeLineBackgroundColor ??
          sequenceLifeLineBackgroundColor,
      participantBackgroundColor:
          other.participantBackgroundColor ?? participantBackgroundColor,
      participantBorderColor:
          other.participantBorderColor ?? participantBorderColor,
      noteBackgroundColor: other.noteBackgroundColor ?? noteBackgroundColor,
      noteBorderColor: other.noteBorderColor ?? noteBorderColor,
    );
  }
}

class HeaderFooter {
  final String text;
  final TextAlign align;
  const HeaderFooter({required this.text, this.align = TextAlign.center});
}

class Legend {
  final String text;
  final TextAlign align;
  const Legend({required this.text, this.align = TextAlign.left});
}

class ParticipantBox {
  final String label;
  final Color? color;
  final List<Participant> participants;

  const ParticipantBox({
    required this.label,
    this.color,
    this.participants = const [],
  });
}

enum ParticipantKind {
  participant,
  actor,
  boundary,
  control,
  entity,
  database,
  collections,
  queue,
}

class Participant {
  final String alias;
  final String? displayName;
  final ParticipantKind kind;

  const Participant({
    required this.alias,
    this.displayName,
    this.kind = ParticipantKind.participant,
  });

  String get label => displayName ?? alias;
}

sealed class SequenceEvent {
  const SequenceEvent();
}

enum LineStyle { solid, dashed }

enum ArrowHead {
  filled,
  open,
  openCircle,
  cross,
  triangle,
  filledDiamond,
  hollowDiamond,
}

enum MessageDirection { forward, backward }

enum ActivationSuffix {
  activateTarget,
  deactivateSource,
  createTarget,
  destroyTarget,
}

class Message extends SequenceEvent {
  final String from;
  final String to;
  final String? label;
  final LineStyle lineStyle;
  final ArrowHead head;
  final MessageDirection direction;
  final bool hidden;
  final Color? color;
  final ActivationSuffix? activation;

  const Message({
    required this.from,
    required this.to,
    this.label,
    this.lineStyle = LineStyle.solid,
    this.head = ArrowHead.filled,
    this.direction = MessageDirection.forward,
    this.hidden = false,
    this.color,
    this.activation,
  });
}

class Activate extends SequenceEvent {
  final String participant;
  const Activate(this.participant);
}

class Deactivate extends SequenceEvent {
  final String participant;
  const Deactivate(this.participant);
}

class Create extends SequenceEvent {
  final String participant;
  const Create(this.participant);
}

class Destroy extends SequenceEvent {
  final String participant;
  const Destroy(this.participant);
}

enum NotePosition { leftOf, rightOf, over }

class Note extends SequenceEvent {
  final NotePosition position;
  final List<String> participants;
  final String text;

  const Note({
    required this.position,
    required this.participants,
    required this.text,
  });
}

class RefBox extends SequenceEvent {
  final List<String> participants;
  final String text;

  const RefBox({
    required this.participants,
    required this.text,
  });
}

enum SeparatorKind { title, delay, skip, dash }

class Separator extends SequenceEvent {
  final SeparatorKind kind;
  final String? label;
  final int? delayPixels;

  const Separator({
    required this.kind,
    this.label,
    this.delayPixels,
  });
}

class NewPage extends SequenceEvent {
  final String? title;
  const NewPage([this.title]);
}

enum GroupKind { alt, opt, loop, par }

class GroupBranch {
  final String? label;
  final List<SequenceEvent> events;
  const GroupBranch({this.label, this.events = const []});
}

class Group extends SequenceEvent {
  final GroupKind kind;
  final List<GroupBranch> branches;
  const Group({required this.kind, required this.branches});
}

class ClassDiagram extends Diagram {
  final List<ClassDecl> classes;
  final List<Relationship> relationships;
  final List<FreeNote> freeNotes;
  @override
  final DiagramDecorations decorations;

  const ClassDiagram({
    this.classes = const [],
    this.relationships = const [],
    this.freeNotes = const [],
    this.decorations = const DiagramDecorations(),
  });
}

class FreeNote {
  final String alias;
  final String text;
  final String? attachedTo;

  const FreeNote({
    required this.alias,
    required this.text,
    this.attachedTo,
  });
}

enum ClassKind {
  class_,
  abstractClass,
  interface,
  enum_,
  annotation,
  exception,
  object_,
  map_,
  entity_,
  record_,
}

enum CrowFoot { one, zeroOrOne, zeroOrMany, oneOrMany }

enum Visibility { public, private, protected, packagePrivate }

enum DividerKind { solid, dashed, doubleLine }

class ClassDecl {
  final String name;
  final ClassKind kind;
  final List<ClassMember> members;
  final String? instanceOf;
  final String? stereotype;
  final String? generics;

  const ClassDecl({
    required this.name,
    this.kind = ClassKind.class_,
    this.members = const [],
    this.instanceOf,
    this.stereotype,
    this.generics,
  });
}

sealed class ClassMember {
  const ClassMember();
}

class Field extends ClassMember {
  final Visibility visibility;
  final bool isStatic;
  final String name;
  final String? type;
  final bool required;
  final String? stereotype;

  const Field({
    required this.name,
    this.visibility = Visibility.public,
    this.isStatic = false,
    this.type,
    this.required = false,
    this.stereotype,
  });
}

class Method extends ClassMember {
  final Visibility visibility;
  final bool isStatic;
  final bool isAbstract;
  final String name;
  final String? signature;
  final String? returnType;

  const Method({
    required this.name,
    this.visibility = Visibility.public,
    this.isStatic = false,
    this.isAbstract = false,
    this.signature,
    this.returnType,
  });
}

class EnumValue extends ClassMember {
  final String name;
  const EnumValue(this.name);
}

class MemberDivider extends ClassMember {
  final DividerKind kind;
  const MemberDivider(this.kind);
}

class Attribute extends ClassMember {
  final String name;
  final String value;
  final bool isMap;

  const Attribute({
    required this.name,
    required this.value,
    this.isMap = false,
  });
}

enum RelationshipKind {
  inheritance,
  realization,
  composition,
  aggregation,
  association,
  directedAssociation,
  dependency,
  link,
}

class Relationship {
  final String from;
  final String to;
  final RelationshipKind kind;
  final String? label;
  final String? fromMultiplicity;
  final String? toMultiplicity;
  final CrowFoot? fromCrowFoot;
  final CrowFoot? toCrowFoot;

  const Relationship({
    required this.from,
    required this.to,
    required this.kind,
    this.label,
    this.fromMultiplicity,
    this.toMultiplicity,
    this.fromCrowFoot,
    this.toCrowFoot,
  });
}

enum UseCaseNodeKind { actor, useCase }

class UseCaseNode {
  final String alias;
  final String label;
  final UseCaseNodeKind kind;

  const UseCaseNode({
    required this.alias,
    required this.label,
    required this.kind,
  });
}

class UseCaseRelation {
  final String from;
  final String to;
  final LineStyle lineStyle;
  final ArrowHead? head;
  final MessageDirection direction;
  final String? label;

  const UseCaseRelation({
    required this.from,
    required this.to,
    this.lineStyle = LineStyle.solid,
    this.head = ArrowHead.open,
    this.direction = MessageDirection.forward,
    this.label,
  });
}

class UseCaseBoundary {
  final String? label;
  final List<String> containedAliases;

  const UseCaseBoundary({
    this.label,
    this.containedAliases = const [],
  });
}

class UseCaseDiagram extends Diagram {
  final List<UseCaseNode> nodes;
  final List<UseCaseRelation> relations;
  final List<UseCaseBoundary> boundaries;
  final bool leftToRightDirection;
  @override
  final DiagramDecorations decorations;

  const UseCaseDiagram({
    this.nodes = const [],
    this.relations = const [],
    this.boundaries = const [],
    this.leftToRightDirection = false,
    this.decorations = const DiagramDecorations(),
  });
}

class ActivityDiagram extends Diagram {
  final List<ActivityNode> nodes;
  @override
  final DiagramDecorations decorations;

  const ActivityDiagram({
    this.nodes = const [],
    this.decorations = const DiagramDecorations(),
  });
}

class ActivityNoteAttachment {
  final NotePosition position;
  final String text;

  const ActivityNoteAttachment({
    required this.position,
    required this.text,
  });
}

sealed class ActivityNode {
  const ActivityNode();
}

class StartNode extends ActivityNode {
  const StartNode();
}

class StopNode extends ActivityNode {
  const StopNode();
}

class EndNode extends ActivityNode {
  const EndNode();
}

class Action extends ActivityNode {
  final String text;
  final ActivityNoteAttachment? note;

  const Action({required this.text, this.note});
}

class IfBranch {
  final String condition;
  final String? thenLabel;
  final List<ActivityNode> body;

  const IfBranch({
    required this.condition,
    this.thenLabel,
    this.body = const [],
  });
}

class IfBlock extends ActivityNode {
  final List<IfBranch> branches;
  final String? elseLabel;
  final List<ActivityNode> elseBody;

  const IfBlock({
    this.branches = const [],
    this.elseLabel,
    this.elseBody = const [],
  });
}

class WhileBlock extends ActivityNode {
  final String condition;
  final String? isLabel;
  final String? endLabel;
  final List<ActivityNode> body;

  const WhileBlock({
    required this.condition,
    this.isLabel,
    this.endLabel,
    this.body = const [],
  });
}

class RepeatBlock extends ActivityNode {
  final List<ActivityNode> body;
  final String? whileCondition;
  final String? isLabel;
  final String? notLabel;

  const RepeatBlock({
    this.body = const [],
    this.whileCondition,
    this.isLabel,
    this.notLabel,
  });
}

class ForkBlock extends ActivityNode {
  final List<List<ActivityNode>> branches;

  const ForkBlock({this.branches = const []});
}

class Partition extends ActivityNode {
  final String name;
  final List<ActivityNode> body;

  const Partition({required this.name, this.body = const []});
}

class Detach extends ActivityNode {
  const Detach();
}

class Break extends ActivityNode {
  const Break();
}

class Kill extends ActivityNode {
  const Kill();
}

class StateDiagram extends Diagram {
  final List<StateDecl> states;
  final List<StateTransition> transitions;
  @override
  final DiagramDecorations decorations;

  const StateDiagram({
    this.states = const [],
    this.transitions = const [],
    this.decorations = const DiagramDecorations(),
  });
}

class StateDecl {
  final String name;
  final String? displayName;
  final List<StateDecl> nestedStates;
  final List<StateTransition> nestedTransitions;
  final List<List<StateDecl>> concurrentRegions;

  const StateDecl({
    required this.name,
    this.displayName,
    this.nestedStates = const [],
    this.nestedTransitions = const [],
    this.concurrentRegions = const [],
  });

  String get label => displayName ?? name;
}

class StateTransition {
  final String from;
  final String to;
  final String? label;

  const StateTransition({
    required this.from,
    required this.to,
    this.label,
  });
}

enum ComponentNodeKind { component, interface, artifact }

class ComponentNode {
  final String alias;
  final String label;
  final ComponentNodeKind kind;

  const ComponentNode({
    required this.alias,
    required this.label,
    required this.kind,
  });
}

enum ContainerKind { package, node, cloud, frame }

class ComponentContainer {
  final String? label;
  final ContainerKind kind;
  final List<String> nodeAliases;
  final List<ComponentContainer> nestedContainers;

  const ComponentContainer({
    this.label,
    required this.kind,
    this.nodeAliases = const [],
    this.nestedContainers = const [],
  });
}

class ComponentRelation {
  final String from;
  final String to;
  final LineStyle lineStyle;
  final ArrowHead? head;
  final MessageDirection direction;
  final String? label;

  const ComponentRelation({
    required this.from,
    required this.to,
    this.lineStyle = LineStyle.solid,
    this.head = ArrowHead.open,
    this.direction = MessageDirection.forward,
    this.label,
  });
}

class ComponentDiagram extends Diagram {
  final List<ComponentNode> nodes;
  final List<ComponentContainer> containers;
  final List<ComponentRelation> relations;
  @override
  final DiagramDecorations decorations;

  const ComponentDiagram({
    this.nodes = const [],
    this.containers = const [],
    this.relations = const [],
    this.decorations = const DiagramDecorations(),
  });
}

enum TimingLaneKind { robust, concise, clock }

class TimingLane {
  final String alias;
  final String label;
  final TimingLaneKind kind;
  final int? clockPeriod;

  const TimingLane({
    required this.alias,
    required this.label,
    required this.kind,
    this.clockPeriod,
  });
}

sealed class TimingEvent {
  final int time;
  const TimingEvent(this.time);
}

class StateChange extends TimingEvent {
  final String lane;
  final String state;

  const StateChange({
    required int time,
    required this.lane,
    required this.state,
  }) : super(time);
}

class TimingArrow extends TimingEvent {
  final String from;
  final String to;
  final String? label;

  const TimingArrow({
    required int time,
    required this.from,
    required this.to,
    this.label,
  }) : super(time);
}

class TimingDiagram extends Diagram {
  final List<TimingLane> lanes;
  final List<TimingEvent> events;
  @override
  final DiagramDecorations decorations;

  const TimingDiagram({
    this.lanes = const [],
    this.events = const [],
    this.decorations = const DiagramDecorations(),
  });
}

enum MindmapSide { auto, left, right }

class MindmapNode {
  final String text;
  final int depth;
  final MindmapSide side;
  final Color? color;
  final List<MindmapNode> children;

  const MindmapNode({
    required this.text,
    required this.depth,
    this.side = MindmapSide.auto,
    this.color,
    this.children = const [],
  });
}

class MindmapDiagram extends Diagram {
  final MindmapNode? root;
  @override
  final DiagramDecorations decorations;

  const MindmapDiagram({
    this.root,
    this.decorations = const DiagramDecorations(),
  });
}

class WbsDiagram extends Diagram {
  final MindmapNode? root;
  @override
  final DiagramDecorations decorations;

  const WbsDiagram({
    this.root,
    this.decorations = const DiagramDecorations(),
  });
}

enum DataFormat { json, yaml }

enum ScalarKind { string, number, boolean, null_ }

sealed class DataNode {
  const DataNode();
}

class DataObject extends DataNode {
  final List<MapEntry<String, DataNode>> entries;
  const DataObject(this.entries);
}

class DataArray extends DataNode {
  final List<DataNode> items;
  const DataArray(this.items);
}

class DataScalar extends DataNode {
  final String value;
  final ScalarKind kind;
  const DataScalar({required this.value, required this.kind});
}

class DataDiagram extends Diagram {
  final DataNode root;
  final DataFormat format;
  @override
  final DiagramDecorations decorations;

  const DataDiagram({
    required this.root,
    required this.format,
    this.decorations = const DiagramDecorations(),
  });
}

sealed class SaltCell {
  const SaltCell();
}

class SaltLabel extends SaltCell {
  final String text;
  const SaltLabel(this.text);
}

class SaltButton extends SaltCell {
  final String label;
  const SaltButton(this.label);
}

class SaltTextField extends SaltCell {
  final String value;
  const SaltTextField(this.value);
}

class SaltRadio extends SaltCell {
  final bool selected;
  final String label;
  const SaltRadio({required this.selected, required this.label});
}

class SaltCheckbox extends SaltCell {
  final bool checked;
  final String label;
  const SaltCheckbox({required this.checked, required this.label});
}

class SaltRow {
  final bool isDivider;
  final List<SaltCell> cells;
  const SaltRow({this.isDivider = false, this.cells = const []});
}

class SaltDiagram extends Diagram {
  final List<SaltRow> rows;
  @override
  final DiagramDecorations decorations;

  const SaltDiagram({
    this.rows = const [],
    this.decorations = const DiagramDecorations(),
  });
}

sealed class GanttItem {
  const GanttItem();
}

class GanttTask extends GanttItem {
  final String name;
  final DateTime start;
  final Duration duration;
  final Color? color;

  const GanttTask({
    required this.name,
    required this.start,
    required this.duration,
    this.color,
  });
}

class GanttMilestone extends GanttItem {
  final String name;
  final DateTime date;

  const GanttMilestone({required this.name, required this.date});
}

class GanttSection extends GanttItem {
  final String title;
  const GanttSection(this.title);
}

class NetworkNode {
  final String name;
  final String? address;

  const NetworkNode({required this.name, this.address});
}

class NetworkSegment {
  final String name;
  final String? address;
  final List<NetworkNode> nodes;

  const NetworkSegment({
    required this.name,
    this.address,
    this.nodes = const [],
  });
}

class NetworkDiagram extends Diagram {
  final List<NetworkSegment> networks;
  @override
  final DiagramDecorations decorations;

  const NetworkDiagram({
    this.networks = const [],
    this.decorations = const DiagramDecorations(),
  });
}

class GanttDiagram extends Diagram {
  final DateTime projectStart;
  final List<GanttItem> items;
  @override
  final DiagramDecorations decorations;

  const GanttDiagram({
    required this.projectStart,
    this.items = const [],
    this.decorations = const DiagramDecorations(),
  });
}
