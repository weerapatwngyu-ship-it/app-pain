import 'package:flutter/foundation.dart';

import '../storage/local_database.dart';

enum AppLocale {
  th,
  en;

  static AppLocale parse(String? raw) =>
      raw == 'en' ? AppLocale.en : AppLocale.th;
}

/// Which language the app is speaking, and the one thing that changes it.
///
/// Held on the device rather than on the account: the language decides what
/// the sign-in screen says, and that screen runs before there is an account to
/// read a preference from.
///
/// A ChangeNotifier rather than an inherited widget so that [t] can be called
/// from anywhere — including outside a build, where a notification body or an
/// error message is being composed and there is no BuildContext to hand.
/// The tree is rebuilt by the listener installed in MediGoApp.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const _settingKey = 'locale';

  AppLocale _locale = AppLocale.th;
  AppLocale get locale => _locale;
  bool get isEnglish => _locale == AppLocale.en;

  /// Reads the stored choice. Called once at startup, before runApp, so the
  /// first screen is already in the right language rather than flicking over
  /// to it a frame later.
  Future<void> load() async {
    try {
      _locale = AppLocale.parse(
        await LocalDatabase.instance.setting(_settingKey),
      );
    } catch (error) {
      // A settings table that cannot be read is not a reason to fail to
      // start; Thai is the default anyway.
      debugPrint('locale load failed: $error');
    }
  }

  Future<void> set(AppLocale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      await LocalDatabase.instance.setSetting(_settingKey, locale.name);
    } catch (error) {
      // The switch already happened on screen. Losing it on next launch is
      // better than refusing to switch at all.
      debugPrint('locale save failed: $error');
    }
  }
}

/// The Thai text, or the English one when English is chosen.
///
/// Both readings sit together at the point of use rather than behind a key in
/// a catalogue. With most of a Thai app already written, a key-per-string
/// catalogue would mean inventing ~1000 names and keeping two files in step
/// with the code by hand — and a screen half-migrated to keys shows blanks or
/// raw identifiers where a string was missed. Here a string nobody has
/// translated yet simply stays Thai, which is a working app rather than a
/// broken one, and translating it later is a local edit with the original
/// still in front of you.
String t(String th, String en) =>
    LocaleController.instance.isEnglish ? en : th;
