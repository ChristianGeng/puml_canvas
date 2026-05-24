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

  const PumlView({
    super.key,
    required this.source,
    this.errorBuilder,
    this.fileLoader,
  });

  @override
  Widget build(BuildContext context) {
    final Scene scene;
    try {
      final pre =
          Preprocessor(fileLoader: fileLoader).preprocess(source);
      final tokens = Lexer().tokenize(pre);
      final diagram = Parser().parse(tokens);
      scene = const AutoLayout().layout(diagram, const FlutterTextMeasurer());
    } catch (e) {
      return errorBuilder?.call(context, e) ??
          _DefaultError(error: e.toString());
    }

    if (scene.size == Size.zero) return const SizedBox.shrink();

    return CustomPaint(
      size: scene.size,
      painter: _PumlPainter(scene),
    );
  }
}

class _PumlPainter extends CustomPainter {
  final Scene scene;
  const _PumlPainter(this.scene);

  @override
  void paint(Canvas canvas, Size size) {
    const Renderer().render(canvas, scene);
  }

  @override
  bool shouldRepaint(covariant _PumlPainter old) =>
      !identical(old.scene, scene);
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
