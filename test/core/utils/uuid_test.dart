import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart'; // This import will fail initially

void main() {
  group('Uuid', () {
    test('v4 generates a non-empty string', () {
      const uuid = Uuid();
      final generatedUuid = uuid.v4();

      expect(generatedUuid, isA<String>());
      expect(generatedUuid, isNotEmpty);
      // Basic regex check for UUID format (simplified)
      expect(
        generatedUuid,
        matches(
          RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
          ),
        ),
      );
    });
  });
}
