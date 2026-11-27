import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hace que las flechas y el botón OK del control remoto funcionen siempre.
/// Envuelve una pantalla completa; los eventos burbujean desde el widget
/// enfocado hasta acá.
class TvNavigation extends StatelessWidget {
  const TvNavigation({super.key, required this.child, this.onConfirm});

  final Widget child;

  /// Si se indica, el botón OK del control ejecuta esta acción.
  /// Si es null, OK deja que el botón enfocado haga su trabajo normal.
  final VoidCallback? onConfirm;

  /// Mueve el foco y lo centra en el scroll cuando hace falta. Así las tarjetas
  /// no quedan cortadas al recorrer la lista con el control remoto.
  void _moveFocus(BuildContext context, {required bool next}) {
    final scope = FocusScope.of(context);
    final current = FocusManager.instance.primaryFocus;
    final nodes = scope.traversalDescendants
        .where((n) => n.canRequestFocus && !n.skipTraversal)
        .toList();

    // Sin "wrap": al llegar al último botón, seguir bajando no debe llevar
    // a las tarjetas del medio. Nos quedamos en el último (o en el primero).
    if (current != null && nodes.isNotEmpty) {
      final index = nodes.indexOf(current);
      if (index >= 0) {
        final target = index + (next ? 1 : -1);
        if (target < 0 || target >= nodes.length) return;
        nodes[target].requestFocus();
      } else {
        next ? scope.nextFocus() : scope.previousFocus();
      }
    } else {
      next ? scope.nextFocus() : scope.previousFocus();
    }

    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null || !focusContext.mounted) return;
    if (Scrollable.maybeOf(focusContext) == null) return;
    Scrollable.ensureVisible(
      focusContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

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
          _moveFocus(context, next: true);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowLeft) {
          _moveFocus(context, next: false);
          return KeyEventResult.handled;
        }
        final isOk =
            key == LogicalKeyboardKey.enter ||
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
