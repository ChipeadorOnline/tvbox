import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hace que las flechas y el botón OK del control remoto funcionen siempre.
/// Envuelve una pantalla completa; los eventos burbujean desde el widget
/// enfocado hasta acá.
class TvNavigation extends StatelessWidget {
  const TvNavigation({
    super.key,
    required this.child,
    this.onConfirm,
  });

  final Widget child;

  /// Si se indica, el botón OK del control ejecuta esta acción.
  /// Si es null, OK deja que el botón enfocado haga su trabajo normal.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowRight) {
          FocusScope.of(context).nextFocus();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowLeft) {
          FocusScope.of(context).previousFocus();
          return KeyEventResult.handled;
        }
        final isOk = key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.select;
        if (isOk && onConfirm != null) {
          onConfirm!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// Botón con borde blanco cuando tiene el foco, para ver dónde estamos
/// parados con el control remoto.
class TvStyles {
  const TvStyles._();

  static ButtonStyle button(Color background) => ButtonStyle(
        backgroundColor: WidgetStateProperty.all(background),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        minimumSize: WidgetStateProperty.all(const Size(200, 52)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        side: WidgetStateProperty.resolveWith<BorderSide>((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(color: Colors.white, width: 3);
          }
          return BorderSide.none;
        }),
      );
}
