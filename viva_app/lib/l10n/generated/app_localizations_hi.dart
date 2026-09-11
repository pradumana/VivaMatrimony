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
  String get search => 'खोजें';

  @override
  String get searchHint => 'नाम या सदस्य ID (जैसे VIVA001234)';

  @override
  String get searchByMemberId => 'सदस्य ID से खोज रहे हैं';

  @override
  String get noProfilesFound => 'कोई प्रोफ़ाइल नहीं मिली';

  @override
  String get tryAdjustingFilters => 'अधिक परिणामों के लिए अपने फ़िल्टर बदलें।';

  @override
  String profilesFound(int count) {
    return '$count प्रोफ़ाइल मिलीं';
  }

  @override
  String get sendInterest => 'रुचि भेजें';

  @override
  String get interestSent => '✓ रुचि भेजी गई';

  @override
  String get shortlisted => 'सूचीबद्ध';

  @override
  String get noShortlist => 'कोई प्रोफ़ाइल सूचीबद्ध नहीं';

  @override
  String get noShortlistSubtitle => 'किसी भी प्रोफ़ाइल पर बुकमार्क आइकन दबाएं।';

  @override
  String get verified => 'सत्यापित';

  @override
  String get getVerified => 'सत्यापन करें';

  @override
  String get verificationStatus => 'सत्यापन स्थिति';

  @override
  String get underReview => 'समीक्षाधीन';

  @override
  String get needsAttention => 'ध्यान चाहिए';

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
  String get communityAndTraditions => 'समुदाय और परंपराएं';

  @override
  String get profileComplete => 'प्रोफ़ाइल पूर्ण ✓';

  @override
  String get profileCompletion => 'प्रोफ़ाइल पूर्णता';

  @override
  String get editProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get myProfile => 'मेरी प्रोफ़ाइल';

  @override
  String get personalDetails => 'व्यक्तिगत विवरण';

  @override
  String get education => 'शिक्षा';

  @override
  String get career => 'करियर';

  @override
  String get family => 'परिवार';

  @override
  String get lifestyle => 'जीवनशैली';

  @override
  String get about => 'परिचय';

  @override
  String get nativePlace => 'मूल स्थान';

  @override
  String get location => 'स्थान';

  @override
  String get whoViewedMe => 'मेरी प्रोफ़ाइल किसने देखी';

  @override
  String get noProfileViewsYet => 'अभी तक कोई प्रोफ़ाइल दृश्य नहीं';

  @override
  String get noProfileViewsSubtitle =>
      'जब कोई आपकी प्रोफ़ाइल देखेगा, वे यहाँ दिखेंगे।';

  @override
  String get mutualMatches => 'आपसी मेल';

  @override
  String get noConnectionsYet => 'अभी कोई संपर्क नहीं';

  @override
  String get noConnectionsSubtitle =>
      'जब कोई रुचि स्वीकार की जाएगी, वे यहाँ दिखेंगे।';

  @override
  String get biodata => 'विवाह बायोडेटा';

  @override
  String get generate => 'बायोडेटा बनाएं';

  @override
  String get regenerate => 'बायोडेटा फिर से बनाएं';

  @override
  String get download => 'PDF डाउनलोड करें';

  @override
  String get share => 'साझा करें';

  @override
  String get biodataReady => 'बायोडेटा डाउनलोड के लिए तैयार';

  @override
  String get biodataGenerating => 'बन रहा है…';

  @override
  String get biodataStale => 'प्रोफ़ाइल अपडेट हुई — फिर से बनाएं';

  @override
  String get biodataNotGenerated => 'अभी नहीं बनाया';

  @override
  String get lastActive => 'अंतिम सक्रिय';

  @override
  String get activeToday => 'आज सक्रिय';

  @override
  String get activeYesterday => 'कल सक्रिय';

  @override
  String get activeThisWeek => 'इस सप्ताह सक्रिय';

  @override
  String get activeThisMonth => 'इस महीने सक्रिय';

  @override
  String get justNow => 'अभी';

  @override
  String compatibilityScore(int score) {
    return '$score% मेल';
  }

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get language => 'भाषा';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get privacySettings => 'गोपनीयता सेटिंग्स';

  @override
  String get notificationPreferences => 'सूचना प्राथमिकताएं';

  @override
  String get helpAndSupport => 'सहायता और समर्थन';

  @override
  String get deleteAccount => 'खाता हटाएं';

  @override
  String get reportProfile => 'प्रोफ़ाइल रिपोर्ट करें';

  @override
  String get connections => 'संपर्क';

  @override
  String get noConnectionsMessage => 'जुड़ने के लिए रुचियां स्वीकार करें।';

  @override
  String get filters => 'फ़िल्टर';

  @override
  String get resetAll => 'सब रीसेट करें';

  @override
  String get applyFilters => 'फ़िल्टर लागू करें';

  @override
  String get ageRange => 'आयु सीमा';

  @override
  String get height => 'ऊंचाई';

  @override
  String get age => 'आयु';

  @override
  String get gender => 'लिंग';

  @override
  String get maritalStatus => 'वैवाहिक स्थिति';

  @override
  String get motherTongue => 'मातृभाषा';

  @override
  String get profession => 'पेशा';

  @override
  String get degree => 'डिग्री';

  @override
  String get field => 'विषय';

  @override
  String get college => 'कॉलेज';

  @override
  String get company => 'कंपनी';

  @override
  String get income => 'आय';

  @override
  String get siblings => 'भाई-बहन';

  @override
  String get familyType => 'परिवार का प्रकार';

  @override
  String get values => 'मूल्य';

  @override
  String get diet => 'आहार';

  @override
  String get smoking => 'धूम्रपान';

  @override
  String get drinking => 'शराब';

  @override
  String get partnerPreferences => 'पार्टनर की प्राथमिकताएं';

  @override
  String get completeProfile => 'प्रोफ़ाइल पूर्ण करें';

  @override
  String get logOut => 'लॉग आउट';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सहेजें';

  @override
  String get saveAndContinue => 'सहेजें और जारी रखें';

  @override
  String get continue_ => 'जारी रखें';

  @override
  String get retry => 'पुनः प्रयास';

  @override
  String get goBack => 'वापस जाएं';
}
