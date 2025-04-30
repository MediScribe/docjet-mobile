# Riverpod Guide for DocJet Mobile

## Provider Generation Pattern

### What is Riverpod?

Riverpod is a reactive caching and data-binding framework that improves on Flutter's InheritedWidget pattern. Created by Remi Rousselet (who also created Provider), Riverpod offers several key advantages:

1. **Compile-time safety**: Catches provider access errors at compile time rather than runtime
2. **Simplified dependency management**: Providers can depend on other providers without complex nesting
3. **Reactive rebuilding**: UI components only rebuild when their specific dependencies change
4. **Testing support**: First-class testing capabilities with easy provider overrides
5. **Code generation**: Reduces boilerplate through annotations

In DocJet Mobile, we use Riverpod with code generation for state management. This document explains our approach to provider definitions, code generation, and provider overrides. 

### Code Generation Approach

1. **Provider Annotations**: We use `@riverpod` annotations from the `riverpod_annotation` package to generate providers.

    ```dart
    // Example in auth_notifier.dart
    @Riverpod(keepAlive: true)
    class AuthNotifier extends _$AuthNotifier {
      // Implementation...
    }

    @Riverpod(keepAlive: true)
    AuthService authService(AuthServiceRef ref) {
      throw UnimplementedError(
        'authServiceProvider has not been overridden. '
        'Make sure to override this in your main.dart with an implementation.',
      );
    }
    ```

2. **Generated Providers**: Running `flutter pub run build_runner build` creates `.g.dart` files containing the generated providers:

    ```dart
    // Generated in auth_notifier.g.dart
    final authServiceProvider = Provider<AuthService>.internal(
      authService,
      name: r'authServiceProvider',
      // ...
    );

    final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>.internal(
      AuthNotifier.new,
      name: r'authNotifierProvider',
      // ...
    );
    ```

3. **Provider Import**: Always import providers from the file where they are defined, not their `.g.dart` files directly:

    ```dart
    // Correct: Import the defining file
    import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';

    // Incorrect: Never import the generated file directly
    // import 'package:docjet_mobile/core/auth/presentation/auth_notifier.g.dart';
    ```

## Provider Override Patterns

### Dependency Injection with GetIt and Riverpod

We use a hybrid approach with GetIt for service instantiation and Riverpod for state management:

1. **Service Registration**: Services are registered in GetIt within the `injection_container.dart` file:

    ```dart
    // Register the service in GetIt
    sl.registerLazySingleton<AuthService>(
      () => AuthServiceImpl(
        apiClient: sl<AuthApiClient>(),
        credentialsProvider: sl<AuthCredentialsProvider>(),
        eventBus: sl<AuthEventBus>(),
      ),
    );
    ```

2. **Provider Overrides**: In `main.dart`, we override the generated providers with GetIt instances:

    ```dart
    // In main.dart
    ProviderScope(
      overrides: [
        // Override with GetIt instance
        authServiceProvider.overrideWithValue(getIt<AuthService>()),
      ],
      child: const MyApp(),
    ),
    ```

3. **Module-Based Overrides**: For modular code, we use `providerOverrides` methods:

    ```dart
    // In auth_module.dart
    static List<Override> providerOverrides(GetIt getIt) {
      return [
        authServiceProvider.overrideWithValue(getIt<AuthService>()),
      ];
    }
    ```

## Common Pitfalls

### Provider Duplication

**NEVER** redefine providers manually that are already generated via `@riverpod` annotations:

```dart
// BAD: Defining a duplicate provider with the same name
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('...'),
);

// GOOD: Use the generated provider from the annotation
// Just import from the file where it's defined with @riverpod
```

### Provider References in Tests

When testing components that use providers:

1. **Mock All Dependencies**: Override all providers used by the component:

    ```dart
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        authEventBusProvider.overrideWithValue(mockAuthEventBus),
      ],
      child: ComponentUnderTest(),
    ),
    ```

2. **Use Generated Mocks**: Use `@GenerateMocks` with `build_runner` to generate proper mock classes.

## Best Practices

1. **Single Source of Truth**: Each provider should be defined in exactly one place, preferably with code generation.

2. **Clear Provider Naming**: Use consistent naming patterns:
   - Service providers: `fooServiceProvider`
   - Notifier providers: `fooNotifierProvider`

3. **Provider Documentation**: Document providers with usage examples and dependency information.

4. **Provider Scope**: Use `keepAlive: true` for app-wide providers, `autoDispose` for screen-level providers. 