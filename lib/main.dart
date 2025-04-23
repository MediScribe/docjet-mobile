import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_page.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
        home: const JobListPage(),
      ),
    );
  }
}
