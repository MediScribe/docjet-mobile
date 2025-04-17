import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_page.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

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
