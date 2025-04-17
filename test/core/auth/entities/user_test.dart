import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equatable/equatable.dart';

void main() {
  group('User Entity', () {
    test('should be a subclass of Equatable', () {
      // Arrange
      const user = User(id: 'test-id');
      // Assert
      expect(user, isA<Equatable>());
    });

    test('should support value equality', () {
      // Arrange
      const user1 = User(id: 'test-id');
      const user2 = User(id: 'test-id');
      // Assert
      expect(user1, equals(user2));
    });

    test('should have correct props for equality', () {
      // Arrange
      const user = User(id: 'test-id');
      // Assert
      expect(user.props, equals([user.id]));
    });
  });
}
