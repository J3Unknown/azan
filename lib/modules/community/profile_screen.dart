import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:azan/services/community_service.dart';
import 'package:azan/utils/helpers/app_language.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  Map<String, dynamic>? profile;
  String? photo;
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
      final data = await CommunityService.dashboard();
      final p = Map<String, dynamic>.from(data['profile']);
      String? url;
      if (p['avatar_path'] != null) {
        url = await CommunityService.client.storage
            .from('azan-avatars')
            .createSignedUrl(p['avatar_path'], 3600);
      }
      if (mounted) {
        setState(() {
          profile = p;
          name.text = p['display_name'];
          photo = url;
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
  Future<void> save({bool upload = false}) async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      String? path;
      if (upload) {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (image == null) return;
        if (await image.length() > 2 * 1024 * 1024) {
          if (mounted) notice('Choose an image of 2 MB or less.');
          return;
        }
        final bytes = await image.readAsBytes();
        // Check the actual file signature rather than trusting a renamed extension.
        final jpeg =
            bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255;
        final png =
            bytes.length >= 8 &&
            bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
        final webp =
            bytes.length >= 12 &&
            String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
            String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP';
        if (!jpeg && !png && !webp) {
          if (mounted) notice('Choose a JPEG, PNG or WebP image.');
          return;
        }
        final ext = jpeg
            ? 'jpg'
            : png
            ? 'png'
            : 'webp';
        path = '${CommunityService.client.auth.currentUser!.id}/avatar.$ext';
        await CommunityService.client.storage
            .from('azan-avatars')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: jpeg
                    ? 'image/jpeg'
                    : png
                    ? 'image/png'
                    : 'image/webp',
              ),
            );
      }
      await CommunityService.action('profile', {
        'name': name.text.trim(),
        'avatar_path': ?path,
      });
      await load();
      if (mounted) notice('Profile saved');
    } catch (_) {
      if (mounted) notice('Unable to save. Please try again.');
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
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: photo == null ? null : NetworkImage(photo!),
                  child: photo == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => save(upload: true),
                child: Text(context.tr('Upload photo · maximum 2 MB')),
              ),
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
              Text(CommunityService.client.auth.currentUser!.email ?? ''),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(context.tr(busy ? 'Saving…' : 'Save')),
              ),
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
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await CommunityService.client.auth.signOut();
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
            ],
          ),
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
