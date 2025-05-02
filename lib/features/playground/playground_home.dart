import 'package:flutter/material.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_playground.dart';
import 'package:docjet_mobile/features/playground/notifier_playground.dart';

/// Central navigation hub for all playground screens.
/// This provides a unified entry point for all UI experimentation playgrounds.
class PlaygroundHome extends StatelessWidget {
  const PlaygroundHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Use a standard Scaffold - no need to add extra Material wrapper
    // since our app already uses MaterialApp at the root
    return Scaffold(
      appBar: AppBar(title: const Text('DocJet Playground')),
      body: ListView(
        children: [
          _buildPlaygroundTile(
            context,
            title: 'Job List UI Playground',
            subtitle: 'Experiment with job list components and interactions',
            icon: Icons.work,
            destination: const JobListPlayground(),
          ),
          _buildPlaygroundTile(
            context,
            title: 'Notification System Playground',
            subtitle: 'Test the app-wide notification system',
            icon: Icons.notifications,
            destination: const NotifierPlaygroundScreen(),
          ),
          // Add more playground options here as they're created
        ],
      ),
    );
  }

  Widget _buildPlaygroundTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget destination,
  }) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: Icon(icon, size: 36),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          // Since AppShell is applied via MaterialApp.builder,
          // we don't need to add it manually to each route
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => destination));
        },
      ),
    );
  }
}
