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
    // Flutter ordena por posición (ReadingOrderTraversalPolicy). El default
    // hace "closedLoop": del último vuelve al primero. Con stop nos quedamos
    // en el borde, sin saltos al menú ni a las tarjetas del medio.
    scope.traversalEdgeBehavior = TraversalEdgeBehavior.stop;
    if (next) {
      scope.nextFocus();
    } else {
      scope.previousFocus();
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
      // Este Focus solo escucha las teclas que burbujean desde los controles
      // hijos. No debe ser un destino del foco: si lo fuera, al subir desde el
      // primer botón el foco caía acá y parecía que el menú quedaba trabado.
      canRequestFocus: false,
      skipTraversal: true,
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
