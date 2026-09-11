// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Viva';

  @override
  String get appTagline => 'Find someone who feels like home.';

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Name or Member ID (e.g. VIVA001234)';

  @override
  String get searchByMemberId => 'Searching by Member ID';

  @override
  String get noProfilesFound => 'No profiles found';

  @override
  String get tryAdjustingFilters =>
      'Try adjusting your filters to see more results.';

  @override
  String profilesFound(int count) {
    return '$count profiles found';
  }

  @override
  String get sendInterest => 'Send Interest';

  @override
  String get interestSent => '✓ Interest Sent';

  @override
  String get shortlisted => 'Shortlisted';

  @override
  String get noShortlist => 'No profiles shortlisted';

  @override
  String get noShortlistSubtitle =>
      'Tap the bookmark icon on any profile to save them here.';

  @override
  String get verified => 'Verified';

  @override
  String get getVerified => 'Get verified';

  @override
  String get verificationStatus => 'Verification Status';

  @override
  String get underReview => 'Under review';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get community => 'Community';

  @override
  String get caste => 'Caste';

  @override
  String get subCaste => 'Sub-caste';

  @override
  String get gotra => 'Gotra';

  @override
  String get religion => 'Religion';

  @override
  String get communityAndTraditions => 'Community & Traditions';

  @override
  String get profileComplete => 'Profile Complete ✓';

  @override
  String get profileCompletion => 'Profile Completion';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get myProfile => 'My Profile';

  @override
  String get personalDetails => 'Personal Details';

  @override
  String get education => 'Education';

  @override
  String get career => 'Career';

  @override
  String get family => 'Family';

  @override
  String get lifestyle => 'Lifestyle';

  @override
  String get about => 'About';

  @override
  String get nativePlace => 'Native Place';

  @override
  String get location => 'Location';

  @override
  String get whoViewedMe => 'Who Viewed My Profile';

  @override
  String get noProfileViewsYet => 'No profile views yet';

  @override
  String get noProfileViewsSubtitle =>
      'When someone views your profile, they\'ll appear here.';

  @override
  String get mutualMatches => 'Mutual Matches';

  @override
  String get noConnectionsYet => 'No connections yet';

  @override
  String get noConnectionsSubtitle =>
      'When an interest you sent or received is accepted, they\'ll appear here.';

  @override
  String get biodata => 'Matrimonial Biodata';

  @override
  String get generate => 'Generate Biodata';

  @override
  String get regenerate => 'Regenerate Biodata';

  @override
  String get download => 'Download PDF';

  @override
  String get share => 'Share';

  @override
  String get biodataReady => 'Biodata ready to download';

  @override
  String get biodataGenerating => 'Generating…';

  @override
  String get biodataStale => 'Profile updated — regenerate to refresh';

  @override
  String get biodataNotGenerated => 'Not yet generated';

  @override
  String get lastActive => 'Last active';

  @override
  String get activeToday => 'Active today';

  @override
  String get activeYesterday => 'Active yesterday';

  @override
  String get activeThisWeek => 'Active this week';

  @override
  String get activeThisMonth => 'Active this month';

  @override
  String get justNow => 'Just now';

  @override
  String compatibilityScore(int score) {
    return '$score% Compatible';
  }

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language / भाषा';

  @override
  String get selectLanguage => 'Select Language / भाषा चुनें';

  @override
  String get privacySettings => 'Privacy Settings';

  @override
  String get notificationPreferences => 'Notification Preferences';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get reportProfile => 'Report Profile';

  @override
  String get connections => 'Connections';

  @override
  String get noConnectionsMessage => 'Accept interests to start connecting.';

  @override
  String get filters => 'Filters';

  @override
  String get resetAll => 'Reset all';

  @override
  String get applyFilters => 'Apply Filters';

  @override
  String get ageRange => 'Age Range';

  @override
  String get height => 'Height';

  @override
  String get age => 'Age';

  @override
  String get gender => 'Gender';

  @override
  String get maritalStatus => 'Marital Status';

  @override
  String get motherTongue => 'Mother Tongue';

  @override
  String get profession => 'Profession';

  @override
  String get degree => 'Degree';

  @override
  String get field => 'Field';

  @override
  String get college => 'College';

  @override
  String get company => 'Company';

  @override
  String get income => 'Income';

  @override
  String get siblings => 'Siblings';

  @override
  String get familyType => 'Family Type';

  @override
  String get values => 'Values';

  @override
  String get diet => 'Diet';

  @override
  String get smoking => 'Smoking';

  @override
  String get drinking => 'Drinking';

  @override
  String get partnerPreferences => 'Partner Preferences';

  @override
  String get completeProfile => 'Complete Profile';

  @override
  String get logOut => 'Log Out';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get saveAndContinue => 'Save & Continue';

  @override
  String get continue_ => 'Continue';

  @override
  String get retry => 'Retry';

  @override
  String get goBack => 'Go Back';
}
