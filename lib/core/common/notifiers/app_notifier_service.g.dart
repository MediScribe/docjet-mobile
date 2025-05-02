// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notifier_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appNotifierServiceHash() =>
    r'e3660c741bcc2df1fe3ca49846bd97bd819dd8d5';

/// Notifier service for managing and displaying application-wide transient messages.
///
/// Manages a single [AppMessage] state, replacing the current message
/// when a new one is shown.
///
/// Copied from [AppNotifierService].
@ProviderFor(AppNotifierService)
final appNotifierServiceProvider =
    AutoDisposeNotifierProvider<AppNotifierService, AppMessage?>.internal(
  AppNotifierService.new,
  name: r'appNotifierServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appNotifierServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppNotifierService = AutoDisposeNotifier<AppMessage?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
