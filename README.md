# QR Wallet

A modern, sleek cashless wallet app enabling seamless transactions via QR codes. Built with Flutter for iOS and Android.

![QR Wallet](assets/images/banner.png)

## Features

- 🔐 **Secure Authentication** - Email, phone verification with OTP, biometric login
- 📱 **QR Code Payments** - Generate and scan QR codes for instant transactions
- 💰 **Wallet Management** - Check balance, add money, withdraw to bank
- 📊 **Transaction History** - View all transactions with detailed information
- 🌓 **Dark/Light Mode** - Beautiful UI in both themes
- 🔔 **Real-time Updates** - Stay informed about your transactions
- 🏦 **Bank Integration** - Link bank accounts via Paystack/Flutterwave

## Screenshots

| Splash | Sign Up | Home | Send Money |
|--------|---------|------|------------|
| ![Splash](screenshots/splash.png) | ![Sign Up](screenshots/signup.png) | ![Home](screenshots/home.png) | ![Send](screenshots/send.png) |

## Getting Started

### Prerequisites

- Flutter SDK (>=3.2.0)
- Dart (>=3.2.0)
- Android Studio / Xcode
- Firebase account (for backend)
- Paystack account (for payments)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/qr_wallet.git
   cd qr_wallet
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Setup Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Authentication (Email/Phone)
   - Create Firestore database
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the appropriate directories:
     - Android: `android/app/google-services.json`
     - iOS: `ios/Runner/GoogleService-Info.plist`

4. **Configure environment variables**
   Create a `.env` file in the root directory:
   ```
   PAYSTACK_PUBLIC_KEY=pk_test_xxxxx
   PAYSTACK_SECRET_KEY=sk_test_xxxxx
   ```

5. **Generate Hive adapters**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── core/
│   ├── constants/          # App-wide constants (colors, strings, dimensions)
│   ├── theme/              # Theme configuration
│   ├── router/             # Navigation routes
│   ├── services/           # API services, Firebase services
│   └── utils/              # Helper functions
├── features/
│   ├── splash/             # Splash screen
│   ├── auth/               # Authentication (login, signup, OTP, KYC)
│   │   ├── screens/
│   │   └── widgets/
│   ├── home/               # Home screen with balance and quick actions
│   │   ├── screens/
│   │   └── widgets/
│   ├── send/               # Send money (QR scan, manual entry)
│   ├── receive/            # Receive money (QR display)
│   ├── transactions/       # Transaction history and details
│   └── profile/            # User profile and settings
├── models/                 # Data models
├── providers/              # Riverpod providers
└── main.dart              # App entry point
```

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Local Storage**: Hive
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Payments**: Paystack, Flutterwave
- **QR Code**: qr_flutter, mobile_scanner
- **Authentication**: Biometric (local_auth)

## Configuration

### Firebase Security Rules

```javascript
// Firestore rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /wallets/{walletId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    match /transactions/{transactionId} {
      allow read: if request.auth != null && 
        (resource.data.senderWalletId == request.auth.uid || 
         resource.data.receiverWalletId == request.auth.uid);
    }
  }
}
```

### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS Configuration

Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for QR code scanning</string>
<key>NSFaceIDUsageDescription</key>
<string>Face ID is used for secure authentication</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required for profile photo</string>
```

## API Integration

### Paystack

```dart
// Initialize Paystack
final paystack = PaystackPlugin();
await paystack.initialize(publicKey: 'YOUR_PUBLIC_KEY');

// Make payment
final charge = Charge()
  ..amount = 10000 // in kobo
  ..email = 'user@email.com'
  ..reference = 'unique_reference';

final response = await paystack.checkout(context, charge: charge);
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

Your Name - [@yourtwitter](https://twitter.com/yourtwitter) - email@example.com

Project Link: [https://github.com/yourusername/qr_wallet](https://github.com/yourusername/qr_wallet)

---

Made with ❤️ and Flutter
