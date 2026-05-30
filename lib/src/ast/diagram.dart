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
  // Display names for aliases introduced inline via `"X" as Alias` in a
  // message; the alias is auto-discovered by event traversal so it must NOT
  // be added to `participants` (which would override its layout order).
  final Map<String, String> aliasDisplayNames;
  // Set by the `autoactivate on` directive. Informational only — the parser
  // already lowers autoactivate semantics into explicit Activate/Deactivate
  // events plus return messages, so layout does not need to inspect this.
  final bool autoactivate;
  // Set by the `hide unlinked` directive. When true, layout removes any
  // participant that is not referenced as the source or target of a
  // [Message] (declared boxes/groups and activate/deactivate-only references
  // do not count as "linked"). Order-independent — applied at render time.
  final bool hideUnlinked;
  // Set by the `hide footbox` directive. When true, layout skips the
  // bottom (foot) participant boxes/symbols that mirror the header row at
  // the end of the lifelines. Lifelines still terminate at the same Y.
  final bool hideFootbox;
  // Set by `skinparam actorStyle <value>` (e.g. `awesome`, `Hollow`). When
  // null, actors render with the default stick-figure shape. Currently
  // `awesome` is honoured visually (cartoonier figure); other values are
  // stored but render identically to the default until implemented.
  final String? actorStyle;
  // Set by the `mainframe <label>` directive. When non-null, layout wraps
  // the entire diagram in an outer rectangle with a folded-corner label tab
  // in the top-left containing this label (which honours inline markup like
  // `**bold**`).
  final String? mainframeLabel;
  @override
  final DiagramDecorations decorations;

  const SequenceDiagram({
    this.participants = const [],
    this.events = const [],
    this.boxes = const [],
    this.aliasDisplayNames = const {},
    this.autoactivate = false,
    this.hideUnlinked = false,
    this.hideFootbox = false,
    this.actorStyle,
    this.mainframeLabel,
    this.decorations = const DiagramDecorations(),
  });

  /// Returns the set of participant aliases that are referenced as the source
  /// or target of at least one [Message] anywhere in the event tree
  /// (recursing into [Group] branches). External "found"/"lost" endpoints do
  /// not count — only declared participant aliases.
  Set<String> linkedAliases() {
    final out = <String>{};
    void visit(List<SequenceEvent> list) {
      for (final e in list) {
        switch (e) {
          case Message():
            if (e.fromExternal == null) out.add(e.from);
            if (e.toExternal == null) out.add(e.to);
          case Group():
            for (final b in e.branches) {
              visit(b.events);
            }
          case Note():
          case RefBox():
          case Activate():
          case Deactivate():
          case Create():
          case Destroy():
          case Separator():
          case NewPage():
            break;
        }
      }
    }

    visit(events);
    return out;
  }

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
      for (final p in box.allParticipants()) {
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
        order.add(byAlias[alias] ??
            Participant(
              alias: alias,
              displayName: aliasDisplayNames[alias],
            ));
      }
    }

    void visit(List<SequenceEvent> list) {
      for (final e in list) {
        switch (e) {
          case Message():
            // Skip anonymous endpoints — they're not real participants and
            // must not appear in the lifeline column order.
            if (e.fromExternal == null) touch(e.from);
            if (e.toExternal == null) touch(e.to);
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
    // Stable sort by explicit `order N` directive when any participant
    // declared one; undeclared participants keep their relative position.
    final anyOrdered = order.any((p) => p.order != null);
    if (anyOrdered) {
      final indexed = [
        for (var i = 0; i < order.length; i++) (i, order[i]),
      ];
      indexed.sort((a, b) {
        final ao = a.$2.order;
        final bo = b.$2.order;
        if (ao != null && bo != null) return ao.compareTo(bo);
        if (ao != null) return -1;
        if (bo != null) return 1;
        return a.$1.compareTo(b.$1);
      });
      return [for (final e in indexed) e.$2];
    }
    return order;
  }

  /// Returns the innermost box containing the participant with the given
  /// alias, or null if the participant is not declared inside any box.
  ParticipantBox? boxOf(String alias) {
    ParticipantBox? search(ParticipantBox box) {
      for (final c in box.children) {
        final found = search(c);
        if (found != null) return found;
      }
      for (final p in box.participants) {
        if (p.alias == alias) return box;
      }
      return null;
    }

    for (final box in boxes) {
      final found = search(box);
      if (found != null) return found;
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
  // Participants declared directly inside this box (not inside a nested box).
  final List<Participant> participants;
  // Nested boxes declared inside this box.
  final List<ParticipantBox> children;

  const ParticipantBox({
    required this.label,
    this.color,
    this.participants = const [],
    this.children = const [],
  });

  /// All participants enclosed by this box (recursing into nested boxes).
  List<Participant> allParticipants() {
    final out = <Participant>[];
    void visit(ParticipantBox b) {
      out.addAll(b.participants);
      for (final c in b.children) {
        visit(c);
      }
    }

    visit(this);
    return out;
  }
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

enum ParticipantLabelStyle { normal, title, code }

class ParticipantLabelLine {
  final String text;
  final ParticipantLabelStyle style;
  const ParticipantLabelLine(this.text, this.style);
}

class ParticipantLabelSection {
  final List<ParticipantLabelLine> lines;
  const ParticipantLabelSection(this.lines);
}

class Participant {
  final String alias;
  final String? displayName;
  final ParticipantKind kind;
  final int? order;
  final List<ParticipantLabelSection>? labelSections;
  final Color? color;
  final String? stereotype;

  const Participant({
    required this.alias,
    this.displayName,
    this.kind = ParticipantKind.participant,
    this.order,
    this.labelSections,
    this.color,
    this.stereotype,
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
  square,
  bracket,
  plus,
  caret,
}

enum MessageDirection { forward, backward, bidirectional }

/// Optional decoration drawn at the non-triangle endpoint of a [Message].
///
/// PlantUML sequence syntax allows decorating the TAIL end of an arrow
/// independently of the head triangle: a small open circle (`o->`, `o<-`,
/// `o<->o`) or a cross (`x->`, `x<-`, `x<->x`). The head can ALSO carry such
/// a decoration when stacked behind the triangle (`->>o`, `-\o`) — when
/// present, the decoder records the visible shape in [Message.head]
/// (e.g. [ArrowHead.openCircle]) and the head decoration is implicit in that.
///
/// For bidirectional arrows both endpoints carry the SAME decoration, so a
/// single `tailDecoration` plus [Message.head] suffices to round-trip the
/// 20 PlantUML head/tail combos.
enum EndpointDecoration { openCircle, cross }

enum ActivationSuffix {
  activateTarget,
  deactivateSource,
  createTarget,
  destroyTarget,
}

/// Marks one endpoint of a [Message] as anonymous — the arrow attaches to a
/// notional "external" location instead of a declared participant lifeline.
///
/// Source forms:
/// - `[-> Alice`  → message starts at the LEFT edge of the diagram
///   ([fromEdge]).
/// - `?-> Alice`  → message starts at a SHORT stub to the left of Alice's
///   lifeline ([fromShort]).
///
/// Target forms (mirrored):
/// - `Alice ->]`  → message ends at the RIGHT edge of the diagram ([toEdge]).
/// - `Alice ->?`  → message ends at a SHORT stub to the right of Alice's
///   lifeline ([toShort]).
///
/// PlantUML calls these "found" (source is external) and "lost"
/// (target is external) messages. When [Message.fromExternal] is non-null,
/// [Message.from] holds the placeholder alias of the external endpoint and
/// must NOT be auto-declared as a participant — layout substitutes a
/// computed X coordinate instead. Same for [Message.toExternal] / [Message.to].
enum MessageExternal { fromEdge, fromShort, toEdge, toShort }

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
  // Non-null when the source endpoint is anonymous (`[->` / `?->`). The
  // [from] field still carries a synthetic alias so the layout can key into
  // per-event maps, but no participant should be declared for it.
  final MessageExternal? fromExternal;
  // Non-null when the target endpoint is anonymous (`->]` / `->?`). Same
  // alias caveat as [fromExternal].
  final MessageExternal? toExternal;
  /// Optional decoration drawn at the TAIL end of the arrow body (the
  /// endpoint opposite the head triangle for a forward / backward message,
  /// or the source endpoint for a forward bidirectional). Encodes the leading
  /// `o` / `x` of PlantUML forms like `o->`, `x->`, `o<->o`, `x<->x`,
  /// `x->o`. The head's own decoration (e.g. trailing `o` in `->o`) is
  /// captured by the visible shape in [head], not here.
  final EndpointDecoration? tailDecoration;
  /// Optional PlantUML "transmission duration" annotation embedded in the
  /// arrow body — `A ->(N) B` or `A (N)<- B`. When non-null, the arrow is
  /// rendered as a slanted/diagonal line: the head endpoint sits below the
  /// tail endpoint by an amount proportional to [duration]. Forward arrows
  /// slant DOWN to the right; backward arrows slant DOWN to the left.
  /// Visualises "time passes during message transmission".
  final int? duration;
  /// When true, this message shares its START Y coordinate with the
  /// immediately preceding message rather than advancing past it. Set by the
  /// PlantUML `&` line-prefix marker (used together with `!pragma teoz` to
  /// group parallel messages that arrive at slightly different times).
  final bool synchronized;

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
    this.fromExternal,
    this.toExternal,
    this.tailDecoration,
    this.duration,
    this.synchronized = false,
  });
}

class Activate extends SequenceEvent {
  final String participant;
  final Color? color;
  const Activate(this.participant, {this.color});
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

/// Visible outline shape for a [Note]. Defaults to [rectangle]; PlantUML's
/// `hnote` keyword selects [hexagon] and `rnote` selects [rectangle]
/// explicitly. Layout currently renders both as rectangles (hexagon
/// rendering deferred).
enum NoteShape { rectangle, hexagon }

class Note extends SequenceEvent {
  final NotePosition position;
  final List<String> participants;
  final String text;
  final Color? color;
  final NoteShape shape;

  const Note({
    required this.position,
    required this.participants,
    required this.text,
    this.color,
    this.shape = NoteShape.rectangle,
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

enum GroupKind { alt, opt, loop, par, group }

class GroupBranch {
  final String? label;
  final List<SequenceEvent> events;

  /// Optional background fill colour for this branch's vertical span.
  /// PlantUML syntax: `alt #Body label` / `else #Body label`.
  final Color? bodyColor;

  const GroupBranch({this.label, this.events = const [], this.bodyColor});
}

class Group extends SequenceEvent {
  final GroupKind kind;
  final List<GroupBranch> branches;

  /// Optional background fill for the small kind tab (e.g. the "alt" corner).
  /// PlantUML syntax: `alt#Tab` — colour attached directly to the keyword.
  final Color? tabColor;

  const Group({required this.kind, required this.branches, this.tabColor});
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
  circle,
  diamond,
  dataclass,
  metaclass,
  protocol,
  stereotype_,
  struct,
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
  squareLink,
  crossLink,
  bracketLink,
  plusLink,
  caretLink,
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

/// A semantic separator placed inside a use-case ellipse's multi-line label.
///
/// PlantUML allows quoted use-case labels to embed horizontal section
/// dividers that render across the shape:
///
/// ```
/// usecase UC1 as "Top section
/// --
/// Middle section
/// ==
/// Bottom section
/// ..Footer.."
/// ```
///
/// - [thin]: a single thin horizontal line (the `--` marker).
/// - [thick]: a thicker / double horizontal line (the `==` marker).
/// - [labeled]: a thin horizontal line with centered text (the `..Text..`
///   marker — [text] holds the centered label).
enum UseCaseLabelSeparator { thin, thick, labeled }

sealed class UseCaseLabelSpan {
  const UseCaseLabelSpan();
}

class UseCaseLabelText extends UseCaseLabelSpan {
  final String text;
  const UseCaseLabelText(this.text);
}

class UseCaseLabelSeparatorSpan extends UseCaseLabelSpan {
  final UseCaseLabelSeparator kind;
  final String? text;
  const UseCaseLabelSeparatorSpan(this.kind, {this.text});
}

class UseCaseNode {
  final String alias;
  final String label;
  final UseCaseNodeKind kind;

  /// Structured representation of [label] when it contains internal
  /// separator markers (`--`, `==`, `..Text..`). For simple single-line
  /// labels this is `null` and the layout renders [label] directly.
  final List<UseCaseLabelSpan>? labelSpans;

  /// Optional `<< Stereotype >>` annotation declared after the node. Stored
  /// as the inner text (already trimmed by the lexer, no guillemets). When
  /// non-null, layouts may render `«stereotype»` near the node label.
  final String? stereotype;

  const UseCaseNode({
    required this.alias,
    required this.label,
    required this.kind,
    this.labelSpans,
    this.stereotype,
  });
}

/// Visual line style used by `UseCaseRelation`. Extends the base `LineStyle`
/// (solid/dashed) with `bold` and `dotted` variants that PlantUML's inline
/// `#color;line.bold;line.dotted` modifiers introduce on use case relations.
enum UseCaseLineStyle { solid, bold, dashed, dotted }

class UseCaseRelation {
  final String from;
  final String to;
  final LineStyle lineStyle;
  final ArrowHead? head;
  final MessageDirection direction;
  final String? label;

  /// Stroke color from `#<color>` / `line:<color>` inline modifier. Null when
  /// no inline color is supplied — the renderer falls back to the default
  /// relation stroke.
  final Color? lineColor;

  /// Inline `line.bold|dashed|dotted` modifier, or null when the relation
  /// keeps its arrow-derived `lineStyle`.
  final UseCaseLineStyle? inlineLineStyle;

  /// Label text color from `text:<color>` inline modifier.
  final Color? textColor;

  const UseCaseRelation({
    required this.from,
    required this.to,
    this.lineStyle = LineStyle.solid,
    this.head = ArrowHead.open,
    this.direction = MessageDirection.forward,
    this.label,
    this.lineColor,
    this.inlineLineStyle,
    this.textColor,
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

/// A note attached to a use case diagram. Three flavours:
///
/// - Inline attached: `note right of X : text` — [position] and [attachedTo]
///   are both set, [alias] is null.
/// - Multi-line attached: `note right of X` ... `end note` — same as inline
///   but [text] may contain newlines.
/// - Free-standing: `note "text" as N2` — [alias] is set, [position] and
///   [attachedTo] are null. Can be connected to other nodes via
///   [UseCaseNoteConnection].
class UseCaseNote {
  /// Stable identifier for this note. Either the user-supplied alias (for
  /// free-standing notes) or a synthetic one for attached notes (so the
  /// layout can address it uniformly).
  final String alias;
  final String text;
  final NotePosition? position;
  final String? attachedTo;

  const UseCaseNote({
    required this.alias,
    required this.text,
    this.position,
    this.attachedTo,
  });

  bool get isFreeStanding => position == null && attachedTo == null;
}

/// A connector line between two endpoints in a use case diagram where at
/// least one endpoint is a free-standing note. PlantUML draws these as
/// thin dotted lines without arrowheads (the `..` syntax).
class UseCaseNoteConnection {
  final String from;
  final String to;
  const UseCaseNoteConnection({required this.from, required this.to});
}

class UseCaseDiagram extends Diagram {
  final List<UseCaseNode> nodes;
  final List<UseCaseRelation> relations;
  final List<UseCaseBoundary> boundaries;
  final List<UseCaseNote> notes;
  final List<UseCaseNoteConnection> noteConnections;
  final bool leftToRightDirection;
  @override
  final DiagramDecorations decorations;

  const UseCaseDiagram({
    this.nodes = const [],
    this.relations = const [],
    this.boundaries = const [],
    this.notes = const [],
    this.noteConnections = const [],
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

  /// Optional `<<stereotype>>` attached either inline or on a following line.
  /// Used by activity diagrams to select SDL shapes
  /// (`<<input>>`, `<<output>>`, `<<task>>`, …) and UML signal/object node
  /// variants (`<<object>>`, `<<sendSignal>>`, …). Visual rendering of the
  /// stereotype-specific shape is not yet implemented; the value is preserved
  /// so downstream consumers (and future renderers) can act on it.
  final String? stereotype;

  const Action({required this.text, this.note, this.stereotype});
}

/// Multi-way split block: `split` / `split again` / `end split`.
/// Semantically identical to [ForkBlock] for parsing purposes; rendered with
/// a diamond split-bar in PlantUML. Each entry of [branches] holds the
/// activity nodes for that branch.
class SplitBlock extends ActivityNode {
  final List<List<ActivityNode>> branches;

  const SplitBlock({this.branches = const []});
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

enum ComponentNodeKind {
  component,
  interface,
  artifact,
  database,
  queue,
  storage,
  port,
  portIn,
  portOut,
}

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

enum ContainerKind { package, node, cloud, frame, database, queue, storage }

class ComponentContainer {
  final String? label;
  final String? alias;
  final ContainerKind kind;
  final List<String> nodeAliases;
  final List<ComponentContainer> nestedContainers;

  const ComponentContainer({
    this.label,
    this.alias,
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
  final bool leftToRightDirection;
  @override
  final DiagramDecorations decorations;

  const ComponentDiagram({
    this.nodes = const [],
    this.containers = const [],
    this.relations = const [],
    this.leftToRightDirection = false,
    this.decorations = const DiagramDecorations(),
  });
}

enum TimingLaneKind { robust, concise, clock, binary, analog, rectangle }

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

class EbnfDiagram extends Diagram {
  final String text;
  final List<EbnfRule> rules;
  @override
  final DiagramDecorations decorations;

  const EbnfDiagram({
    required this.text,
    this.rules = const [],
    this.decorations = const DiagramDecorations(),
  });
}

class EbnfRule {
  final String name;
  final EbnfExpr expression;
  const EbnfRule({required this.name, required this.expression});
}

sealed class EbnfExpr {
  const EbnfExpr();
}

class EbnfTerminal extends EbnfExpr {
  final String value;
  const EbnfTerminal(this.value);
}

class EbnfNonTerminal extends EbnfExpr {
  final String name;
  const EbnfNonTerminal(this.name);
}

class EbnfSequence extends EbnfExpr {
  final List<EbnfExpr> items;
  const EbnfSequence(this.items);
}

class EbnfAlternation extends EbnfExpr {
  final List<EbnfExpr> items;
  const EbnfAlternation(this.items);
}

class EbnfOptional extends EbnfExpr {
  final EbnfExpr inner;
  const EbnfOptional(this.inner);
}

class EbnfRepetition extends EbnfExpr {
  final EbnfExpr inner;
  const EbnfRepetition(this.inner);
}

class EbnfGroup extends EbnfExpr {
  final EbnfExpr inner;
  const EbnfGroup(this.inner);
}

class EbnfComment extends EbnfExpr {
  final String text;
  const EbnfComment(this.text);
}

class EbnfSpecial extends EbnfExpr {
  final String text;
  const EbnfSpecial(this.text);
}

class EbnfEmpty extends EbnfExpr {
  const EbnfEmpty();
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
