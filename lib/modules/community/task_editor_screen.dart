import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'community_models.dart';

const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({
    super.key,
    required this.today,
    required this.existingNames,
    this.task,
  });
  final String today;
  final List<String> existingNames;
  final Map<String, dynamic>? task;
  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final points = TextEditingController(text: '1');
  final description = TextEditingController();
  String repeats = 'daily';
  String template = 'Custom task';
  late DateTime starts = DateTime.parse(widget.today);
  late Set<int> days = {DateTime.parse(widget.today).weekday};
  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      name.text = task['name'];
      points.text = task['points'].toString();
      description.text = task['description'];
      repeats = task['repeats'];
      days = (task['weekdays'] as List).cast<int>().toSet();
      final original = DateTime.parse(task['start_date']);
      if (original.isAfter(starts)) starts = original;
    }
  }

  @override
  void dispose() {
    name.dispose();
    points.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr(widget.task == null ? 'Add task' : 'Edit task')),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: template,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('Start from a template'),
              ),
              items: [
                for (final t in ['Custom task', ...worshipTasks])
                  DropdownMenuItem(value: t, child: Text(context.tr(t))),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  template = v;
                  name.text = v == 'Custom task' ? '' : v;
                  points.text = v == 'Custom task'
                      ? '1'
                      : taskPoints(v).toString();
                });
              },
            ),
            TextFormField(
              controller: name,
              maxLength: 80,
              decoration: InputDecoration(labelText: context.tr('Task name')),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.length < 2) {
                  return context.tr('Use at least 2 characters');
                }
                if (widget.existingNames.any(
                  (n) => n.toLowerCase() == value.toLowerCase(),
                )) {
                  return context.tr(
                    'This room already has a task with that name',
                  );
                }
                return null;
              },
            ),
            TextFormField(
              controller: points,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              decoration: InputDecoration(
                labelText: context.tr('Points per completion'),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 1 || n > 1000
                    ? context.tr('Enter points from 1 to 1000')
                    : null;
              },
            ),
            TextFormField(
              controller: description,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.tr('Description (optional)'),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: repeats,
              decoration: InputDecoration(labelText: context.tr('Repeat')),
              items: [
                for (final entry in {
                  'daily': 'Every day',
                  'weekly': 'Selected weekdays',
                  'once': 'Once on a date',
                }.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(context.tr(entry.value)),
                  ),
              ],
              onChanged: (v) => setState(() => repeats = v!),
            ),
            if (repeats == 'weekly')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (var i = 1; i <= 7; i++)
                      FilterChip(
                        label: Text(context.tr(weekdayLabels[i - 1])),
                        selected: days.contains(i),
                        onSelected: (selected) => setState(
                          () => selected ? days.add(i) : days.remove(i),
                        ),
                      ),
                  ],
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.tr(repeats == 'once' ? 'Scheduled date' : 'Start date'),
              ),
              subtitle: Text(calendarDate(starts)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: starts,
                  firstDate: DateTime.parse(widget.today),
                  lastDate: DateTime.parse(
                    widget.today,
                  ).add(const Duration(days: 365 * 5)),
                );
                if (date != null && mounted) setState(() => starts = date);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                if (repeats == 'weekly' && days.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('Select at least one weekday')),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'name': name.text.trim(),
                  'points': int.parse(points.text),
                  'description': description.text.trim(),
                  'repeats': repeats,
                  'weekdays': days.toList()..sort(),
                  'start_date': calendarDate(starts),
                });
              },
              child: Text(
                context.tr(widget.task == null ? 'Add task' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String taskSchedule(BuildContext context, Map<String, dynamic> task) =>
    switch (task['repeats']) {
      'weekly' =>
        (task['weekdays'] as List)
            .map((day) => context.tr(weekdayLabels[(day as int) - 1]))
            .join(' · '),
      'once' => '${context.tr('Once on a date')} · ${task['start_date']}',
      _ => context.tr('Every day'),
    };
