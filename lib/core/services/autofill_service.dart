import 'package:flutter/services.dart';

/// Service that handles platform-specific autofill operations
///
/// This abstraction isolates UI platform dependencies (TextInput)
/// from the presentation layer
abstract class AutofillService {
  /// Signal completion of an autofill session
  ///
  /// Call this after a successful login/form submission to trigger
  /// password save/update prompts on supported platforms (iOS)
  void completeAutofillContext({bool shouldSave = true});
}

/// Default implementation of [AutofillService]
class AutofillServiceImpl implements AutofillService {
  @override
  void completeAutofillContext({bool shouldSave = true}) {
    // This is a UI platform call but isolated behind this service abstraction
    TextInput.finishAutofillContext(shouldSave: shouldSave);
  }
}
