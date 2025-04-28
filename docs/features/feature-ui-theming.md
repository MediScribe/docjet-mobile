# DocJet UI Theming Architecture

This document outlines the theming architecture in the DocJet mobile app, focusing on how to use and extend the theme system.

## Overview

The DocJet theming system is built on top of Flutter's [ThemeExtension](https://api.flutter.dev/flutter/material/ThemeExtension-class.html) mechanism. This approach provides several benefits:

1. **Consistent theming** across the entire application
2. **Light/dark mode support** built-in
3. **Type-safe access** to semantic color tokens
4. **Centralized definitions** of all color tokens 
5. **Easy adaptation** to theme changes

## Architecture

The theming system consists of three main components:

### 1. `AppColorTokens` (Theme Extension)

Located in `lib/core/theme/app_color_tokens.dart`, this is a Flutter `ThemeExtension` that defines semantic color tokens for the application.

```dart
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  final Color dangerBg;
  final Color dangerFg;
  // ... more semantic colors
  
  // Constructor, copyWith, lerp implementations
}
```

Key categories of tokens include:

- **Danger/Error** colors (`dangerBg`, `dangerFg`)
- **Warning** colors (`warningBg`, `warningFg`)
- **Success** colors (`successBg`, `successFg`)
- **Info** colors (`infoBg`, `infoFg`)
- **Offline status** colors (`offlineBg`, `offlineFg`)
- **Primary Action** colors (`primaryActionBg`, `primaryActionFg`) for important UI actions like recording
- **Outline** color (`outlineColor`) for form input borders and dividers
- **Shadow** color (`shadowColor`) for consistent elevation effects

### 2. `app_theme.dart` (Central Theme Definition)

Located in `lib/core/theme/app_theme.dart`, this is the single export point for all theme-related functionality:

```dart
// Creating theme instances
ThemeData createLightTheme() { /* ... */ }
ThemeData createDarkTheme() { /* ... */ }

// Helper utility for accessing tokens
AppColorTokens getAppColors(BuildContext context) { /* ... */ }
```

### 3. Theme Consumers

Various UI components like:

- `OfflineBannerTheme` - Adapts the offline banner styling
- `RecordButton` - Uses theme colors instead of hardcoded values

## How to Use

### Using Theme Colors in Widgets

To use semantic color tokens in your widgets:

```dart
import 'package:docjet_mobile/core/theme/app_theme.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get app color tokens
    final appColors = getAppColors(context);
    
    return Container(
      color: appColors.infoBg,
      child: Text(
        'Information',
        style: TextStyle(color: appColors.infoFg),
      ),
    );
  }
}
```

### Adding New Semantic Color Tokens

To add a new semantic color token:

1. **Add properties** to the `AppColorTokens` class:

```dart
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  // Existing properties
  // ...
  
  // New tokens
  final Color newFeatureBg;
  final Color newFeatureFg;
  
  // Update constructor
  const AppColorTokens({
    // Existing parameters
    // ...
    
    // New parameters
    required this.newFeatureBg,
    required this.newFeatureFg,
  });
  
  // Update static factory methods
  static AppColorTokens light(ColorScheme colorScheme) {
    return AppColorTokens(
      // Existing assignments
      // ...
      
      // New assignments
      newFeatureBg: colorScheme.primary.withOpacity(0.1),
      newFeatureFg: colorScheme.primary,
    );
  }
  
  static AppColorTokens dark(ColorScheme colorScheme) {
    return AppColorTokens(
      // Existing assignments
      // ...
      
      // New assignments
      newFeatureBg: colorScheme.primaryContainer,
      newFeatureFg: colorScheme.onPrimaryContainer,
    );
  }
  
  // Update copyWith method
  @override
  ThemeExtension<AppColorTokens> copyWith({
    // Existing parameters
    // ...
    
    // New parameters
    Color? newFeatureBg, 
    Color? newFeatureFg,
  }) {
    return AppColorTokens(
      // Existing assignments
      // ...
      
      // New assignments
      newFeatureBg: newFeatureBg ?? this.newFeatureBg,
      newFeatureFg: newFeatureFg ?? this.newFeatureFg,
    );
  }
  
  // Update lerp method
  @override
  ThemeExtension<AppColorTokens> lerp(
    covariant ThemeExtension<AppColorTokens>? other,
    double t,
  ) {
    if (other is! AppColorTokens) {
      return this;
    }
    
    return AppColorTokens(
      // Existing assignments
      // ...
      
      // New assignments
      newFeatureBg: Color.lerp(newFeatureBg, other.newFeatureBg, t)!,
      newFeatureFg: Color.lerp(newFeatureFg, other.newFeatureFg, t)!,
    );
  }
}
```

2. **Add tests** to verify the new tokens in `test/core/theme/app_color_tokens_test.dart`

## Theme Utilities & Helpers

The `getAppColors` function is a convenience utility to safely access the color tokens:

```dart
AppColorTokens getAppColors(BuildContext context) {
  final tokens = Theme.of(context).extension<AppColorTokens>();
  if (tokens == null) {
    throw StateError('AppColorTokens not found in the theme. Make sure to use the themes from app_theme.dart');
  }
  return tokens;
}
```

## Best Practices

1. **Never hardcode colors** in your UI components
2. **Always use semantic tokens** rather than accessing `ColorScheme` directly
3. **Add new tokens** when representing new semantic UI elements
4. **Ensure light/dark theme contrast** by testing in both modes
5. **Write tests** to verify theme adaptation for all theme-dependent widgets

## Testing Theme-Aware UI

Use the provided test helpers to verify theme adaptation:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/core/theme/app_color_tokens.dart';

void main() {
  test('Widget adapts to theme changes', () {
    // Get tokens from light and dark themes
    final lightTokens = AppColorTokens.light(ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ));
    
    final darkTokens = AppColorTokens.dark(ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ));
    
    // Verify colors differ between themes
    expect(
      lightTokens.dangerFg, 
      isNot(equals(darkTokens.dangerFg)),
    );
  });
}
``` 