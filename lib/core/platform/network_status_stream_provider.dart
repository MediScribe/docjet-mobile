import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docjet_mobile/core/platform/network_info_provider.dart';

/// Exposes the online/offline connectivity status as a `StreamProvider<bool>`.
///
/// Emits `true` when the device is online and `false` when it goes offline.
/// The underlying [NetworkInfo.onConnectivityChanged] stream already emits
/// distinct values, so we simply forward it.
final networkStatusStreamProvider = StreamProvider<bool>((ref) {
  final networkInfo = ref.watch(networkInfoProvider);
  return networkInfo.onConnectivityChanged;
});
