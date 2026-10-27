import 'package:azan/models/reminder_model.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/utils/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<ReminderModel> _reminders = [];
  String _city = 'Cairo, Egypt';
  final DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  void _loadReminders() {
    final cachedCity = HiveManager.getMeta('city');
    if (cachedCity != null && cachedCity.toString().isNotEmpty) {
      _city = cachedCity.toString();
    }
    setState(() {
      _reminders = HiveManager.getReminders();
    });
  }

  Future<void> _togglePin(ReminderModel reminder) async {
    await HiveManager.togglePinReminder(reminder.id);
    _loadReminders();
  }

  Future<void> _deleteReminder(ReminderModel reminder) async {
    await HiveManager.deleteReminder(reminder.id);
    await cancelNotification(reminder.id.hashCode);
    _loadReminders();
  }

  Future<void> _toggleCompleted(ReminderModel reminder, bool? checked) async {
    reminder.isCompleted = checked ?? false;
    await HiveManager.updateReminder(reminder);
    if (reminder.isCompleted && reminder.repeatTimes != 0) {
      await scheduleReminderNotification(reminder);
    }
    _loadReminders();
  }

  Future<void> _editReminder(ReminderModel reminder) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddReminderBottomSheet(
        reminder: reminder,
        onReminderAdded: _loadReminders,
      ),
    );
  }

  void _openAddReminderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddReminderBottomSheet(
        onReminderAdded: () {
          _loadReminders();
        },
      ),
    );
  }

  FaIconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'quran':
        return FontAwesomeIcons.bookOpen;
      case 'sunnah':
        return FontAwesomeIcons.handsPraying;
      case 'fasting':
        return FontAwesomeIcons.moon;
      case 'prayer':
        return FontAwesomeIcons.mosque;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinnedReminders = _reminders.where((r) => r.isPinned).toList();
    final upcomingReminders = _reminders.where((r) => !r.isPinned).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Location & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: ColorsManager.primaryGold,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _city,
                        style: const TextStyle(
                          color: ColorsManager.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    UiHelpers.formatDate(_currentDate),
                    style: const TextStyle(
                      color: ColorsManager.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title and Add Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daily Reminders',
                    style: TextStyle(
                      color: ColorsManager.textPrimary,
                      fontSize: 24,
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: _openAddReminderSheet,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ColorsManager.primaryGold.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ColorsManager.primaryGold.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: ColorsManager.primaryGold,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pinned Section
              if (pinnedReminders.isNotEmpty) ...[
                const Text(
                  'Pinned',
                  style: TextStyle(
                    color: ColorsManager.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRemindersList(pinnedReminders),
                const SizedBox(height: 28),
              ],

              // Upcoming Section
              const Text(
                'Upcoming',
                style: TextStyle(
                  color: ColorsManager.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 12),
              if (upcomingReminders.isEmpty && pinnedReminders.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.calendarCheck,
                          color: ColorsManager.textMuted,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No reminders added yet.',
                          style: TextStyle(color: ColorsManager.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildRemindersList(upcomingReminders),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ColorsManager.primaryGold,
        foregroundColor: const Color(0xFF191A19),
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Reminder',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: _openAddReminderSheet,
      ),
    );
  }

  Widget _buildRemindersList(List<ReminderModel> list) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final reminder = list[index];
        return _buildReminderCard(reminder);
      },
    );
  }

  Widget _buildReminderCard(ReminderModel reminder) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF282826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reminder.isPinned
              ? ColorsManager.primaryGold.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Category label, Pin icon, Category Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reminder.category,
                style: const TextStyle(
                  color: ColorsManager.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _editReminder(reminder),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: ColorsManager.textMuted,
                    ),
                  ),
                  const SizedBox(width: 9),
                  GestureDetector(
                    onTap: () => _togglePin(reminder),
                    child: FaIcon(
                      reminder.isPinned
                          ? FontAwesomeIcons.thumbtack
                          : FontAwesomeIcons.mapPin,
                      size: 14,
                      color: reminder.isPinned
                          ? ColorsManager.primaryGold
                          : ColorsManager.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FaIcon(
                    _getCategoryIcon(reminder.category),
                    size: 14,
                    color: ColorsManager.primaryGold.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ],
          ),

          // Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 28,
                child: Checkbox(
                  value: reminder.isCompleted,
                  onChanged: (value) => _toggleCompleted(reminder, value),
                  activeColor: ColorsManager.primaryGold,
                  checkColor: const Color(0xFF191A19),
                  side: const BorderSide(color: ColorsManager.textMuted),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reminder.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: reminder.isCompleted
                        ? ColorsManager.textMuted
                        : ColorsManager.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    decoration: reminder.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
          if (reminder.isCompleted &&
              reminder.repeatTimes != 0 &&
              reminder.repeatInterval != 'none')
            Text(
              'Next: ${UiHelpers.formatDate(_nextReminderOccurrence(reminder))} · ${UiHelpers.formatTime12(reminder.reminderTime)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ColorsManager.primaryGold,
                fontSize: 10,
              ),
            ),

          // Time and Delete Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${UiHelpers.formatDate(reminder.reminderDate)} · ${UiHelpers.formatTime12(reminder.reminderTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ColorsManager.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showDeleteConfirmation(reminder),
                child: const Icon(
                  Icons.delete_outline,
                  color: ColorsManager.textMuted,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DateTime _nextReminderOccurrence(ReminderModel reminder) {
    var next = DateTime(
      reminder.reminderDate.year,
      reminder.reminderDate.month,
      reminder.reminderDate.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final interval = reminder.repeatInterval;
    // Checking a task completes today's occurrence, even if its scheduled
    // time is later in the day. Advance to a strictly later recurrence date.
    while (!next.isAfter(today)) {
      switch (interval) {
        case 'weekly':
          next = next.add(const Duration(days: 7));
          break;
        case 'monthly':
          final nextMonth = DateTime(next.year, next.month + 1, 1);
          final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
          next = DateTime(
            nextMonth.year,
            nextMonth.month,
            next.day.clamp(1, lastDay).toInt(),
          );
          break;
        default:
          next = next.add(const Duration(days: 1));
      }
    }
    return next;
  }

  void _showDeleteConfirmation(ReminderModel reminder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2A),
        title: const Text(
          'Delete Reminder',
          style: TextStyle(color: ColorsManager.textPrimary),
        ),
        content: Text(
          'Delete "${reminder.title}"?',
          style: const TextStyle(color: ColorsManager.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: ColorsManager.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteReminder(reminder);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AddReminderBottomSheet extends StatefulWidget {
  final VoidCallback onReminderAdded;
  final ReminderModel? reminder;

  const _AddReminderBottomSheet({required this.onReminderAdded, this.reminder});

  @override
  State<_AddReminderBottomSheet> createState() =>
      _AddReminderBottomSheetState();
}

class _AddReminderBottomSheetState extends State<_AddReminderBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  String _selectedCategory = 'Quran';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  bool _repeatEnabled = true;
  String _repeatInterval = 'daily';
  int _repeatTimes = -1; // -1 for forever

  final List<String> _categories = [
    'Quran',
    'Sunnah',
    'Fasting',
    'Prayer',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    if (reminder == null) return;
    _titleController.text = reminder.title;
    _selectedCategory = reminder.category;
    _selectedDate = reminder.reminderDate;
    _selectedTime = TimeOfDay.fromDateTime(reminder.reminderTime);
    _repeatEnabled = reminder.repeatTimes != 0;
    _repeatInterval = reminder.repeatInterval == 'none'
        ? 'daily'
        : reminder.repeatInterval;
    _repeatTimes = reminder.repeatTimes;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ColorsManager.primaryGold,
              surface: Color(0xFF282826),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ColorsManager.primaryGold,
              surface: Color(0xFF282826),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitReminder() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder title')),
      );
      return;
    }

    final reminderDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final existing = widget.reminder;
    final reminder = ReminderModel(
      id: existing?.id ?? 'reminder_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      reminderTime: reminderDateTime,
      reminderDate: _selectedDate,
      category: _selectedCategory,
      repeatTimes: _repeatEnabled ? _repeatTimes : 0,
      repeatInterval: _repeatEnabled ? _repeatInterval : 'none',
      isPinned: existing?.isPinned ?? false,
      isActive: existing?.isActive ?? true,
      isCompleted: existing?.isCompleted ?? false,
    );

    if (existing == null) {
      await HiveManager.addReminder(reminder);
    } else {
      await cancelNotification(reminder.id.hashCode);
      await HiveManager.updateReminder(reminder);
    }
    await scheduleReminderNotification(reminder);

    widget.onReminderAdded();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF282826),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.reminder == null
                      ? 'Add New Reminder'
                      : 'Edit Reminder',
                  style: TextStyle(
                    color: ColorsManager.primaryGold,
                    fontSize: 20,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: ColorsManager.textMuted),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title Input field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(color: ColorsManager.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Enter reminder title...',
                  hintStyle: TextStyle(color: ColorsManager.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Category Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF242422),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: ColorsManager.primaryGold,
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(
                        cat,
                        style: const TextStyle(
                          color: ColorsManager.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Date and Time Pickers Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: ColorsManager.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(
                                color: ColorsManager.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: ColorsManager.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedTime.format(context),
                              style: const TextStyle(
                                color: ColorsManager.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Repeat Options Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Repeat Options',
                      style: TextStyle(
                        color: ColorsManager.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Repeat (e.g. Daily, Weekly, Forever)',
                      style: TextStyle(
                        color: ColorsManager.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _repeatEnabled,
                  activeThumbColor: ColorsManager.primaryGold,
                  activeTrackColor: ColorsManager.primaryGoldDark.withValues(
                    alpha: 0.7,
                  ),
                  inactiveThumbColor: ColorsManager.textMuted,
                  inactiveTrackColor: const Color(0xFF1E1E1C),
                  onChanged: (val) {
                    setState(() {
                      _repeatEnabled = val;
                    });
                  },
                ),
              ],
            ),

            if (_repeatEnabled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _repeatInterval,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF242422),
                          items: const [
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text(
                                'Daily',
                                style: TextStyle(
                                  color: ColorsManager.textPrimary,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text(
                                'Weekly',
                                style: TextStyle(
                                  color: ColorsManager.textPrimary,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text(
                                'Monthly',
                                style: TextStyle(
                                  color: ColorsManager.textPrimary,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'custom',
                              child: Text(
                                'Custom',
                                style: TextStyle(
                                  color: ColorsManager.textPrimary,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _repeatInterval = v);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _repeatTimes,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF242422),
                          items: const [
                            DropdownMenuItem(
                              value: -1,
                              child: Text(
                                'Forever',
                                style: TextStyle(
                                  color: ColorsManager.primaryGold,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 7,
                              child: Text(
                                '7 Times',
                                style: TextStyle(
                                  color: ColorsManager.textPrimary,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text(
                                '30 Times',
                                style: TextStyle(
                                  color: ColorsManager.textPrimary,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 100,
                              child: Text(
                                '100 Times',
                                style: TextStyle(
                                  color: ColorsManager.textPrimary,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _repeatTimes = v);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsManager.primaryGold,
                  foregroundColor: const Color(0xFF191A19),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _submitReminder,
                child: Text(
                  widget.reminder == null ? 'Add Reminder' : 'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
