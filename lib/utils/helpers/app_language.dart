import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/services/prayer_home_widget_service.dart';
import 'package:flutter/material.dart';

class AppLanguage {
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('ar'));

  static void loadSavedLanguage() {
    final code = HiveManager.getMeta('language', defaultValue: 'ar').toString();
    locale.value = Locale(code == 'ar' ? 'ar' : 'en');
  }

  static Future<void> setLanguage(String code) async {
    final normalized = code == 'ar' ? 'ar' : 'en';
    await HiveManager.addUpdateMetaData('language', normalized);
    locale.value = Locale(normalized);
    final prayers = HiveManager.getPrayer();
    if (prayers.isNotEmpty) {
      try {
        await PrayerHomeWidgetService.update(prayers);
      } catch (error) {
        debugPrint('Unable to refresh prayer widget language: $error');
      }
    }
  }
}

extension AppTranslation on BuildContext {
  String tr(String english) {
    if (Localizations.localeOf(this).languageCode != 'ar') return english;
    return _arabicTranslations[english] ?? english;
  }
}

const Map<String, String> _arabicTranslations = {
  'Home': 'الرئيسية',
  'Qibla': 'القبلة',
  'Quran': 'القرآن الكريم',
  'Supplications': 'الأذكار والأدعية',
  'Menu': 'القائمة',
  'Settings': 'الإعدادات',
  'Sahih al-Bukhari': 'صحيح البخاري',
  'Browse chapters and search all hadiths':
      'تصفّح الأبواب وابحث في جميع الأحاديث',
  'Prayer location and app preferences': 'موقع الصلاة وتفضيلات التطبيق',
  'Language': 'اللغة',
  'English': 'الإنجليزية',
  'Arabic': 'العربية',
  'Location': 'الموقع',
  'Update': 'تحديث',
  'Play Adhan Audio': 'تشغيل صوت الأذان',
  'Vibration on Reminder': 'الاهتزاز عند التذكير',
  'Calculation Method': 'طريقة حساب مواقيت الصلاة',
  'Egyptian General Authority of Survey (Shafi)':
      'الهيئة المصرية العامة للمساحة (على المذهب الشافعي)',
  'Background Recalculation': 'إعادة حساب مواقيت الصلاة في الخلفية',
  'WorkManager periodic interval: Every 8 hours':
      'إعادة التحديث كل ٨ ساعات في الخلفية',
  'Current Prayer': 'الصلاة الحالية',
  'Next Prayer': 'الصلاة القادمة',
  'Update prayer times': 'تحديث مواقيت الصلاة',
  'Add prayer times widget': 'إضافة أداة مواقيت الصلاة',
  'Could not add widget:': 'تعذّر إضافة الأداة:',
  'left in Athan': 'متبقية على انتهاء وقت الصلاة',
  'until': 'حتى',
  'Fajr': 'الفجر',
  'Sunrise': 'الشروق',
  'Dhuhr': 'الظهر',
  'Asr': 'العصر',
  'Maghrib': 'المغرب',
  'Isha': 'العشاء',
  'Qibla Direction': 'اتجاه القبلة',
  '✨ You are facing the Holy Kaaba!': '✨ أنت تواجه الكعبة المشرفة!',
  'Turn your device until the needle points up':
      'حرّك جهازك حتى يشير المؤشر إلى الأعلى',
  'Compass sensor not detected. Showing calculated angle.':
      'لم يتم اكتشاف مستشعر البوصلة. يتم عرض الزاوية المحسوبة.',
  'Qibla Bearing': 'اتجاه القبلة',
  'Distance to Kaaba': 'المسافة إلى الكعبة',
  'Heading:': 'اتجاه الجهاز:',
  'km': 'كم',
  'Kaaba: 21.42° N, 39.83° E': 'الكعبة: ٢١٫٤٢° شمالًا، ٣٩٫٨٣° شرقًا',
  'North': 'شمال',
  'South': 'جنوب',
  'East': 'شرق',
  'West': 'غرب',
  'NE': 'شمال شرق',
  'NW': 'شمال غرب',
  'SE': 'جنوب شرق',
  'SW': 'جنوب غرب',
  'Northeast': 'شمال شرق',
  'Northwest': 'شمال غرب',
  'Southeast': 'جنوب شرق',
  'Southwest': 'جنوب غرب',
  'N': 'شمال',
  'E': 'شرق',
  'S': 'جنوب',
  'W': 'غرب',
  'Holy Quran': 'القرآن الكريم',
  'The Holy Quran': 'القرآن الكريم',
  '114 Surahs': '١١٤ سورة',
  'Verses': 'آية',
  'Meccan': 'مكية',
  'Medinan': 'مدنية',
  'Traditional Order (Tap to Read)': 'الترتيب المعتاد (اضغط للقراءة)',
  'Search Surah by name or number...': 'ابحث عن سورة بالاسم أو الرقم...',
  'Select Reciter': 'اختر قارئًا',
  'Choose your preferred audio reciter for Surahs & Verses':
      'اختر قارئك المفضل لسماع السور والآيات',
  'Select Audio Reciter': 'اختر قارئ الصوت',
  'Audio will stream from the selected reciter':
      'سيتم بث التلاوة من القارئ المحدد',
  'Change Reciter': 'تغيير القارئ',
  'Murattal': 'مرتّل',
  'Traditional recitation': 'تلاوة تقليدية',
  'Slow and clear': 'بطيء وواضح',
  'Melodious recitation': 'تلاوة عذبة',
  'Translation': 'الترجمة',
  'Transliteration': 'النقل الصوتي',
  'Cached': 'محفوظ',
  'Loading from cache...': 'جارٍ التحميل من الذاكرة...',
  'Failed to load Surah': 'تعذّر تحميل السورة',
  'Could not play Surah audio:': 'تعذّر تشغيل صوت السورة:',
  'Could not play Ayah audio:': 'تعذّر تشغيل صوت الآية:',
  'Retrieving Surah from API (one-time)...':
      'جارٍ جلب السورة من الخدمة لأول مرة...',
  'Surah': 'سورة',
  'Ayah': 'آية',
  'Revelation': 'ترتيب النزول',
  'Play Full Surah': 'تشغيل السورة كاملة',
  'Playing Surah': 'تشغيل سورة',
  'Playing Ayah': 'تشغيل الآية',
  'Retry': 'إعادة المحاولة',
  'Playing Full Surah': 'تشغيل السورة كاملة',
  'Playing': 'قيد التشغيل',
  'Audio': 'الصوت',
  'Athkar': 'الأذكار',
  'Daily Reminders': 'التذكيرات اليومية',
  'Pinned': 'مثبّتة',
  'Upcoming': 'القادمة',
  'No reminders added yet.': 'لم تُضف تذكيرات بعد.',
  'Add Reminder': 'إضافة تذكير',
  'Add New Reminder': 'إضافة تذكير جديد',
  'Edit Reminder': 'تعديل التذكير',
  'Save Changes': 'حفظ التعديلات',
  'Delete Reminder': 'حذف التذكير',
  'Next:': 'التالي:',
  'Repeat Options': 'خيارات التكرار',
  'Repeat (e.g. Daily, Weekly, Forever)': 'التكرار (يوميًا، أسبوعيًا، دائمًا)',
  'Custom': 'مخصص',
  'Forever': 'دائمًا',
  '7 Times': '٧ مرات',
  '30 Times': '٣٠ مرة',
  '100 Times': '١٠٠ مرة',
  'Sunnah': 'السنة النبوية',
  'Fasting': 'الصيام',
  'Prayer': 'الصلاة',
  'General': 'عام',
  'Delete "': 'حذف "',
  'Please enter a reminder title': 'يرجى إدخال عنوان التذكير',
  'Enter reminder title...': 'أدخل عنوان التذكير...',
  'Save': 'حفظ',
  'Done': 'تم',
  'Today': 'اليوم',
  'Tomorrow': 'غدًا',
  'No reminders yet': 'لا توجد تذكيرات بعد',
  'Repeat': 'التكرار',
  'Never': 'أبدًا',
  'Daily': 'يوميًا',
  'Weekly': 'أسبوعيًا',
  'Monthly': 'شهريًا',
  'Choose a supplication collection to begin.': 'اختر مجموعة أذكار للبدء.',
  'All prayers': 'جميع الصلوات',
  'Morning supplications': 'أذكار الصباح',
  'Evening supplications': 'أذكار المساء',
  'Tasbeeh': 'التسبيح',
  'Sleep supplications': 'أذكار النوم',
  'Wake-up supplications': 'أذكار الاستيقاظ',
  'Quranic supplications': 'أدعية قرآنية',
  'Prophets’ supplications': 'أدعية الأنبياء',
  'supplications': 'أذكار',
  'Reset Counters': 'إعادة ضبط العدادات',
  'Do you want to reset all Athkar counters to 0?':
      'هل تريد إعادة جميع عدادات الأذكار إلى الصفر؟',
  'Cancel': 'إلغاء',
  'Reset': 'إعادة الضبط',
  'Back to supplications': 'العودة إلى الأذكار',
  'Some supplications in this collection are specifically said after Fajr, after Maghrib, or after both prayers. Follow the note shown with each supplication.':
      'تُقال بعض أذكار هذه المجموعة بعد الفجر أو المغرب أو بعد كلتيهما. يُرجى اتباع الملاحظة المرفقة بكل ذكر.',
  'Post-Prayer Supplications': 'أذكار ما بعد الصلاة',
  'Progress:': 'التقدم:',
  'Tap to Count': 'اضغط للعد',
  'times': 'مرات',
  'Search Bukhari': 'البحث في صحيح البخاري',
  'Search all hadiths': 'ابحث في جميع الأحاديث',
  'Search Arabic or English text': 'ابحث بالعربية أو الإنجليزية',
  'Enter a word or phrase to search all hadiths.':
      'أدخل كلمة أو عبارة للبحث في جميع الأحاديث.',
  'No matching hadiths found.': 'لم يتم العثور على أحاديث مطابقة.',
  'Could not load the Bukhari collection.': 'تعذّر تحميل مجموعة صحيح البخاري.',
  'Hadith': 'حديث',
  'Chapter': 'باب',
  'Browse': 'تصفّح',
  'Select date': 'اختر التاريخ',
  'Select time': 'اختر الوقت',
  'Delete': 'حذف',
  'Prayer Times & Daily Dhikr': 'مواقيت الصلاة والأذكار اليومية',
  'AM': 'ص',
  'PM': 'م',
};
