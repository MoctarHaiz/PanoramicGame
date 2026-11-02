# Chaka Zulu — Android (Java)

The Play Store app `com.HaizStudio.ChakaZulu`, updated for current Android:

- Android Gradle Plugin 9.4, Gradle 9.8, Kotlin build scripts and a version catalog
  (`gradle/libs.versions.toml`).
- Targets Android 16 (API 36), as Google Play requires for updates since August 31, 2026. Runs on Android 8.1+.
- Google Mobile Ads 25.5 (banner + an interstitial every 3rd game over) with Google's
  consent form for GDPR regions (UMP 4.0). Debug builds always use Google's test ads.
- Firebase 35 (analytics + push notifications), optional: see below.
- Full screen with the system bars hidden, display cutouts used, predictive back gesture,
  landscape kept on tablets and foldables (`appCategory="game"`).
- No storage, vibration or wake-lock permissions any more.
- Fixes: pause button and pause screen work (back button = pause, back again = menu),
  game waits on the pause screen when you come back to it, music resumes, tiles no
  longer disappear when the hero is blocked by a wall, lives reset after falling in
  a hole, no crash when the activity is recreated, notification icon is a proper
  white silhouette.

## Run it

1. Open this `Android/` folder in Android Studio (File > Open).
2. Wait for the Gradle sync, pick a phone or the `Pixel_Android16` emulator, press Run.

From a terminal: `./gradlew installDebug`.

## Firebase (optional)

Firebase is switched on when `app/google-services.json` exists. Download it from the
[Firebase console](https://console.firebase.google.com) > Project settings > your
Android app `com.HaizStudio.ChakaZulu`, and put it in `app/`. It is not stored in git.
Without it the game works, just without analytics and push notifications.

## Publish an update on Google Play

1. **Version.** In `app/build.gradle.kts`, `versionCode` must be higher than the one
   already on Play (Play Console > Test and release > App bundle explorer). It is `3` now.
2. **Upload key.** The old upload keystore and its password were committed to this
   public repository in 2024 (they are still in the git history), so treat that key as
   leaked: in Play Console > Test and release > App integrity > App signing, request an
   **upload key reset**, and create a new upload key in Android Studio
   (Build > Generate Signed App Bundle or APK > Android App Bundle > Create new...).
   Keep the new `.jks` file and its passwords outside git (they are in `.gitignore`).
3. **Build.** Build > Generate Signed App Bundle or APK > Android App Bundle > release.
   Or, with a `keystore.properties` file (see `keystore.properties.example`):
   `./gradlew bundleRelease` → `app/build/outputs/bundle/release/app-release.aab`.
4. **Upload.** Play Console > Test and release > Production (or Internal testing first)
   > Create new release > upload the `.aab` > release notes > Review > Roll out.

## Before releasing

- **AdMob consent message.** The consent form only appears if a GDPR message is set up in
  AdMob > Privacy & messaging. Without it, ads in the EEA/UK/Switzerland earn very little.
- **Children.** If the Play Console target audience includes children under 13, the app
  falls under Google Play's Families policy: ads must be configured as child-directed.
- **Data safety form.** Ads and Firebase collect device identifiers; declare them in Play
  Console > App content > Data safety.
