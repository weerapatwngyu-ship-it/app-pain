import '../../core/i18n/app_locale.dart';

/// Thai weekday and month names, written out rather than pulled from intl,
/// which the project does not depend on and which would be a lot of weight
/// for a handful of strings.
const thaiWeekdays = [
  'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์',
];

const thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

const thaiMonthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

/// "12 ส.ค. 2568" — years are Buddhist, which is what a Thai reader expects
/// to see next to a date.
String thaiDate(DateTime date) =>
    '${date.day} ${thaiMonthsShort[date.month - 1]} ${date.year + 543}';

/// "12 สิงหาคม 2568". Used where the date is the point of the line rather
/// than a detail beside it — a date of birth on a medical record, say, where
/// an abbreviation saves nothing worth having.
String thaiDateFull(DateTime date) =>
    '${date.day} ${thaiMonthsFull[date.month - 1]} ${date.year + 543}';

const englishWeekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

const englishMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const englishMonthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "12 Aug 2025" — the Gregorian year, since a Buddhist year written in
/// English reads as a typo rather than as a date.
String englishDate(DateTime date) =>
    '${date.day} ${englishMonthsShort[date.month - 1]} ${date.year}';

String englishDateFull(DateTime date) =>
    '${date.day} ${englishMonthsFull[date.month - 1]} ${date.year}';

/// Whole years since [birthDate], as a chart shows an age.
int ageFrom(DateTime birthDate, {DateTime? asOf}) {
  final now = asOf ?? DateTime.now();
  var years = now.year - birthDate.year;
  final hadBirthday = now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!hadBirthday) years -= 1;
  return years;
}

/// The date in whichever language is showing, so a caller does not have to
/// branch on the locale every time it prints one.
String thaiOrEnglishDate(DateTime date) =>
    LocaleController.instance.isEnglish ? englishDate(date) : thaiDate(date);
