import '../models/job_hive_model.dart';
import '../../domain/entities/job.dart';

// Maps between the domain Job entity and the Hive JobHiveModel DTO
class JobMapper {
  // Cannot be instantiated
  JobMapper._();

  static JobHiveModel toHiveModel(Job job) {
    // Create an empty model first, then assign fields.
    // This is often necessary because HiveObject properties might not be assignable via constructor.
    final model =
        JobHiveModel()
          ..id = job.id
          ..status = job.status
          ..createdAt = job.createdAt
          ..updatedAt = job.updatedAt
          ..userId = job.userId
          ..displayTitle = job.displayTitle
          ..displayText = job.displayText
          ..errorCode = job.errorCode
          ..errorMessage = job.errorMessage
          ..audioFilePath = job.audioFilePath
          ..text = job.text
          ..additionalText = job.additionalText;
    return model;
  }

  static Job fromHiveModel(JobHiveModel model) {
    return Job(
      id: model.id,
      status: model.status,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      userId: model.userId,
      displayTitle: model.displayTitle,
      displayText: model.displayText,
      errorCode: model.errorCode,
      errorMessage: model.errorMessage,
      audioFilePath: model.audioFilePath,
      text: model.text,
      additionalText: model.additionalText,
    );
  }

  static List<Job> fromHiveModelList(List<JobHiveModel> models) {
    return models.map(fromHiveModel).toList();
  }

  // We might not need this direction often, but good to have
  static List<JobHiveModel> toHiveModelList(List<Job> jobs) {
    return jobs.map(toHiveModel).toList();
  }
}
