import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/desktop/widgets/sos_settings_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTarget(VoidCallback onOpen) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SosSettingsTarget(label: 'Settings', onOpen: onOpen),
          ),
        ),
      );

  final target = find.byType(SosSettingsTarget);
  final border =
      find.descendant(of: target, matching: find.byType(DecoratedBox));
  BoxDecoration decoration(WidgetTester tester) =>
      tester.widget<DecoratedBox>(border).decoration as BoxDecoration;

  testWidgets('only the original area opens settings and hover stays invisible',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(buildTarget(() => opens++));
    expect(tester.getSize(target), const Size(30, 25));
    expect(find.byIcon(Icons.more_vert_outlined), findsNothing);
    final center = tester.getCenter(target);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: center - const Offset(40, 0));
    await mouse.moveTo(center);
    await tester.pump();
    expect(decoration(tester).border, isNull);
    expect(find.byType(Tooltip), findsNothing);
    expect(opens, 0);
    await tester.tapAt(center - const Offset(20, 0));
    expect(opens, 0);
    await tester.tapAt(center, kind: PointerDeviceKind.mouse);
    expect(opens, 1);
    await mouse.removePointer();
  });

  testWidgets('settings is named and can be focused and activated by keyboard',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(buildTarget(() => opens++));
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(decoration(tester).border, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opens, 1);
  });
}
