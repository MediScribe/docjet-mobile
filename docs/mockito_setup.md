# Mockito Setup for Testing

For testing with Mockito in this project, we use the `build_runner` to generate mock classes.

## Setup

1. Ensure you have the dependencies in `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     mockito: ^5.x.x
     build_runner: ^2.x.x
   ```

2. Create your test files with `@GenerateMocks([...])` annotations.

3. Run the following command to generate mock classes:
   ```bash
   flutter pub run build_runner build
   ```
   
   Or to watch for changes:
   ```bash
   flutter pub run build_runner watch
   ```

## Troubleshooting

If you see errors like:
```
Target of URI doesn't exist: 'your_test_file.mocks.dart'
Undefined class 'MockYourClass'
```

It means the mocks haven't been generated yet. Run the build_runner command above.

If you need to clear the build cache and regenerate from scratch:
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
``` 