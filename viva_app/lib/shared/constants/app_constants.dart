/// App-wide constants for Viva Matrimony.
class AppConstants {
  AppConstants._();

  // Supabase project credentials (anon/publishable key — safe to embed in client)
  // Set via --dart-define at build time; defaults to your project values.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qzjxluqbqlziqimgadgl.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6anhsdXFicWx6aXFpbWdhZGdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwODM1MzYsImV4cCI6MjEwMzY1OTUzNn0.yqCDkPZ7sLHCzWMVZ5ksWX3DkWhtVV9IhW9XxcLz5Os',
  );

  // API base URL. Override at build time for staging/other environments:
  //   flutter build apk --dart-define=API_BASE_URL=https://staging.example.com/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.vivamatrimony.in/api/v1',
  );

  // Timeouts — generous to handle Render free-tier cold start (~30-50s)
  static const int connectTimeoutMs = 60000;
  static const int receiveTimeoutMs = 60000;

  // Storage keys (app-level only — Supabase SDK manages its own session keys)
  static const String memberIdKey = 'viva_member_id';
  static const String onboardingCompletedKey = 'viva_onboarding_done';

  // Photo limits
  static const int maxPhotos = 10;
  static const int maxPhotoSizeMB = 10;

  // Pagination
  static const int defaultPageSize = 20;

  // Height range (cm)
  static const int minHeightCm = 140;
  static const int maxHeightCm = 220;

  // Age range
  static const int minAge = 18;
  static const int maxAge = 70;

  // Document size limit (certificates, biodata uploads)
  static const int maxCertSizeMB = 20;

  // Verification SLA strings
  static const String verificationSlaDays = '1-2 business days';
  static const String reportReviewHours = '24-48 hours';

  // India country code — used by reference verification phone field
  static const String indiaCode = '+91';

  // Onboarding step labels (matches AppRoutes onboarding order)
  static const List<String> onboardingSteps = [
    'Basic Info',
    'About You',
    'Education',
    'Career',
    'Family',
    'Lifestyle',
    'Native Place',
    'Preferences',
    'Photos',
  ];

  // App info
  static const String appName = 'Viva';
  static const String appTagline = 'Find someone who feels like home.';
  static const String supportEmail = 'support@vivamatrimony.in';
  static const String privacyPolicyUrl = 'https://vivamatrimony.in/privacy';
  static const String termsUrl = 'https://vivamatrimony.in/terms';
  static const String appVersion = '1.0.0';
}

/// Route path constants.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String welcome = '/welcome';

  // Onboarding
  static const String onboardingBasic = '/onboarding/basic';
  static const String onboardingBio = '/onboarding/bio';
  static const String onboardingEducation = '/onboarding/education';
  static const String onboardingCareer = '/onboarding/career';
  static const String onboardingFamily = '/onboarding/family';
  static const String onboardingLifestyle = '/onboarding/lifestyle';
  static const String onboardingNativePlace = '/onboarding/native-place';
  static const String onboardingPreferences = '/onboarding/preferences';
  static const String onboardingPhotos = '/onboarding/photos';

  // Verification
  static const String verificationSelect = '/verification/select';
  static const String verificationReference = '/verification/reference';
  static const String verificationCertificate = '/verification/certificate';
  static const String verificationStatus = '/verification/status';

  // Main app shell
  static const String home = '/home';
  static const String search = '/search';
  static const String interests = '/interests';
  static const String connections = '/connections';
  static const String myProfile = '/profile/me';

  // Detail screens
  static const String profileDetail = '/profile/:userId';
  static const String biodata = '/biodata';

  // Settings
  static const String settings = '/settings';
  static const String privacy = '/settings/privacy';
  static const String helpSupport = '/settings/help';
  static const String reportUser = '/report/:userId';
  static const String editProfile = '/profile/edit';
  static const String notifications = '/notifications';
  static const String shortlist = '/shortlist';
  static const String whoViewedMe = '/profile/viewers';
  static const String mutualMatches = '/interests/mutual';
  static const String onboardingCommunity = '/onboarding/community';
}
