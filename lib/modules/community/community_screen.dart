import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:azan/services/community_service.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';

const worshipTasks = [
  'Fajr',
  'Dhuhr',
  'Asr',
  'Maghrib',
  'Isha',
  'Daily Quran',
  'Daily supplications',
];
int taskPoints(String task) => task == 'Daily Quran'
    ? 2
    : task == 'Daily supplications'
    ? 3
    : 1;
bool isWeakPoint(int done, int target) => target > 0 && done / target < .75;

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
  StreamSubscription<AuthState>? subscription;
  Timer? refreshTimer;
  bool loading = false;
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
      refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
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
    refreshTimer?.cancel();
    subscription?.cancel();
    super.dispose();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && CommunityService.configured) {
      load();
    }
  }

  Future<void> run(String action, Map<String, dynamic> args) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await CommunityService.action(action, args);
      await load();
    } on PostgrestException catch (e) {
      if (mounted) notice(e.message);
    } catch (_) {
      if (mounted) notice(context.tr('Unable to connect. Please try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> roomDialog(String action) async {
    final first = TextEditingController();
    final friend = TextEditingController();
    final form = GlobalKey<FormState>();
    final title = action == 'join'
        ? 'Request to join'
        : action == 'invite'
        ? 'Private challenge'
        : 'Create room';
    final args = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(title)),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: first,
                maxLength: action == 'join' ? 8 : 80,
                keyboardType: action == 'join'
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: context.tr(
                    action == 'join' ? 'Room reference' : 'Room name',
                  ),
                ),
                validator: (v) => action == 'join'
                    ? (RegExp(r'^\d{8}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : context.tr('Enter the 8 digit reference'))
                    : ((v?.trim().length ?? 0) < 2
                          ? context.tr('Use at least 2 characters')
                          : null),
              ),
              if (action == 'invite')
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
              Text(
                context.tr(
                  'Daily: 5 prayers × 1 point, Quran 2, supplications 3.',
                ),
              ),
            ],
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
                  action == 'join' ? 'ref' : 'name': first.text.trim(),
                  'friend_code': friend.text.trim(),
                });
              }
            },
            child: Text(context.tr('Send')),
          ),
        ],
      ),
    );
    // Dispose after the dialog route has finished its closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    first.dispose();
    friend.dispose();
    if (args != null && mounted) await run(action, args);
  }

  @override
  Widget build(BuildContext context) {
    final configured = CommunityService.configured;
    final loggedIn =
        configured && CommunityService.client.auth.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Worship together')),
        actions: [
          if (loggedIn)
            IconButton(
              tooltip: context.tr('Profile'),
              icon: const Icon(Icons.person_outline),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                await load();
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
      body: !configured
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
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
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
                                  for (final entry in {
                                    'create': 'Create room',
                                    'join': 'Request to join',
                                    'invite': 'Private challenge',
                                  }.entries)
                                    OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => roomDialog(entry.key),
                                      child: Text(context.tr(entry.value)),
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
                              for (final room in data!['rooms'])
                                roomCard(Map<String, dynamic>.from(room)),
                            ],
                          ),
                        ),
                        RefreshIndicator(
                          onRefresh: load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Text(
                                context.tr(
                                  'Monday–Sunday · Cairo time. Reports arrive after each week ends.',
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
                              for (final report in data!['reports'])
                                reportCard(Map<String, dynamic>.from(report)),
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
    final accepted = room['status'] == 'accepted';
    final mine = CommunityService.client.auth.currentUser!.id;
    final done = room['completed'] as List;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room['name'], style: Theme.of(context).textTheme.titleLarge),
            if (!room['private'])
              Row(
                children: [
                  Text('${context.tr('Room reference')}: ${room['ref']}'),
                  IconButton(
                    tooltip: context.tr('Copy'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: room['ref']));
                      if (mounted) notice(context.tr('Copied'));
                    },
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
            if (room['status'] == 'pending')
              Text(
                context.tr(
                  'Waiting for the room owner to approve your request.',
                ),
              ),
            if (room['status'] == 'invited') ...[
              Text(context.tr('You have been invited to a private challenge.')),
              Wrap(
                spacing: 8,
                children: [
                  for (final action in ['accept', 'decline'])
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => run(action, {'room_id': room['id']}),
                      child: Text(
                        context.tr(action == 'accept' ? 'Accept' : 'Decline'),
                      ),
                    ),
                ],
              ),
            ],
            if (accepted) ...[
              Text(
                '${context.tr('Today')}: ${data!['today']} · ${done.fold<int>(0, (sum, task) => sum + taskPoints(task))}/10 ${context.tr('points')}',
              ),
              for (final task in worshipTasks)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr(task)),
                  subtitle: Text('${taskPoints(task)} ${context.tr('points')}'),
                  value: done.contains(task),
                  onChanged: busy || done.contains(task)
                      ? null
                      : (_) => run('complete', {
                          'room_id': room['id'],
                          'task': task,
                          'day': data!['today'],
                        }),
                ),
              const Divider(),
              for (final member in room['members'])
                if (member['status'] == 'accepted')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${member['name']} ${member['user_id'] == mine ? '(${context.tr('You')})' : ''}',
                    ),
                  ),
              if (room['owner_id'] == mine)
                for (final member in room['members'])
                  if (member['status'] == 'pending')
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(member['name']),
                      subtitle: Text(context.tr('Join request')),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: context.tr('Accept'),
                            onPressed: busy
                                ? null
                                : () => run('accept', {
                                    'room_id': room['id'],
                                    'user_id': member['user_id'],
                                  }),
                            icon: const Icon(Icons.check),
                          ),
                          IconButton(
                            tooltip: context.tr('Decline'),
                            onPressed: busy
                                ? null
                                : () => run('decline', {
                                    'room_id': room['id'],
                                    'user_id': member['user_id'],
                                  }),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget reportCard(Map<String, dynamic> report) {
    final summary = report['summary'];
    return Card(
      child: ExpansionTile(
        title: Text(summary['room_name']),
        subtitle: Text('${context.tr('Week of')} ${report['week']}'),
        children: [
          for (final score in summary['scores'])
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${score['name']} · ${score['points']} ${context.tr('points')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final task in score['tasks'])
                    Text(
                      '${context.tr(task['task'])}: ${task['done']}/${task['target']}${isWeakPoint(task['done'], task['target']) ? ' · ${context.tr('Area to improve')}' : ''}',
                    ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      (score['tasks'] as List).any(
                            (t) => isWeakPoint(t['done'], t['target']),
                          )
                          ? 'Every new day is another chance. Choose one small habit and keep going.'
                          : 'Your consistency is growing. Keep encouraging each other!',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
