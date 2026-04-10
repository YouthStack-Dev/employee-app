# MLT Corporate Employee Connect

The **MLT Corporate Employee Connect** app is a comprehensive mobile solution designed for corporate employees to securely manage and track their daily commutes.

## Features
- **Secure Authentication:** Multi-tenant login via Email/Username and OTP-based Phone Number authentication.
- **Dynamic Dashboard:** Sticky active rides, intuitive grouping for upcoming rides, and real-time transit status updates.
- **Seamless Scheduling:** Easy-to-use interface for creating and modifying home-to-office and office-to-home shift commute bookings.
- **Live Tracking & SOS:** Real-time driver tracking and an always-accessible SOS alert system for maximum employee safety.
- **Push Notifications:** Instant Firebase alerts tracking shift allocations, driver arrivals, and critical announcements.

---

## Technical Stack
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Networking:** Dio (HTTP client with custom interceptor logic for JWT Auth & Tenant Management)
- **Maps:** Google Maps Flutter & Geolocator
- **Push Notifications:** Firebase Cloud Messaging (FCM)

---

## Setup & Requirements

1. **Flutter SDK**: Ensure you have Flutter ^3.10.7 installed on your machine.
2. **Setup Dependencies**:
   Navigate to the project root and run:
   ```bash
   flutter clean
   flutter pub get
   ```

---

## How to Run the App (Development)

To run the application natively on a connected physical device or emulator:
```bash
flutter run
```
*Tip: If you have multiple devices connected, specify your device ID using `flutter run -d <DEVICE_ID>`*

---

## How to Build the App (Production)

### Android (APK & App Bundle)
Google Play requires an `.aab` file for new store submissions, but you can build a `.apk` for direct device installations/side-loading.

1. **Build a universal APK** (for direct testing/distribution):
   ```bash
   flutter clean
   flutter build apk --release
   ```
   *Output Directory:* `build/app/outputs/flutter-apk/app-release.apk`

2. **Build an Android App Bundle** (for Google Play Console Upload):
   ```bash
   flutter clean
   flutter build appbundle --release
   ```
   *Output Directory:* `build/app/outputs/bundle/release/app-release.aab`

### iOS (IPA)
*Note: To build for iOS, you must use a macOS environment and have Xcode installed.*

1. **Update CocoaPods**:
   ```bash
   cd ios
   pod repo update
   pod install
   cd ..
   ```
2. **Build the iOS App Archive (IPA)**:
   ```bash
   flutter clean
   flutter build ipa --release
   ```
   *Alternatively, you can open the `ios/Runner.xcworkspace` file in Xcode, select your Apple Developer Signing Certificate, and use `Product > Archive` to submit directly to TestFlight and the App Store.*
