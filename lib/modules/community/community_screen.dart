import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:azan/services/community_service.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'room_detail_screen.dart';
import 'weekly_report_card.dart';
import 'community_models.dart';
export 'community_models.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  bool loading = false;
  Timer? timer;
  StreamSubscription<AuthState>? subscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (CommunityService.configured) {
      subscription = CommunityService.client.auth.onAuthStateChange.listen((
        event,
      ) {
        if (!mounted) return;
        if (event.event == AuthChangeEvent.signedOut) {
          setState(() => data = null);
        }
      }, onError: (Object _) {});
      load();
      timer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed &&
            !busy) {
          load();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && CommunityService.configured) {
      load();
    }
  }

  Future<void> load() async {
    if (loading || CommunityService.client.auth.currentUser == null) return;
    final uid = CommunityService.client.auth.currentUser!.id;
    loading = true;
    try {
      final result = await CommunityService.dashboard();
      if (mounted && CommunityService.client.auth.currentUser?.id == uid) {
        setState(() {
          data = result;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to load. Check your connection and try again.',
        );
      }
    } finally {
      loading = false;
    }
  }

  Future<void> roomDialog(String action) async {
    final args = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RoomEntryDialog(action: action),
    );
    if (args == null || !mounted) return;
    setState(() => busy = true);
    try {
      await CommunityService.action(action, args);
      await load();
    } on PostgrestException catch (e) {
      if (mounted) notice(e.message);
    } catch (_) {
      if (mounted) notice('Unable to connect. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.tr(message))));
  Future<void> profile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    await load();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn =
        CommunityService.configured &&
        CommunityService.client.auth.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Worship together')),
        actions: [
          if (loggedIn)
            IconButton(
              tooltip: context.tr('Profile'),
              icon: const Icon(Icons.person_outline),
              onPressed: profile,
            ),
        ],
      ),
      body: !CommunityService.configured
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    'Online worship is being prepared. You can continue using all offline features.',
                  ),
                ),
              ),
            )
          : !loggedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_outlined, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      context.tr(
                        'Sign in to join rooms and encourage your friends.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                        await load();
                        if (mounted) setState(() {});
                      },
                      child: Text(context.tr('Log in')),
                    ),
                  ],
                ),
              ),
            )
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr(error!)),
                  TextButton(onPressed: load, child: Text(context.tr('Retry'))),
                ],
              ),
            )
          : data == null
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: context.tr('Rooms')),
                      Tab(text: context.tr('Weekly reports')),
                    ],
                  ),
                  if (busy) const LinearProgressIndicator(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        RefreshIndicator(
                          onRefresh: load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                context.tr(
                                  'Grow together, one good deed at a time.',
                                ),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr(
                                  'Tasks are self-reported. Points encourage consistency; they do not measure faith.',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final e in {
                                    'create': 'Create room',
                                    'join': 'Request to join',
                                    'invite': 'Private challenge',
                                  }.entries)
                                    OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => roomDialog(e.key),
                                      child: Text(context.tr(e.value)),
                                    ),
                                ],
                              ),
                              if ((data!['rooms'] as List).isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    context.tr(
                                      'Create a room or request to join using its reference.',
                                    ),
                                  ),
                                ),
                              for (final r in data!['rooms'])
                                roomCard(Map<String, dynamic>.from(r)),
                            ],
                          ),
                        ),
                        RefreshIndicator(
                          onRefresh: load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                context.tr(
                                  'Friday–Thursday · Cairo time. Reports arrive after each week ends.',
                                ),
                              ),
                              if ((data!['reports'] as List).isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    context.tr(
                                      'Your first report will appear after this week ends.',
                                    ),
                                  ),
                                ),
                              for (final r in data!['reports'])
                                WeeklyReportCard(
                                  report: Map<String, dynamic>.from(r),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget roomCard(Map<String, dynamic> room) {
    final members = (room['members'] as List)
        .where((m) => m['status'] == 'accepted')
        .length;
    final due = (room['tasks'] as List)
        .where((t) => t['due_today'] == true)
        .toList();
    final done = (room['completed'] as List)
        .where((id) => due.any((t) => taskKey(t) == id))
        .length;
    final status = switch (room['status']) {
      'accepted' =>
        '$members ${context.tr('members')} · $done/${due.length} ${context.tr('tasks completed')}',
      'invited' => context.tr('Invitation pending'),
      _ => context.tr('Join request pending'),
    };
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          room['private'] ? Icons.lock_outline : Icons.groups_outlined,
        ),
        title: Text(room['name']),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(status),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RoomDetailScreen(initialRoom: room, today: data!['today']),
            ),
          );
          await load();
        },
      ),
    );
  }
}

class RoomEntryDialog extends StatefulWidget {
  const RoomEntryDialog({super.key, required this.action});
  final String action;
  @override
  State<RoomEntryDialog> createState() => _RoomEntryDialogState();
}

class _RoomEntryDialogState extends State<RoomEntryDialog> {
  final first = TextEditingController();
  final friend = TextEditingController();
  final form = GlobalKey<FormState>();
  bool templates = true;
  @override
  void dispose() {
    first.dispose();
    friend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final join = widget.action == 'join';
    final invite = widget.action == 'invite';
    return AlertDialog(
      title: Text(
        context.tr(
          join
              ? 'Request to join'
              : invite
              ? 'Private challenge'
              : 'Create room',
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: first,
                maxLength: join ? 8 : 80,
                keyboardType: join ? TextInputType.number : TextInputType.text,
                decoration: InputDecoration(
                  labelText: context.tr(join ? 'Room reference' : 'Room name'),
                ),
                validator: (v) => join
                    ? (RegExp(r'^\d{8}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : context.tr('Enter the 8 digit reference'))
                    : ((v?.trim().length ?? 0) < 2
                          ? context.tr('Use at least 2 characters')
                          : null),
              ),
              if (invite)
                TextFormField(
                  controller: friend,
                  maxLength: 12,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: context.tr('Friend code'),
                  ),
                  validator: (v) =>
                      RegExp(r'^[a-fA-F0-9]{12}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : context.tr('Enter the 12 character friend code'),
                ),
              if (!join)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: templates,
                  onChanged: (v) => setState(() => templates = v!),
                  title: Text(context.tr('Start with daily worship templates')),
                  subtitle: Text(
                    context.tr(
                      'Add custom tasks, points and schedules in room details.',
                    ),
                  ),
                ),
              if (invite)
                Text(
                  context.tr('Private room · invitations by friend code only'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, {
                join ? 'ref' : 'name': first.text.trim(),
                'friend_code': friend.text.trim(),
                'use_templates': templates,
              });
            }
          },
          child: Text(context.tr('Send')),
        ),
      ],
    );
  }
}
