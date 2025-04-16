import 'package:docjet_mobile/features/home/presentation/pages/transcriptions_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docjet Mobile',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TranscriptionsPage(),
    );
  }
}
