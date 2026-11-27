import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvbox_updater/tv_navigation.dart';

void main() {
  testWidgets('el foco no da una vuelta en los bordes', (tester) async {
    final first = FocusNode(debugLabel: 'primero');
    final second = FocusNode(debugLabel: 'segundo');

    await tester.pumpWidget(
      MaterialApp(
        home: TvNavigation(
          child: Column(
            children: [
              Focus(
                focusNode: first,
                child: const SizedBox(width: 100, height: 100),
              ),
              Focus(
                focusNode: second,
                child: const SizedBox(width: 100, height: 100),
              ),
            ],
          ),
        ),
      ),
    );

    second.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(second));

    first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(first));
  });
}
