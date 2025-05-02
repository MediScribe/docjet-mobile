import 'package:docjet_mobile/core/services/autofill_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Note: This test verifies the service implementation exists and its method can be called.
// It does NOT verify the underlying static Flutter platform call (`TextInput.finishAutofillContext`)
// due to the complexity of mocking platform channels in standard unit tests.
// Verification of the actual autofill prompt behavior requires integration/e2e tests on iOS.

void main() {
  // Initialize the Flutter binding to allow platform channel calls
  TestWidgetsFlutterBinding.ensureInitialized();

  late AutofillServiceImpl autofillService;

  setUp(() {
    autofillService = AutofillServiceImpl();
  });

  group('AutofillServiceImpl', () {
    test(
      'completeAutofillContext should run without throwing immediate errors',
      () {
        // Arrange (Service already set up)

        // Act & Assert
        // We expect no immediate exceptions when calling the method.
        // The actual platform interaction is outside the scope of this unit test.
        expect(
          () => autofillService.completeAutofillContext(shouldSave: true),
          returnsNormally,
        );

        expect(
          () => autofillService.completeAutofillContext(shouldSave: false),
          returnsNormally,
        );
      },
    );
  });
}
