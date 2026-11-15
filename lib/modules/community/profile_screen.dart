import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:azan/services/community_service.dart';
import 'package:azan/utils/helpers/app_language.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.authClient,
    this.fetchDashboard,
    this.deleteAccount,
  });
  final GoTrueClient? authClient;
  final Future<Map<String, dynamic>> Function()? fetchDashboard;
  final Future<void> Function()? deleteAccount;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  GoTrueClient get auth => widget.authClient ?? CommunityService.client.auth;
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  Map<String, dynamic>? profile;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data =
          await (widget.fetchDashboard?.call() ?? CommunityService.dashboard());
      final p = Map<String, dynamic>.from(data['profile']);
      if (mounted) {
        setState(() {
          profile = p;
          name.text = p['display_name'];
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to load. Check your connection and try again.',
        );
      }
    }
  }

  void notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.tr(message))));
  Future<void> save() async {
    final user = auth.currentUser;
    if (user == null) {
      notice('Please log in');
      return;
    }
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await CommunityService.action('profile', {'name': name.text.trim()});
      await load();
      if (mounted) notice('Profile saved');
    } catch (_) {
      if (mounted) notice('Unable to save. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteAccount() async {
    if (busy || auth.currentUser == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await (widget.deleteAccount?.call() ?? CommunityService.deleteAccount());
      try {
        await auth.signOut(scope: SignOutScope.local);
      } catch (error) {
        // The SDK clears the local session before contacting the deleted user.
        debugPrint('Account deleted; remote sign-out unavailable: $error');
      }
      if (mounted) {
        notice('Your account has been deleted.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) notice('Unable to delete your account. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Profile'))),
    body: error != null
        ? Center(
            child: TextButton(onPressed: load, child: Text(context.tr(error!))),
          )
        : profile == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Your friend code')),
                subtitle: SelectableText(profile!['friend_code']),
                trailing: IconButton(
                  tooltip: context.tr('Copy'),
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: profile!['friend_code']),
                    );
                    if (mounted) notice('Copied');
                  },
                ),
              ),
              Text(
                context.tr('Share this code privately to receive a challenge.'),
              ),
              const SizedBox(height: 24),
              Form(
                key: form,
                child: TextFormField(
                  controller: name,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: context.tr('User name'),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 2
                      ? context.tr('Use at least 2 characters')
                      : null,
                ),
              ),
              StreamBuilder<AuthState>(
                stream: auth.onAuthStateChange,
                builder: (context, _) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: Text(context.tr('Email')),
                  subtitle: Text(
                    auth.currentUser?.email ?? '',
                    key: const ValueKey('profile-email'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(context.tr(busy ? 'Saving…' : 'Save')),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await auth.signOut();
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (mounted) {
                            notice('Unable to connect. Please try again.');
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(context.tr('Log out')),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: busy ? null : deleteAccount,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(context.tr('Delete account')),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
  );
}

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});
  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final confirmation = TextEditingController();
  @override
  void dispose() {
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.tr('Delete account permanently?')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            'This permanently deletes your account, profile, memberships, completions and reports, including your entries in other members’ reports. Rooms you own and all their tasks and member progress will also be deleted. This cannot be undone. Offline prayer times, Quran and supplications remain available.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('delete-account-confirmation'),
          controller: confirmation,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: context.tr('Type DELETE to confirm'),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(context.tr('Cancel')),
      ),
      FilledButton(
        onPressed: confirmation.text == 'DELETE'
            ? () => Navigator.pop(context, true)
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        child: Text(context.tr('Delete permanently')),
      ),
    ],
  );
}

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final subject = TextEditingController();
  final message = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Contact us'))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SelectableText('taemaomar65@gmail.com'),
            TextFormField(
              controller: subject,
              maxLength: 120,
              decoration: InputDecoration(labelText: context.tr('Subject')),
              validator: (v) =>
                  v!.trim().isEmpty ? context.tr('Required') : null,
            ),
            TextFormField(
              controller: message,
              maxLength: 5000,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(labelText: context.tr('Message')),
              validator: (v) =>
                  v!.trim().isEmpty ? context.tr('Required') : null,
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => busy = true);
                      try {
                        final uri = Uri(
                          scheme: 'mailto',
                          path: 'taemaomar65@gmail.com',
                          query:
                              'subject=${Uri.encodeComponent(subject.text.trim())}&body=${Uri.encodeComponent(message.text.trim())}',
                        );
                        if (!await launchUrl(uri)) {
                          throw StateError('No email app');
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.tr(
                                  'No email app found. Please email taemaomar65@gmail.com.',
                                ),
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(context.tr('Open email app')),
            ),
            Text(context.tr('Review and send your message in your email app.')),
          ],
        ),
      ),
    ),
  );
}
