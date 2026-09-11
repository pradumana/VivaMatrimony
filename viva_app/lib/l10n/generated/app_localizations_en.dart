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
  String get searchHint => 'Name or Member ID (e.g. VIVA001234)';

  @override
  String get noProfilesFound => 'No profiles found';

  @override
  String get tryAdjustingFilters =>
      'Try adjusting your filters to see more results.';

  @override
  String get sendInterest => 'Send Interest';

  @override
  String get interestSent => 'Interest Sent';

  @override
  String get shortlisted => 'Shortlisted';

  @override
  String get verified => 'Verified';

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
  String get profileComplete => 'Profile Complete';

  @override
  String get profileCompletion => 'Profile Completion';

  @override
  String get whoViewedMe => 'Who Viewed My Profile';

  @override
  String get mutualMatches => 'Mutual Matches';

  @override
  String get biodata => 'Matrimonial Biodata';

  @override
  String get generate => 'Generate Biodata';

  @override
  String get download => 'Download PDF';

  @override
  String get share => 'Share';

  @override
  String get lastActive => 'Last active';

  @override
  String compatibilityScore(int score) {
    return '$score% Compatible';
  }
}
