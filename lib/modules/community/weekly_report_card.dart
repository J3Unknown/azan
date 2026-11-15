import 'package:flutter/material.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'community_models.dart';

class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({
    super.key,
    required this.report,
    this.expanded = false,
  });
  final Map<String, dynamic> report;
  final bool expanded;
  @override
  Widget build(BuildContext context) {
    final summary = report['summary'];
    return Card(
      child: ExpansionTile(
        initiallyExpanded: expanded,
        title: Text(context.tr(summary['room_name'])),
        subtitle: Text(
          '${report['week']} → ${summary['ends_on'] ?? calendarDate(DateTime.parse(report['week']).add(const Duration(days: 6)))}',
        ),
        children: [
          for (final score in summary['scores'])
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${score['name']} · ${score['points']} ${context.tr('points')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  for (final task in score['tasks']) ...[
                    Text(
                      '${context.tr(task['task'])} · ${task['done']}/${task['target']}${isWeakPoint(task['done'], task['target']) ? ' · ${context.tr('Area to improve')}' : ''}',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 12),
                      child: LinearProgressIndicator(
                        value: task['target'] == 0
                            ? 0
                            : ((task['done'] as num) / (task['target'] as num))
                                  .clamp(0, 1)
                                  .toDouble(),
                        color: isWeakPoint(task['done'], task['target'])
                            ? Colors.orangeAccent
                            : Colors.greenAccent,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                  Text(
                    context.tr(
                      (score['tasks'] as List).any(
                            (t) => isWeakPoint(t['done'], t['target']),
                          )
                          ? 'Every new day is another chance. Choose one small habit and keep going.'
                          : 'Your consistency is growing. Keep encouraging each other!',
                    ),
                  ),
                  const Divider(height: 28),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
