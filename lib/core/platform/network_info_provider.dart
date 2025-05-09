import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';

/// Riverpod provider that exposes the [NetworkInfo] implementation registered
/// in the global GetIt service locator. This allows tests (and production code)
/// to override the provider easily while keeping runtime look-ups decoupled.
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  // Resolve the concrete implementation from the global GetIt locator.
  // Using get<T>() improves readability over the tear-off syntax.
  return GetIt.instance.get<NetworkInfo>();
});
