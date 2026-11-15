import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class CommunityService {
  // Load .env with Flutter's --dart-define-from-file=.env build option.
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment(
    'SUPABASE_PUBLISH_KEY',
    defaultValue: String.fromEnvironment('SUPABSE_PUBLISH_KEY'),
  );
  static bool configured = false;
  static SupabaseClient get client => Supabase.instance.client;
  static Future<void> initialize() async {
    if (url.isEmpty || key.isEmpty) return;
    try {
      await Supabase.initialize(
        url: url,
        anonKey: key,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          detectSessionInUri: false,
        ),
      );
      configured = true;
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
  static Future<void> deleteAccount() async {
    await client.rpc('azan_delete_account', params: {'confirmation': 'DELETE'});
  }

  static Future<void> action(
    String action, [
    Map<String, dynamic> args = const {},
  ]) async {
    await client.rpc('azan_action', params: {'action': action, 'args': args});
  }
}
