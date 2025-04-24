import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:docjet_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Access GetIt for convenience
final getIt = di.sl;

// Riverpod providers
final authServiceProvider = Provider<AuthService>(
  (ref) =>
      throw UnimplementedError(
        'authServiceProvider not initialized - must be overridden',
      ),
);

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await di.init();

  runApp(
    // Wrap the entire app in ProviderScope for Riverpod
    ProviderScope(
      overrides: [
        // Override the generated authServiceProvider with the implementation from GetIt
        authServiceProvider.overrideWithValue(getIt<AuthService>()),
      ],
      child: const MyApp(),
    ),
  );
}

// Make MyApp a ConsumerWidget to access providers
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get auth state from the provider - this will trigger rebuilds when it changes
    final authState = ref.watch(authNotifierProvider);

    return MultiBlocProvider(
      providers: [BlocProvider(create: (context) => getIt<JobListCubit>())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DocJet',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        // Conditionally show screens based on auth state
        home: _buildHomeBasedOnAuthState(authState),
      ),
    );
  }

  // Helper method to determine which screen to show based on auth state
  Widget _buildHomeBasedOnAuthState(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}
