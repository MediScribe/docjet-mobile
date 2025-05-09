// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JobHiveModelAdapter extends TypeAdapter<JobHiveModel> {
  @override
  final int typeId = 0;

  @override
  JobHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JobHiveModel(
      localId: fields[0] as String,
      status: fields[1] as int?,
      createdAt: fields[2] as String?,
      updatedAt: fields[3] as String?,
      userId: fields[4] as String?,
      displayTitle: fields[5] as String?,
      displayText: fields[6] as String?,
      errorCode: fields[7] as int?,
      errorMessage: fields[8] as String?,
      audioFilePath: fields[9] as String?,
      text: fields[10] as String?,
      additionalText: fields[11] as String?,
      syncStatus: fields[12] as int?,
      serverId: fields[13] as String?,
      retryCount: fields[14] as int?,
      lastSyncAttemptAt: fields[15] as String?,
      failedAudioDeletionAttempts: fields[16] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, JobHiveModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.localId)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.userId)
      ..writeByte(5)
      ..write(obj.displayTitle)
      ..writeByte(6)
      ..write(obj.displayText)
      ..writeByte(7)
      ..write(obj.errorCode)
      ..writeByte(8)
      ..write(obj.errorMessage)
      ..writeByte(9)
      ..write(obj.audioFilePath)
      ..writeByte(10)
      ..write(obj.text)
      ..writeByte(11)
      ..write(obj.additionalText)
      ..writeByte(12)
      ..write(obj.syncStatus)
      ..writeByte(13)
      ..write(obj.serverId)
      ..writeByte(14)
      ..write(obj.retryCount)
      ..writeByte(15)
      ..write(obj.lastSyncAttemptAt)
      ..writeByte(16)
      ..write(obj.failedAudioDeletionAttempts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
