// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_job.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalJobAdapter extends TypeAdapter<LocalJob> {
  @override
  final int typeId = 0;

  @override
  LocalJob read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalJob(
      localFilePath: fields[0] as String,
      durationMillis: fields[1] as int,
      status: fields[2] as TranscriptionStatus,
      localCreatedAt: fields[3] as DateTime,
      backendId: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalJob obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.localFilePath)
      ..writeByte(1)
      ..write(obj.durationMillis)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.localCreatedAt)
      ..writeByte(4)
      ..write(obj.backendId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalJobAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
