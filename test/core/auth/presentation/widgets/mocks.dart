import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mock provider for testing that doesn't depend on auth_notifier internals
final testOfflineState = AuthState.initial().copyWith(isOffline: true);
final testOnlineState = AuthState.initial().copyWith(isOffline: false);

// A provider that can be used in tests instead of authNotifierProvider
final mockAuthProvider = Provider<AuthState>((ref) => AuthState.initial());
