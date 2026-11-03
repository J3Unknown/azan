class UiHelpers {
  /// Formats date like: "Tuesday, 27 Oct"
  static String formatDate(DateTime dt, {bool arabic = false}) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (arabic) {
      const arabicDays = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      const arabicMonths = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      return '${arabicDays[dt.weekday - 1]}، ${_arabicDigits(dt.day.toString())} ${arabicMonths[dt.month - 1]}';
    }
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName, ${dt.day} $monthName';
  }

  /// Formats time to 12-hour format: "04:52 AM"
  static String formatTime12(DateTime dt, {bool arabic = false}) {
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = arabic
        ? (hour >= 12 ? 'م' : 'ص')
        : (hour >= 12 ? 'PM' : 'AM');
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final hourStr = hour.toString().padLeft(2, '0');
    final time = '$hourStr:$minute';
    return arabic ? '${_arabicDigits(time)} $period' : '$time $period';
  }

  static String _arabicDigits(String value) => value.replaceAllMapped(
    RegExp(r'[0-9]'),
    (match) => String.fromCharCode(0x0660 + int.parse(match[0]!)),
  );

  static String formatDigits(int value, {bool arabic = false}) =>
      arabic ? _arabicDigits(value.toString()) : value.toString();

  static String localizeDigits(String value, {bool arabic = false}) =>
      arabic ? _arabicDigits(value) : value;

  /// Formats duration to "HH:mm:ss"
  static String formatDuration(Duration d, {bool arabic = false}) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return localizeDigits('$hours:$minutes:$seconds', arabic: arabic);
  }
}
