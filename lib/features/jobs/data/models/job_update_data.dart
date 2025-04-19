/// Model class for job updates with explicit fields
class JobUpdateData {
  final String? text;
  // TODO: Remove this once JobStatus is available or defined
  // final JobStatus? status;
  final String? serverId; // Added for sync operations
  // Add other fields that can be updated

  const JobUpdateData({
    this.text,
    // this.status,
    this.serverId,
  });

  // Optional utility to check if instance has any non-null fields
  bool get hasChanges =>
      text != null /* || status != null */ || serverId != null;
}
