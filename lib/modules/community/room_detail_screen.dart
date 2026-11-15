import 'dart:async';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:azan/services/community_service.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'task_editor_screen.dart';
import 'community_models.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({
    super.key,
    required this.initialRoom,
    required this.today,
  });
  final Map<String, dynamic> initialRoom;
  final String today;
  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen>
    with WidgetsBindingObserver {
  late Map<String, dynamic>? room = widget.initialRoom;
  late String today = widget.today;
  bool busy = false;
  bool loading = false;
  String? error;
  Timer? timer;
  String get mine => CommunityService.client.auth.currentUser?.id ?? '';
  bool get owner => room?['owner_id'] == mine;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          !busy) {
        refresh();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    try {
      final data = await CommunityService.dashboard();
      final rooms = (data['rooms'] as List).where(
        (r) => r['id'] == widget.initialRoom['id'],
      );
      if (mounted) {
        setState(() {
          room = rooms.isEmpty ? null : Map<String, dynamic>.from(rooms.first);
          today = data['today'];
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

  void notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.tr(message))));
  Future<void> action(
    String name, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await CommunityService.action(name, {
        'room_id': widget.initialRoom['id'],
        ...args,
      });
      if (name == 'delete_room') {
        if (mounted) Navigator.pop(context);
        return;
      }
      await refresh();
    } on PostgrestException catch (e) {
      if (mounted) notice(e.message);
    } catch (_) {
      if (mounted) notice('Unable to connect. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> inviteFriend() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const FriendCodeDialog(),
    );
    if (code != null && mounted) {
      await action('invite_member', {'friend_code': code});
    }
  }

  Future<void> deleteRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete room?')),
        content: Text(
          context.tr(
            'This permanently removes the room, tasks, completions and reports for every member.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Delete room')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await action('delete_room');
  }

  Future<void> removeMember(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove member?')),
        content: Text(
          '${member['name']}\n${context.tr('This member will lose access to this room. Past completions and earned points are kept. Joining again requires approval or an invitation.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Remove member')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await action('remove_member', {'user_id': member['user_id']});
    }
  }

  Future<void> addTask([Map<String, dynamic>? task]) async {
    final args = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditorScreen(
          today: today,
          task: task,
          existingNames: [
            for (final t in room!['tasks'])
              if (t['retired_on'] == null &&
                  (task == null || taskKey(t) != taskKey(task)))
                t['name'] as String,
          ],
        ),
      ),
    );
    if (args != null && mounted) {
      await action(task == null ? 'add_task' : 'update_task', {
        if (task != null) 'task_id': task['id'],
        ...args,
      });
    }
  }

  Future<void> removeTask(Map<String, dynamic> task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove task?')),
        content: Text(
          context.tr(
            'The task is removed from the schedule. Previous completions and earned points are kept.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Remove task')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await action('remove_task', {'task_id': task['id']});
    }
  }

  Widget hostTaskActions(Map<String, dynamic> task) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : () => addTask(task),
          icon: const Icon(Icons.edit_outlined),
          label: Text(context.tr('Edit task')),
        ),
        TextButton.icon(
          onPressed: busy ? null : () => removeTask(task),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          icon: const Icon(Icons.delete_outline),
          label: Text(context.tr('Remove task')),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final current = room;
    final accepted = current?['status'] == 'accepted';
    final tasks = current == null ? <dynamic>[] : current['tasks'] as List;
    final due = tasks.where((t) => t['due_today'] == true).toList();
    final completed = current == null
        ? <dynamic>[]
        : current['completed'] as List;
    return Scaffold(
      appBar: AppBar(
        title: Text(current?['name'] ?? context.tr('Room details')),
        actions: [
          if (owner)
            IconButton(
              tooltip: context.tr('Delete room'),
              onPressed: busy ? null : deleteRoom,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: current == null
          ? Center(child: Text(context.tr('This room is no longer available.')))
          : RefreshIndicator(
              onRefresh: refresh,
              child: Center(
                child: ListView(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (busy) const LinearProgressIndicator(),
                    if (error != null)
                      TextButton(
                        onPressed: refresh,
                        child: Text(context.tr(error!)),
                      ),
                    if (current['private'])
                      Text(
                        textAlign: TextAlign.center,
                        context.tr(
                          'Private room · invitations by friend code only',
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              '${context.tr('Room reference')}: ${current['ref']}',
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr('Copy'),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: current['ref']),
                              );
                              if (mounted) notice('Copied');
                            },
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                    if (current['status'] == 'pending')
                      Text(
                        textAlign: TextAlign.center,
                        context.tr(
                          'Waiting for the room owner to approve your request.',
                        ),
                      ),
                    if (current['status'] == 'invited') ...[
                      Text(
                        textAlign: TextAlign.center,
                        context.tr(
                          'You have been invited to a private challenge.',
                        ),
                      ),
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final choice in ['accept', 'decline'])
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: choice == "accept"
                                    ? ColorsManager.primaryGold
                                    : ColorsManager.white,
                                foregroundColor: ColorsManager.black,
                              ),
                              onPressed: busy ? null : () => action(choice),
                              child: Text(
                                context.tr(
                                  choice == 'accept' ? 'Accept' : 'Decline',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (accepted) ...[
                      const SizedBox(height: 16),
                      Text(
                        '${context.tr('Today')}: $today',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${completed.where((id) => due.any((t) => taskKey(t) == id)).length}/${due.length} ${context.tr('tasks completed')}',
                      ),
                      if (owner)
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: busy ? null : () => addTask(),
                              icon: const Icon(Icons.add),
                              label: Text(context.tr('Add task')),
                            ),
                            if (current['private'])
                              OutlinedButton.icon(
                                onPressed: busy ? null : inviteFriend,
                                icon: const Icon(Icons.person_add_outlined),
                                label: Text(
                                  context.tr('Invite by friend code'),
                                ),
                              ),
                          ],
                        ),
                      if (due.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            context.tr('No tasks scheduled for today.'),
                          ),
                        ),
                      for (final task in tasks.where(
                        (t) =>
                            (owner && t['retired_on'] == null) ||
                            t['due_today'] == true ||
                            completed.contains(taskKey(t)),
                      ))
                        Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CheckboxListTile(
                                title: Text(context.tr(task['name'])),
                                subtitle: Text(
                                  [
                                    if ((task['description'] as String)
                                        .isNotEmpty)
                                      task['description'],
                                    '${task['points']} ${context.tr('points')}',
                                    taskSchedule(
                                      context,
                                      Map<String, dynamic>.from(task),
                                    ),
                                    if (task['retired_on'] != null)
                                      context.tr('Removed task · history kept'),
                                    if (task['due_today'] != true &&
                                        !completed.contains(taskKey(task)))
                                      context.tr('Not scheduled today'),
                                  ].join('\n'),
                                ),
                                value: completed.contains(taskKey(task)),
                                onChanged:
                                    busy ||
                                        (task['due_today'] != true &&
                                            !completed.contains(taskKey(task)))
                                    ? null
                                    : (checked) => action(
                                        checked == true
                                            ? 'complete'
                                            : 'uncomplete',
                                        {'task_id': task['id'], 'day': today},
                                      ),
                              ),
                              if (owner && task['retired_on'] == null)
                                hostTaskActions(
                                  Map<String, dynamic>.from(task),
                                ),
                            ],
                          ),
                        ),
                      const Divider(height: 32),
                      Text(
                        context.tr('Members and today’s progress'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final member in current['members'])
                        if (member['status'] == 'accepted')
                          Card(
                            child: ExpansionTile(
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (owner && member['user_id'] != mine)
                                    IconButton(
                                      tooltip: context.tr('Remove member'),
                                      onPressed: busy
                                          ? null
                                          : () => removeMember(
                                              Map<String, dynamic>.from(member),
                                            ),
                                      icon: const Icon(
                                        Icons.person_remove_outlined,
                                      ),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  const Icon(Icons.expand_more),
                                ],
                              ),
                              title: Text(
                                '${member['name']}${member['user_id'] == mine ? ' (${context.tr('You')})' : ''}',
                              ),
                              subtitle: Text(
                                '${member['points_today']} ${context.tr('points')} · ${(member['completed'] as List).where((id) => due.any((t) => taskKey(t) == id)).length}/${due.length}',
                              ),
                              children: [
                                if (due.isEmpty)
                                  Text(
                                    context.tr('No tasks scheduled for today.'),
                                  ),
                                for (final task in tasks.where(
                                  (t) =>
                                      t['due_today'] == true ||
                                      (member['completed'] as List).contains(
                                        taskKey(t),
                                      ),
                                ))
                                  ListTile(
                                    dense: true,
                                    leading: Icon(
                                      (member['completed'] as List).contains(
                                            taskKey(task),
                                          )
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color:
                                          (member['completed'] as List)
                                              .contains(taskKey(task))
                                          ? Colors.greenAccent
                                          : Colors.grey,
                                    ),
                                    title: Text(context.tr(task['name'])),
                                    trailing: Text(
                                      context.tr(
                                        (member['completed'] as List).contains(
                                              taskKey(task),
                                            )
                                            ? 'Completed'
                                            : 'Not completed',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      if (owner)
                        for (final member in current['members'])
                          if (member['status'] == 'pending')
                            ListTile(
                              title: Text(member['name']),
                              subtitle: Text(context.tr('Join request')),
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    tooltip: context.tr('Accept'),
                                    onPressed: busy
                                        ? null
                                        : () => action('accept', {
                                            'user_id': member['user_id'],
                                          }),
                                    icon: const Icon(Icons.check),
                                  ),
                                  IconButton(
                                    tooltip: context.tr('Decline'),
                                    onPressed: busy
                                        ? null
                                        : () => action('decline', {
                                            'user_id': member['user_id'],
                                          }),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                      if (owner)
                        for (final member in current['members'])
                          if (member['status'] == 'invited')
                            ListTile(
                              title: Text(member['name']),
                              subtitle: Text(context.tr('Invitation pending')),
                            ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class FriendCodeDialog extends StatefulWidget {
  const FriendCodeDialog({super.key});
  @override
  State<FriendCodeDialog> createState() => _FriendCodeDialogState();
}

class _FriendCodeDialogState extends State<FriendCodeDialog> {
  final code = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('Invite by friend code')),
    content: Form(
      key: form,
      child: TextFormField(
        controller: code,
        maxLength: 12,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: context.tr('Friend code')),
        validator: (v) => RegExp(r'^[a-fA-F0-9]{12}$').hasMatch(v?.trim() ?? '')
            ? null
            : context.tr('Enter the 12 character friend code'),
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
            Navigator.pop(context, code.text.trim());
          }
        },
        child: Text(context.tr('Send')),
      ),
    ],
  );
}
