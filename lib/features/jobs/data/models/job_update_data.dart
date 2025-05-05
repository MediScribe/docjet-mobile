import 'package:equatable/equatable.dart'; // Import Equatable

/// Model class for job updates with explicit fields
class JobUpdateData extends Equatable {
  // Extend Equatable
  final String? text;
  final String? serverId; // Added for sync operations
  // Add other fields that can be updated

  const JobUpdateData({this.text, this.serverId});

  // Optional utility to check if instance has any non-null fields
  bool get hasChanges => text != null || serverId != null;

  @override // Add props for Equatable
  List<Object?> get props => [text, serverId];
}
