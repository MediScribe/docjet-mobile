import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:docjet_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

// Define the key for the compile-time environment variable
const String _apiKeyEnvVar = 'API_KEY';

// GetIt instance for dependency injection
final GetIt getIt = di.sl;

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // --- Get API Key from compile-time environment variables ---
  const String apiKey = String.fromEnvironment(_apiKeyEnvVar);
  if (apiKey.isEmpty) {
    // Throw a more informative error if the API key is missing
    throw Exception(
      'API_KEY is missing. Ensure it is provided via --dart-define=API_KEY=YOUR_API_KEY',
    );
  }
  // Register API_KEY itself in GetIt if needed elsewhere, or handle via config class
  // Example: getIt.registerSingleton<String>(apiKey, instanceName: 'API_KEY');
  // ---------------------------------------------------------

  // Initialize dependency injection - this now handles ALL registrations
  await di.init();

  // Wrap runApp with ProviderScope for Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

// Make MyApp a ConsumerWidget to access providers
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the authentication state
    final authState = ref.watch(authNotifierProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider<JobListCubit>(create: (context) => getIt<JobListCubit>()),
      ],
      child: MaterialApp(
        title: 'DocJet Mobile',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        // Conditionally show LoginScreen or HomeScreen based on auth state
        home:
            authState.status == AuthStatus.authenticated
                ? const HomeScreen()
                : const LoginScreen(),
      ),
    );
  }
}
