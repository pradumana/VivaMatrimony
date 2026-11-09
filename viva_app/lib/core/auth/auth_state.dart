/// Auth states that drive all routing and UI decisions.
///
/// Firebase UIDs are strings (not UUIDs), so [userId] is [String?].
enum AuthStatus {
  /// Auth state is resolving (cold start, token refresh in progress).
  loading,

  /// Signed in and email verified. Full app access.
  authenticated,

  /// Signed in but email not yet verified. Blocked from protected routes.
  emailUnverified,

  /// Onboarding not completed. Routes to the onboarding flow.
  onboardingRequired,

  /// No signed-in user.
  unauthenticated,

  /// An unrecoverable error occurred. Routes to login.
  error,
}

class AuthState {
  final AuthStatus status;

  /// Firebase UID (String, e.g. "abc123XYZ456") — NOT a UUID.
  final String? userId;

  final String? email;
  final String? memberId;
  final bool onboardingCompleted;

  const AuthState({
    required this.status,
    this.userId,
    this.email,
    this.memberId,
    this.onboardingCompleted = false,
  });

  const AuthState.loading()
      : status = AuthStatus.loading,
        userId = null,
        email = null,
        memberId = null,
        onboardingCompleted = false;

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        userId = null,
        email = null,
        memberId = null,
        onboardingCompleted = false;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? email,
    String? memberId,
    bool? onboardingCompleted,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        email: email ?? this.email,
        memberId: memberId ?? this.memberId,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );
}
