// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authServiceHash() => r'0c29aaa4e68afc6b16ed104968784bedfa8bfed7';

/// Provider for the AuthService
///
/// This should be overridden in the widget tree with the actual implementation.
///
/// Copied from [authService].
@ProviderFor(authService)
final authServiceProvider = Provider<AuthService>.internal(
  authService,
  name: r'authServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthServiceRef = ProviderRef<AuthService>;
String _$authEventBusHash() => r'e22fc789307c885d58c50fa416c5a5c65653c410';

/// Provider for the AuthEventBus
///
/// This should be overridden in the widget tree with the actual implementation.
///
/// Copied from [authEventBus].
@ProviderFor(authEventBus)
final authEventBusProvider = Provider<AuthEventBus>.internal(
  authEventBus,
  name: r'authEventBusProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authEventBusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthEventBusRef = ProviderRef<AuthEventBus>;
String _$autofillServiceHash() => r'b2fab5c61774e709f4ecfaca8f7150f54902ae07';

/// Provider for the AutofillService
///
/// This should be overridden in the widget tree with the actual implementation.
///
/// Copied from [autofillService].
@ProviderFor(autofillService)
final autofillServiceProvider = Provider<AutofillService>.internal(
  autofillService,
  name: r'autofillServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$autofillServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AutofillServiceRef = ProviderRef<AutofillService>;
String _$authNotifierHash() => r'189905938c9ee3e8b8140c35cccd02a78e8093cf';

/// Manages authentication state for the application
///
/// This notifier connects the UI layer to the domain service
/// and encapsulates authentication state management.
///
/// Copied from [AuthNotifier].
@ProviderFor(AuthNotifier)
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>.internal(
  AuthNotifier.new,
  name: r'authNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthNotifier = Notifier<AuthState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
