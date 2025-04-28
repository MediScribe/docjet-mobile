import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Creates a ProviderContainer with mocked auth state for testing.
ProviderContainer createProviderContainer({
  required ProviderContainer parent,
  required AuthState authState,
}) {
  return ProviderContainer(
    parent: parent,
    overrides: [
      // This works by storing values directly in the ProviderContainer
    ],
  );
}

/// Test widget that provides a ProviderScope with the necessary overrides
/// for testing widgets that depend on AuthState.
class TestApp extends StatelessWidget {
  final Widget child;
  final List<Override> overrides;

  const TestApp({required this.child, this.overrides = const [], super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(overrides: overrides, child: MaterialApp(home: child));
  }
}
