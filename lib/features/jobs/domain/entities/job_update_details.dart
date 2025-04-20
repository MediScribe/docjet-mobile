import 'package:equatable/equatable.dart';

/// Represents the details allowed for updating a Job entity.
/// Contains only the fields that can be modified by the user/system post-creation.
class JobUpdateDetails extends Equatable {
  // Add fields that are updatable. For now, let's assume only 'text'
  // is updatable based on the previous example.
  // Add other fields here (e.g., status, notes) as needed, using nullable types
  // to indicate that not all fields need to be provided for every update.
  final String? text;
  // final JobStatus? status; // Example: if status could be updated directly

  const JobUpdateDetails({
    this.text,
    // this.status,
  });

  // Check if any update field is actually provided
  bool get hasChanges => text != null; // Extend this check for other fields

  @override
  List<Object?> get props => [text]; // Add other fields
}
