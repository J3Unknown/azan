import 'package:azan/data/app_updates.dart';
import 'package:azan/services/whats_new_service.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

class _MemoryBox extends Fake implements Box<dynamic> {
  final entries = <dynamic, dynamic>{};
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      entries[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    entries[key] = value;
  }
}

void main() {
  final storage = _MemoryBox();
  setUpAll(() => HiveManager.metaDataBox = storage);
  setUp(storage.entries.clear);

  Widget launcher(
    List<String> updates, {
    String language = 'en',
    double textScale = 1,
    bool force = false,
  }) => MaterialApp(
    locale: Locale(language),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => WhatsNewService.showIfNeeded(
            context,
            updates: updates,
            force: force,
          ),
          child: const Text('Launch'),
        ),
      ),
    ),
  );

  testWidgets(
    'Dismissed notes persist across launches and changed lists reappear',
    (tester) async {
      await tester.pumpWidget(launcher(const ['First update']));
      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();
      expect(find.text('First update'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      // Recreate the UI to simulate another startup, preserving local storage.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(launcher(const ['First update']));
      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.pumpWidget(
        launcher(const ['First update', 'Another update']),
      );
      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();
      expect(find.text('Another update'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Current updates support Arabic and large text on a small screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        launcher(currentAppUpdates, language: 'ar', textScale: 2),
      );
      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();
      expect(find.text('ما الجديد'), findsOneWidget);
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(AlertDialog)),
        ).scale(10),
        20,
      );
      expect(find.text(currentAppUpdates.first), findsNothing);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('فهمت'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'Test preview shows seen notes again while normal mode suppresses them',
    (tester) async {
      for (var i = 0; i < 2; i++) {
        await tester.pumpWidget(
          launcher(const ['Preview update'], force: true),
        );
        await tester.tap(find.text('Launch'));
        await tester.pumpAndSettle();
        expect(find.text('Preview update'), findsOneWidget);
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpWidget(launcher(const ['Preview update']));
      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
