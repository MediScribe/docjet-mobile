/// Defines events related to authentication state changes.
enum AuthEvent {
  /// Event triggered when a user successfully logs in.
  loggedIn,

  /// Event triggered when a user logs out.
  loggedOut,

  /// Event triggered when the app detects it's offline during an authenticated session.
  offlineDetected,

  /// Event triggered when online connectivity is restored after being offline.
  onlineRestored,
}
