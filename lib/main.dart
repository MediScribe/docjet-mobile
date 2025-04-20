import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_page.dart';

// Define the key for the compile-time environment variable
const String _apiKeyEnvVar = 'API_KEY';

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
  // ---------------------------------------------------------

  // Initialize the auth credentials provider
  final secureStorage = const FlutterSecureStorage();
  final authCredentialsProvider = SecureStorageAuthCredentialsProvider(
    secureStorage: secureStorage,
  );

  runApp(MyApp(authCredentialsProvider: authCredentialsProvider));
}

class MyApp extends StatelessWidget {
  final SecureStorageAuthCredentialsProvider authCredentialsProvider;

  const MyApp({super.key, required this.authCredentialsProvider});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocJet Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const JobListPage(),
    );
  }
}
