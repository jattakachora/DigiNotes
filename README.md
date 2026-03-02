# DigiNotes

DigiNotes is a Flutter mobile app for organizing photos and videos into folders, adding notes, and keeping local data backed up to Google Drive.

## Features

- Folder-based media organization with custom folder emoji.
- Capture photos and videos directly from the app.
- Import existing media from device storage.
- Add text notes to each media item.
- Record and attach audio notes to media items.
- View images with zoom support.
- Video playback support in gallery and detail screens.
- Share media from inside DigiNotes.
- Save shared images/videos from other apps directly into DigiNotes folders.
- Home-screen quick actions for fast capture (take picture / record video).
- Search support for media notes.
- Google Drive backup and restore with automatic old-backup cleanup.
- Scheduled backups (daily, weekly, monthly) using background tasks.

## Installation

### Download APK

You can download the latest APK release from the [releases folder](releases/):

- **DigiNotes v1.0.12** - [Download](releases/DigiNotes-v1.0.12-release.apk) (51.6 MB)

#### Installation Steps:

1. Download the APK file from the link above
2. Enable installation from unknown sources on your Android device:
   - Settings > Security > Install unknown apps > (select your browser or file manager)
3. Open the downloaded APK file and tap "Install"
4. Once installation is complete, tap "Open" to launch DigiNotes

**Requirements:** Android 7.0 (API level 24) or higher

### Build from Source

If you prefer to build the app yourself:

```bash
git clone https://github.com/jattakachora/DigiNotes.git
cd DigiNotes
flutter pub get
flutter build apk --release
```

The built APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

## Tech Stack

- Flutter
- Provider (state management)
- SQFlite (local database)
- Google Sign-In + Google Drive API (backup)

## System Requirements

### Development Environment

- Flutter SDK: compatible with Dart `>=3.0.0 <4.0.0`
- Dart SDK: `>=3.0.0 <4.0.0`
- Java: 17 (Android build config uses Java 17)
- Android Studio (recommended) with Android SDK installed
- Xcode (for iOS builds, macOS only)

### App Platform Targets

- Android:
  - `minSdk = 24`
  - `targetSdk = 36`
  - `compileSdk = 36`
- iOS:
  - Deployment target: iOS 12.0

## Permissions Used

On Android, the app requests access for:

- Camera
- Microphone
- Storage/media files (images, video, audio)
- Internet (for Google Drive backup)

## Project Setup

1. Clone the repository:

```bash
git clone https://github.com/jattakachora/DigiNotes.git
cd DigiNotes
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

## Build Commands

Pre-built APK releases are available in the [releases folder](releases/). To build your own:

- Android APK:

```bash
flutter build apk --release
```

- Android App Bundle:

```bash
flutter build appbundle --release
```

- iOS (macOS only):

```bash
flutter build ios --release
```

## Backup and Restore

- Open the backup screen in the app.
- Sign in with Google account.
- Create manual backups to Google Drive.
- Restore from any listed backup.
- Enable scheduled backup (daily/weekly/monthly).

Backups are stored in a Google Drive folder named **DigiNotes Backups**.

## Notes for Maintainers

- Current package name / bundle identifiers in project files are still template values (`com.example...`) and should be updated before production release.
- iOS `Info.plist` display-name fields may need cleanup/customization before publishing.

## Version

Current app version in `pubspec.yaml`: `1.0.12`
