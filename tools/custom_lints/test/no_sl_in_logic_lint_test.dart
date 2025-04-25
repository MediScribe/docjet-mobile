import 'package:get_it/get_it.dart'; // Mock import
import 'package:test/test.dart'; // Import test package

// Mock GetIt instance and sl function
final sl = GetIt.instance;

// Main entry point for the test
void main() {
  test('Lint rule test - custom_lint will process expect_lint comments', () {
    // This test is empty because custom_lint will process the expect_lint comments
    // during analysis, not during test execution
  });
}

// --- Test Cases ---

// Disallowed file (imagine this is lib/logic.dart)
void someBusinessLogic() {
  // expect_lint: no_sl_in_logic
  /* final dependency = */ sl<String>(); // Variable unused

  // Second sl call in same function - should also be flagged
  // expect_lint: no_sl_in_logic
  sl<bool>(); // This should be flagged too

  // Third sl call - should be flagged as well
  // expect_lint: no_sl_in_logic
  /* final anotherOne = */ sl<int>(); // Variable unused
  // print(anotherOne); // Avoid print
}

// Allowed file (imagine this is test/core/di/injection_container_test.dart)
// No expect_lint here, should be allowed
void testDIContainer() {
  // expect_lint: no_sl_in_logic
  /* final dependency = */ sl<int>(); // Variable unused
  // print(dependency); // Avoid print

  // Second call, should also be linted due to the test filename not matching allowed path
  // expect_lint: no_sl_in_logic
  /* final something = */ sl<double>(); // Variable unused
  // print(something); // Avoid print

  // NOTE: custom_lint analyzes based on the *test file's path*.
  // We can't truly simulate the allowed paths here, but we can test the Provider logic.
}

// Dummy base class for Bloc/Cubit - Make it a Widget itself for simplicity here
abstract class StateStreamableSource<T> extends Widget {}

// Dummy Cubit class
class DummyCubit extends StateStreamableSource<String> {
  DummyCubit(String initialState); // Mock constructor
}

// Allowed Provider usage
class MyWidget extends Widget {
  // Make MyWidget itself a Widget
  // @override // Removed override - dummy Widget has no build()
  Widget build() {
    return BlocProvider<DummyCubit>(
      // Use dummy cubit type
      // Allowed inside create
      create: (_) {
        // Multiple sl calls inside provider create - all should be allowed
        /* final auth = */ sl<AuthService>(); // Variable unused
        /* final repo = */ sl<Repository>(); // Variable unused
        return sl<DummyCubit>(); // Assume sl can provide the dummy cubit
      },
      child: Container(), // Container now extends Widget
    );
  }

  void someOtherMethod() {
    // expect_lint: no_sl_in_logic
    /* final anotherDep = */ sl<
        double>(); // Disallowed outside create; variable unused

    // Multiple calls in the same method - all should be flagged
    // expect_lint: no_sl_in_logic
    /* final badExample = */ sl<String>(); // Variable unused

    // expect_lint: no_sl_in_logic
    /* final anotherBadExample = */ sl<int>(); // Variable unused

    // print('$badExample $anotherBadExample'); // Avoid print
  }
}

// Test MultiProvider support
class MultiProviderExample extends Widget {
  Widget build() {
    return MultiProvider(
      providers: [
        BlocProvider<DummyCubit>(
          create: (_) => sl<DummyCubit>(), // Should be allowed
          child: Container(), // Added child
        ),
        Provider<AuthService>(
          create: (_) => sl<AuthService>(), // Should be allowed
          child: Container(), // Added child
        ),
      ],
      child: Container(),
    );
  }
}

// Dummy classes for test context
class Widget {}

class BuildContext {}

class AuthService {}

class Repository {}

// Dummy AuthService and JobRepository for testing
class JobRepository {}

// Dummy BlocProvider that returns our dummy Widget
class BlocProvider<T extends StateStreamableSource<Object?>> extends Widget {
  final T Function(BuildContext) create;
  final Widget child;

  BlocProvider({required this.create, required this.child});
}

// Dummy Container
class Container extends Widget {}

// Dummy MultiProvider for testing
class MultiProvider extends Widget {
  final List<Widget> providers;
  final Widget child;

  MultiProvider({required this.providers, required this.child});
}

// Dummy Provider
class Provider<T> extends Widget {
  final T Function(BuildContext) create;
  final Widget child;

  Provider({required this.create, required this.child});
}

class AnotherWidget {
  void build(BuildContext context) {
    // Allowed via MultiProvider create
    /* final multi = */ MultiProvider(
      providers: [
        BlocProvider<DummyCubit>(
          create: (_) => sl<DummyCubit>(),
          child: Container(),
        ),
      ],
      child: Container(),
    );

    // Allowed chained Provider create
    /* final chained = */ Provider<String>(
      create: (_) => sl<String>(),
      child: Provider<int>(
        create: (_) => sl<int>(),
        child: Container(),
      ),
    );

    // Disallowed direct calls
    // expect_lint: no_sl_in_logic
    /* final auth = */ sl<AuthService>(); // Variable unused
    // expect_lint: no_sl_in_logic
    /* final repo = */ sl<JobRepository>(); // Variable unused
  }

  void anotherMethod() {
    // expect_lint: no_sl_in_logic
    sl<String>(); // Disallowed
  }
}
