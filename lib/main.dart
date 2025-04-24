import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_page.dart';
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
    ref.watch(authNotifierProvider);

    return MultiBlocProvider(
      providers: [BlocProvider(create: (context) => getIt<JobListCubit>())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DocJet',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        // For now, always show the JobListPage
        // Later, conditionally show based on auth state:
        // home: authState.status == AuthStatus.authenticated
        //   ? const HomeScreen()
        //   : const LoginScreen(),
        home: const JobListPage(),
      ),
    );
  }
}
