import 'package:azan/services/community_service.dart';
import 'package:azan/modules/community/community_screen.dart';
import 'package:azan/modules/community/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Email validation accepts normal addresses and rejects malformed ones',
    () {
      for (final email in [
        'omar@example.com',
        'omar+azan@mail.example.co.uk',
        ' omar@example.com ',
      ]) {
        expect(CommunityService.emailError(email), isNull, reason: email);
      }
      for (final email in [
        '',
        'omar',
        'omar@',
        '@example.com',
        'omar@example',
        'a..b@example.com',
        '.a@example.com',
        'a.@example.com',
        'a@-example.com',
        'a b@example.com',
      ]) {
        expect(CommunityService.emailError(email), isNotNull, reason: email);
      }
    },
  );
  test('Scoring and strict 75 percent weakness threshold', () {
    expect(
      worshipTasks.fold<int>(0, (sum, task) => sum + taskPoints(task)),
      10,
    );
    expect(isWeakPoint(3, 4), false);
    expect(isWeakPoint(5, 7), true);
    expect(isWeakPoint(6, 7), false);
    expect(isWeakPoint(0, 0), false);
  });
  testWidgets('Offline app entry remains available without Supabase', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    expect(
      find.textContaining('Online worship is being prepared.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('Contact form validates before launching email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ContactScreen()));
    await tester.tap(find.text('Open email app'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(2));
  });
}
