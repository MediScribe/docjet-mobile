# iOS Password AutoFill Setup TODO

## Current Status

- ✅ Flutter code setup for AutoFill is complete:
  - Login screen uses `AutofillGroup` wrapper
  - Email field has `autofillHints: [AutofillHints.email]`
  - Password field has `autofillHints: [AutofillHints.password]`
  - Added `AutofillService` abstraction to isolate platform-specific API calls
  - `AutofillService.completeAutofillContext()` is called after successful login

- ❌ iOS Associated Domains setup is incomplete:
  - iOS provisioning profile is reporting: "doesn't support the AutoFill Credential Provider capability"
  - App is not triggering iOS password save/update prompts
  
- ⚠️ TODO: Add iOS integration tests to verify autofill behavior

## Required Steps

### 1. Xcode Project Configuration

1. Open the iOS project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select the Runner target -> Signing & Capabilities tab

3. Click "+" to add capability -> Select "Associated Domains"

4. Add domain entry in the format:
   ```
   webcredentials:yourdomain.com
   ```
   (Replace `yourdomain.com` with your actual domain where your backend runs)

### 2. Apple Developer Account Setup

1. Log in to [Apple Developer Portal](https://developer.apple.com/account)

2. Go to Certificates, Identifiers & Profiles

3. Select your App ID (identifier)

4. Ensure "Associated Domains" capability is enabled:
   - If not, enable it and update your provisioning profiles

5. Download and install updated provisioning profiles in Xcode

### 3. Web Server Configuration

1. Create an `apple-app-site-association` file:
   ```json
   {
     "webcredentials": {
       "apps": ["TEAM_ID.com.docjet.mobile"]
     }
   }
   ```
   (Replace `TEAM_ID` with your actual Apple Team ID)

2. Host this file at:
   ```
   https://yourdomain.com/.well-known/apple-app-site-association
   ```

3. Ensure the file is:
   - Served with HTTPS
   - Has Content-Type: application/json
   - Is served without redirects
   - Is accessible via direct URL

### 4. Verification

1. Validate your AASA file using:
   - [Apple's CDN Validation Tool](https://app-site-association.cdn-apple.com/a/v1/YOUR_DOMAIN_HERE)
   - or [Branch.io's AASA Validator](https://branch.io/resources/aasa-validator/)

2. Test on a real iOS device:
   - Uninstall previous test app versions
   - Build and install fresh app version
   - Complete login with valid credentials
   - Check if password save prompt appears

## Resources

- [Apple Developer: Supporting Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Flutter Documentation: autofillHints property](https://api.flutter.dev/flutter/material/TextField/autofillHints.html)
- [Firebase Hosting AASA Configuration (Alternative)](https://stackoverflow.com/questions/68104102/flutter-ios-autofill-strong-password-error) - Contains instructions for hosting AASA files on Firebase if needed 