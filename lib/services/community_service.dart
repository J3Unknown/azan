import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class CommunityService {
  // Load .env with Flutter's --dart-define-from-file=.env build option.
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment(
    'SUPABASE_PUBLISH_KEY',
    defaultValue: String.fromEnvironment('SUPABSE_PUBLISH_KEY'),
  );
  static const redirect = 'com.unknown.azan://auth-callback';
  static bool configured = false;
  static final recoveryRequested = ValueNotifier(false);
  static final authNotice = ValueNotifier<String?>(null);
  static SupabaseClient get client => Supabase.instance.client;
  static Future<void> initialize() async {
    if (url.isEmpty || key.isEmpty) return;
    try {
      await Supabase.initialize(url: url, anonKey: key);
      configured = true;
      client.auth.onAuthStateChange.listen(
        (state) {
          if (state.event == AuthChangeEvent.passwordRecovery) {
            recoveryRequested.value = true;
          }
        },
        onError: (Object error) {
          authNotice.value =
              'This email link is invalid or expired. Request a new one.';
        },
      );
    } catch (_) {
      debugPrint(
        'Online features could not initialize. Offline features remain available.',
      );
    }
  }

  static String? emailError(String? value) {
    final email = value?.trim() ?? '';
    if (email.length > 254 ||
        !RegExp(
          r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)+$",
        ).hasMatch(email) ||
        email.split('@').first.contains('..') ||
        email.startsWith('.') ||
        email.split('@').first.endsWith('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static Future<Map<String, dynamic>> dashboard() async =>
      Map<String, dynamic>.from(await client.rpc('azan_dashboard'));
  static Future<void> action(
    String action, [
    Map<String, dynamic> args = const {},
  ]) async {
    await client.rpc('azan_action', params: {'action': action, 'args': args});
  }
}
