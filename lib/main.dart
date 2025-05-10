import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/auth/presentation/widgets/app_shell.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:docjet_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_auth_gate.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import our theme definitions
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/smart_delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';

// Access GetIt for convenience
final getIt = di.sl;

// REMOVED: Duplicate authServiceProvider definition
// Using the generated provider from auth_notifier.dart instead

void main() async {
  // ---- Performance instrumentation – capture cold-start duration ----
  if (kDebugMode) {
    // Start the timeline event *as early as possible*.
    Timeline.startSync('cold_start');
  }

  // Ensure Flutter is initialized *before* we access WidgetsBinding.instance.
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    // Finish the timeline event right after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) => Timeline.finishSync());
  }

  // Initialize dependency injection
  await di.init();

  // **** WAIT FOR ALL ASYNC SINGLETONS ****
  // This ensures SharedPreferences, IUserProfileCache, and AuthService are ready
  await getIt.allReady();

  // Ensure JobSyncAuthGate is instantiated so it begins listening to auth events.
  // This replaces the previous unconditional JobSyncInitializer.
  getIt<JobSyncAuthGate>().markDiReady();

  runApp(
    // Wrap the entire app in ProviderScope for Riverpod
    ProviderScope(
      overrides: [
        // Override the generated authServiceProvider with the implementation from GetIt
        // Using the correct provider from auth_notifier.dart
        authServiceProvider.overrideWithValue(getIt<AuthService>()),
        // Override the generated authEventBusProvider with the implementation from GetIt
        authEventBusProvider.overrideWithValue(getIt<AuthEventBus>()),
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
      providers: [
        // Create the JobListCubit once at the app level
        // This ensures the same instance is used throughout the app lifecycle
        BlocProvider<JobListCubit>(
          create:
              (context) => JobListCubit(
                watchJobsUseCase: getIt<WatchJobsUseCase>(),
                mapper: getIt<JobViewModelMapper>(),
                createJobUseCase: getIt<CreateJobUseCase>(),
                deleteJobUseCase: getIt<DeleteJobUseCase>(),
                smartDeleteJobUseCase: getIt<SmartDeleteJobUseCase>(),
                appNotifierService: ref.watch(
                  appNotifierServiceProvider.notifier,
                ),
              ),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DocJet',
        // Use our theme definitions from app_theme.dart
        theme: createLightTheme(),
        darkTheme: createDarkTheme(),
        // Use system preference for light/dark mode
        themeMode: ThemeMode.system,
        // Use builder to wrap all routes with AppShell
        builder: (context, child) {
          // Wrap in Material to provide default text styles for Text widgets
          return Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: AppShell(child: child ?? const SizedBox.shrink()),
          );
        },
        // Conditionally show screens based on auth state
        home: _buildHomeBasedOnAuthState(authState),
      ),
    );
  }

  // Helper method to determine which screen to show based on auth state
  Widget _buildHomeBasedOnAuthState(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(child: CupertinoActivityIndicator()),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}
