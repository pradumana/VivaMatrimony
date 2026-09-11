// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'विवा';

  @override
  String get appTagline => 'वो मिले जो घर जैसा लगे।';

  @override
  String get searchHint => 'नाम या सदस्य ID (जैसे VIVA001234)';

  @override
  String get noProfilesFound => 'कोई प्रोफ़ाइल नहीं मिली';

  @override
  String get tryAdjustingFilters => 'अधिक परिणामों के लिए अपने फ़िल्टर बदलें।';

  @override
  String get sendInterest => 'रुचि भेजें';

  @override
  String get interestSent => 'रुचि भेजी गई';

  @override
  String get shortlisted => 'सूचीबद्ध';

  @override
  String get verified => 'सत्यापित';

  @override
  String get community => 'समुदाय';

  @override
  String get caste => 'जाति';

  @override
  String get subCaste => 'उपजाति';

  @override
  String get gotra => 'गोत्र';

  @override
  String get religion => 'धर्म';

  @override
  String get profileComplete => 'प्रोफ़ाइल पूर्ण';

  @override
  String get profileCompletion => 'प्रोफ़ाइल पूर्णता';

  @override
  String get whoViewedMe => 'मेरी प्रोफ़ाइल किसने देखी';

  @override
  String get mutualMatches => 'आपसी मेल';

  @override
  String get biodata => 'विवाह बायोडेटा';

  @override
  String get generate => 'बायोडेटा बनाएं';

  @override
  String get download => 'PDF डाउनलोड करें';

  @override
  String get share => 'साझा करें';

  @override
  String get lastActive => 'अंतिम सक्रिय';

  @override
  String compatibilityScore(int score) {
    return '$score% मेल';
  }
}
