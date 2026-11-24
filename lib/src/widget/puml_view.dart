import 'package:flutter/widgets.dart';

import '../layout/layout.dart';
import '../layout/scene.dart';
import '../layout/text_measurer.dart';
import '../lexer/lexer.dart';
import '../parser/parser.dart';
import '../preprocessor/preprocessor.dart';
import '../render/renderer.dart';

class PumlView extends StatelessWidget {
  final String source;
  final Widget Function(BuildContext, Object)? errorBuilder;
  final FileLoader? fileLoader;

  /// Opt-in flag for the Phase-5 Sugiyama-backed state diagram layout. False
  /// (default) keeps the existing [StateLayout] path so output is unchanged.
  final bool useSugiyamaForStates;

  /// Font family for diagram text whose style names none, so the diagram
  /// can match the font of the surrounding page. It goes to both the
  /// measurer and the renderer, so layout and painting use the same font.
  /// Null (default) keeps the platform's default font.
  final String? fontFamily;

  const PumlView({
    super.key,
    required this.source,
    this.errorBuilder,
    this.fileLoader,
    this.useSugiyamaForStates = false,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final Scene scene;
    try {
      final pre =
          Preprocessor(fileLoader: fileLoader).preprocess(source);
      final tokens = Lexer().tokenize(pre);
      final diagram = Parser().parse(tokens);
      scene = AutoLayout(useSugiyamaForStates: useSugiyamaForStates)
          .layout(diagram, FlutterTextMeasurer(fontFamily: fontFamily));
    } catch (e) {
      return errorBuilder?.call(context, e) ??
          _DefaultError(error: e.toString());
    }

    if (scene.size == Size.zero) return const SizedBox.shrink();

    return CustomPaint(
      size: scene.size,
      painter: _PumlPainter(scene, fontFamily),
    );
  }
}

class _PumlPainter extends CustomPainter {
  final Scene scene;
  final String? fontFamily;
  const _PumlPainter(this.scene, this.fontFamily);

  @override
  void paint(Canvas canvas, Size size) {
    Renderer(fontFamily: fontFamily).render(canvas, scene);
  }

  @override
  bool shouldRepaint(covariant _PumlPainter old) =>
      !identical(old.scene, scene) || old.fontFamily != fontFamily;
}

class _DefaultError extends StatelessWidget {
  final String error;
  const _DefaultError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFFFFEBEE),
      child: Text(
        error,
        style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 12),
      ),
    );
  }
}
