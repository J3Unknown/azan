import 'dart:convert';
import 'package:azan/modules/community/auth_screen.dart';
import 'package:azan/modules/community/community_models.dart';
import 'package:azan/modules/community/task_editor_screen.dart';
import 'package:azan/modules/community/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  GoTrueClient fakeClient(
    List<http.Request> requests, {
    bool requireConfirmation = false,
  }) {
    const uid = '10000000-0000-0000-0000-000000000001';
    final user = {
      'id': uid,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'omar@example.com',
      'created_at': '2026-11-15T12:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
    };
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}')).replaceAll('=', '')}.${base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}))).replaceAll('=', '')}.test';
    final client = GoTrueClient(
      url: 'https://example.supabase.co/auth/v1',
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/token') ||
            request.url.path.endsWith('/signup')) {
          if (request.url.path.endsWith('/token') &&
              body['password'] == 'incorrect-password') {
            return http.Response(
              jsonEncode({
                'msg': 'Invalid login credentials',
                'code': 'invalid_credentials',
              }),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/signup') && requireConfirmation
                  ? {'user': user}
                  : {
                      'access_token': token,
                      'refresh_token': 'test-refresh',
                      'token_type': 'bearer',
                      'expires_in': 3600,
                      'user': user,
                    },
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/user')) {
          if (body['email'] != null) {
            user['email'] = body['email'];
          }
          return http.Response(
            jsonEncode(user),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    return client;
  }

  testWidgets(
    'Signup returns to login with no session until password sign-in',
    (tester) async {
      final requests = <http.Request>[];
      final client = fakeClient(requests);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(authClient: client),
                  ),
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('name')), 'Omar');
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'omar@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'strong-password',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign up'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign up'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
      expect(
        find.text('Account created successfully. Please sign in.'),
        findsOneWidget,
      );
      expect(client.currentSession, isNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('email')))
            .controller!
            .text,
        'omar@example.com',
      );
      expect(jsonDecode(requests.first.body)['data']['display_name'], 'Omar');
      expect(requests.map((r) => r.url.path), [
        '/auth/v1/signup',
        '/auth/v1/logout',
      ]);
      expect(find.byKey(const ValueKey('otp')), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('password')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'strong-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
      expect(client.currentSession, isNotNull);
    },
  );
  testWidgets(
    'Login rejects incorrect passwords then signs in with email and password',
    (tester) async {
      final requests = <http.Request>[];
      final client = fakeClient(requests);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(authClient: client),
                  ),
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'omar@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'incorrect-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid login credentials'), findsOneWidget);
      expect(client.currentSession, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'strong-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
      expect(client.currentSession, isNotNull);
      expect(requests.every((r) => r.url.path == '/auth/v1/token'), true);
    },
  );
  testWidgets(
    'Signup never presents a dead verification flow if server configuration changes',
    (tester) async {
      final client = fakeClient(<http.Request>[], requireConfirmation: true);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(page: AuthPage.signup, authClient: client),
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('name')), 'Omar');
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'omar@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'strong-password',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign up'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign up'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Sign up is temporarily unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('otp')), findsNothing);
      expect(client.currentSession, isNull);
    },
  );
  testWidgets(
    'Login exposes signup without email recovery or verification controls',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Forgot password'), findsNothing);
      expect(find.text('Resend confirmation email'), findsNothing);
      expect(find.text('Resend code'), findsNothing);
    },
  );
  testWidgets(
    'Logout safely closes the profile after the session becomes null',
    (tester) async {
      final client = fakeClient(<http.Request>[]);
      await client.signInWithPassword(
        email: 'omar@example.com',
        password: 'strong-password',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      authClient: client,
                      fetchDashboard: () async => {
                        'profile': {
                          'display_name': 'Omar',
                          'friend_code': 'ABCDEF123456',
                        },
                      },
                    ),
                  ),
                ),
                child: const Text('Open profile'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open profile'));
      await tester.pumpAndSettle();
      expect(find.text('omar@example.com'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Log out'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
      await tester.pumpAndSettle();
      expect(client.currentUser, isNull);
      expect(find.text('Open profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final fails in [false, true]) {
    testWidgets(
      'Account deletion requires confirmation and ${fails ? 'preserves the session on failure' : 'signs out after success'}',
      (tester) async {
        final client = fakeClient(<http.Request>[]);
        await client.signInWithPassword(
          email: 'omar@example.com',
          password: 'strong-password',
        );
        var deletions = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        authClient: client,
                        fetchDashboard: () async => {
                          'profile': {
                            'display_name': 'Omar',
                            'friend_code': 'ABCDEF123456',
                          },
                        },
                        deleteAccount: () async {
                          deletions++;
                          if (fails) throw Exception('Network unavailable');
                        },
                      ),
                    ),
                  ),
                  child: const Text('Open profile'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open profile'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Delete account'));
        await tester.tap(find.text('Delete account'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Delete permanently'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(deletions, 0);
        await tester.tap(find.text('Delete account'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('delete-account-confirmation')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('delete-account-confirmation')),
          'DELETE',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Delete permanently'),
        );
        await tester.pumpAndSettle();
        expect(deletions, 1);
        if (fails) {
          expect(client.currentSession, isNotNull);
          expect(
            find.text('Unable to delete your account. Please try again.'),
            findsOneWidget,
          );
        } else {
          expect(client.currentSession, isNull);
          expect(find.text('Open profile'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Profile email follows the signed-in auth user and updates with the session',
    (tester) async {
      final client = fakeClient(<http.Request>[]);
      await client.signInWithPassword(
        email: 'omar@example.com',
        password: 'strong-password',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            authClient: client,
            fetchDashboard: () async => {
              'profile': {
                'display_name': 'Member',
                'friend_code': 'ABCDEF123456',
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('profile-email'))).data,
        client.currentUser!.email,
      );
      await client.updateUser(
        UserAttributes(email: 'another-member@example.com'),
      );
      await tester.pumpAndSettle();
      expect(find.text('another-member@example.com'), findsOneWidget);
      expect(find.text('omar@example.com'), findsNothing);
      await client.signOut();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('profile-email'))).data,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Admin can configure a custom weekly task with its own points and description',
    (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TaskEditorScreen(
                        today: '2026-11-15',
                        existingNames: ['Fajr'],
                      ),
                    ),
                  );
                },
                child: const Text('New task'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Task name'),
        'Charity',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Points per completion'),
        '5',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (optional)'),
        'Help someone in need',
      );
      final repeat = find
          .byWidgetPredicate((w) => w is DropdownButtonFormField<String>)
          .last;
      await tester.ensureVisible(repeat);
      await tester.tap(repeat);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selected weekdays').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Fri'));
      await tester.tap(find.widgetWithText(FilterChip, 'Fri'));
      await tester.tap(find.widgetWithText(FilterChip, 'Sun'));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add task'));
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();
      expect(result, {
        'name': 'Charity',
        'points': 5,
        'description': 'Help someone in need',
        'repeats': 'weekly',
        'weekdays': [5],
        'start_date': '2026-11-15',
      });
    },
  );
  test('Friday anchor follows the Friday to Thursday week', () {
    expect(calendarDate(fridayAnchor(DateTime(2026, 11, 19))), '2026-11-13');
    expect(calendarDate(fridayAnchor(DateTime(2026, 11, 20))), '2026-11-20');
    expect(calendarDate(fridayAnchor(DateTime(2026, 11, 22))), '2026-11-20');
  });
  testWidgets(
    'Task editing preloads existing values and saves the revised task',
    (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TaskEditorScreen(
                        today: '2026-11-15',
                        existingNames: ['Fajr'],
                        task: {
                          'name': 'Quran revision',
                          'points': 4,
                          'description': 'Previous description',
                          'repeats': 'weekly',
                          'weekdays': [5],
                          'start_date': '2026-11-01',
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Edit existing'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit existing'));
      await tester.pumpAndSettle();
      expect(find.text('Quran revision'), findsOneWidget);
      expect(find.text('Previous description'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Task name'),
        'Quran review',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Points per completion'),
        '8',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(result!['name'], 'Quran review');
      expect(result!['points'], 8);
      expect(result!['repeats'], 'weekly');
      expect(result!['weekdays'], [5]);
      expect(result!['start_date'], '2026-11-15');
    },
  );
}
