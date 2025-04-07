// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TranscriptionStatusAdapter extends TypeAdapter<TranscriptionStatus> {
  @override
  final int typeId = 1;

  @override
  TranscriptionStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TranscriptionStatus.created;
      case 1:
        return TranscriptionStatus.submitted;
      case 2:
        return TranscriptionStatus.processing;
      case 3:
        return TranscriptionStatus.transcribed;
      case 4:
        return TranscriptionStatus.generating;
      case 5:
        return TranscriptionStatus.completed;
      case 6:
        return TranscriptionStatus.failed;
      case 7:
        return TranscriptionStatus.unknown;
      default:
        return TranscriptionStatus.created;
    }
  }

  @override
  void write(BinaryWriter writer, TranscriptionStatus obj) {
    switch (obj) {
      case TranscriptionStatus.created:
        writer.writeByte(0);
        break;
      case TranscriptionStatus.submitted:
        writer.writeByte(1);
        break;
      case TranscriptionStatus.processing:
        writer.writeByte(2);
        break;
      case TranscriptionStatus.transcribed:
        writer.writeByte(3);
        break;
      case TranscriptionStatus.generating:
        writer.writeByte(4);
        break;
      case TranscriptionStatus.completed:
        writer.writeByte(5);
        break;
      case TranscriptionStatus.failed:
        writer.writeByte(6);
        break;
      case TranscriptionStatus.unknown:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptionStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
