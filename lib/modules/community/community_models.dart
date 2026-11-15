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
String taskKey(Map task) => (task['series_id'] ?? task['id']) as String;
DateTime fridayAnchor(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day - ((date.weekday + 2) % 7));
String calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
