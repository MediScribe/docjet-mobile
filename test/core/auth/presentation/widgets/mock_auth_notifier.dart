import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockAuthNotifier extends Notifier<AuthState> {
  final AuthState _state;

  MockAuthNotifier(this._state);

  @override
  AuthState build() => _state;
}

final mockAuthNotifierProvider = NotifierProvider<MockAuthNotifier, AuthState>(
  () => throw UnimplementedError('Provider not initialized'),
);
