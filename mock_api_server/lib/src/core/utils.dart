import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

const Uuid uuid = Uuid();

// Helper function to read MimeMultipart as string
Future<String> readAsString(Stream<List<int>> stream) async {
  // MimeMultipart is a Stream<List<int>>, so collect all chunks and decode
  final chunks = await stream.toList();
  final allBytes = <int>[];
  for (var chunk in chunks) {
    allBytes.addAll(chunk);
  }
  return utf8.decode(allBytes);
}
