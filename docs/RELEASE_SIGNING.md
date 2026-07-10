# Android release signing (Play Store & signed APK)

FAM’s Gradle config uses **`android/key.properties`** when present; otherwise **release** builds still sign with the **debug** keystore (fine for local debug, **not** for Play or a serious beta).

## One-time keystore

From the **Flutter app root** (`family_super_app/`):

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep **`upload-keystore.jks`** and passwords in a password manager. **`android/key.properties`** and **`*.jks`** are **gitignored**.

## `key.properties`

Copy the example and fill in real values:

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties`:

- **`storeFile`:** path to the JKS file, relative to the **`android/app/`** directory (e.g. `upload-keystore.jks` if you placed the file in `android/app/`).

Example layout:

- `android/app/upload-keystore.jks`
- `android/key.properties` contains `storeFile=upload-keystore.jks`

## Register SHA fingerprints in Firebase (Google Sign-In)

For **release** or **upload** keystores, add **SHA-1** (and **SHA-256**) in Firebase Console → Project settings → Your apps → Android `com.family.superapp`.

```bash
cd android && ./gradlew signingReport
```

Use the **release** variant output after `key.properties` is configured. See also [BETA_RELEASE_RUNBOOK.md](BETA_RELEASE_RUNBOOK.md).

## Build

```bash
flutter build appbundle --release
# or
flutter build apk --release
```

Output: `build/app/outputs/...`
