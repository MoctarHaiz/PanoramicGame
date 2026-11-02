# Releasing Chaka Zulu 2.0.0

The game builds for both stores. The steps below happen in your Google, Apple and AdMob accounts, so only you can do them.
Commands run from `New/`. Steps are marked ✅ **Done YYYY-MM-DD** when finished.

## Before either store

1. **Privacy policy online.** `docs/privacy-policy.html` (EN + FR, contact studio.haiz@gmail.com) goes in the folder
   `chaka-zulu/` of the existing site repo `HaizStudio/haizstudio.github.io` (next to `super-gassamanh/`). The address is
   the one the game opens: `https://haizstudio.github.io/chaka-zulu/privacy-policy.html` (404 until published).
2. **AdMob apps** (in the Haiz Studio account `ca-app-pub-6901166788369759`, as you chose):
   - Add an **Android** app "Chaka Zulu" (*Is the app listed on a supported app store?* Yes, search `com.HaizStudio.ChakaZulu`)
     and an **iOS** app "Chaka Zulu" (not listed yet).
   - In each, two ad units: **Banner** and **Interstitial**.
   - Send me the 2 app ids (with `~`) and the 4 unit ids (with `/`). They go in Project Settings › Admob and in
     `config/game_config.cfg`. Until then, release builds have **no ads** (debug builds use Google's test ads).
3. **Consent messages** (required, or there are no ads at all): AdMob › Privacy & messaging, for both new apps:
   - **European regulations (GDPR)**: create and publish.
   - **IDFA explainer** (iOS app).
   - **US state regulations** (recommended).
4. ✅ **Done 2026-10-29** (checked 2026-10-30: answers 200, `pub-6901166788369759`). **app-ads.txt** at
   `https://haizstudio.github.io/app-ads.txt` covers the new apps too.

## Google Play

1. ✅ **Done 2026-10-30** (key found in the 2019 history: alias `key0`, CN=Haiz Studio, kept in `signing/`, git-ignored).
   **Key**: `tools/build_android.sh` refuses a bundle not signed with SHA-256 `08:BE:42:CB:…:85:B2`. If Play Console says
   the upload key is different, request an upload key reset in Test and release › App integrity.
2. ✅ **Done 2026-10-30** (60 MB bundle; checked: package `com.HaizStudio.ChakaZulu`, version code 10, target SDK 36,
   signed with the 2019 key; ads ids still Google's samples until the AdMob apps exist, so rebuild after step "AdMob apps").
   **Build**: `tools/build_android.sh` → `build/android/chakazulu-2.0.0.aab` (version code 10, target SDK 36).
   `--apk` adds a signed APK to try on a phone: `adb install -r build/android/chakazulu-2.0.0-release.apk`.
3. **Upload** to *Internal testing*, install it from Play on your phone, then promote to Production.
4. **Store listing**: phone screenshots, feature graphic and icon in `docs/store/` (made by `tools/store_art.py`).
5. **App content**: ads yes; advertising ID yes (AdMob uses it); target audience 13+ (not Families); Data safety as in the skill's table (approximate location,
   device IDs, app interactions, crash logs, diagnostics: collected and shared, required).
6. **Release notes** (below), then send for review.

## App Store

1. **App Store Connect**: create the app, bundle id `com.HaizStudio.ChakaZulu` (team ZUGMSRF5HZ). Send me its numeric
   Apple ID (App Information) for `config/game_config.cfg` › `app_store_id`.
2. **Build**: `tools/build_ios.sh`, open `build/ios/ChakaZulu.xcodeproj` in Xcode, choose *Any iOS Device (arm64)*,
   Product › Archive › Distribute App › App Store Connect.
   `tools/build_ios.sh --simulator "iPhone 18 Pro Max"` runs it in the Simulator.
3. **Screenshots** from `docs/store/appstore/` (6.3" and 6.9" iPhone, 13" iPad, landscape).
4. **App Privacy**: as in the skill's table (coarse location, device ID, product interaction, advertising data: tracking).
5. **Already set by the build**: export compliance (no encryption), 120 Hz, the tracking prompt in English and French,
   landscape, iPhone and iPad, iOS 16+.
6. **Product page, age rating (13+), price (free)**, then submit for review.

## Optional services (off until set up)

- **Firebase**: put `google-services.json` and `GoogleService-Info.plist` in `config/` and rebuild.
- **Remove ads**: create the non-consumable product `remove_ads` in both stores, then `[remove_ads] enabled=true`.
- **Leaderboards**: Play Games Services + Game Center leaderboard `most_red_bobs`, then `[leaderboards] enabled=true`.

## Release notes

**en-US**
```
Chaka Zulu is back, rebuilt from scratch!
• Panoramic redrawn in a brand-new style
• A painted savanna, water, vines and new sounds
• A real ending: get home and earn up to 3 stars
• Smooth on every phone, including 90/120 Hz screens
• Now on iPhone and iPad too, in English and French
```

**fr-FR**
```
Chaka Zulu revient, entièrement refait !
• Panoramic redessiné dans un tout nouveau style
• Une savane peinte, de l'eau, des lianes et de nouveaux sons
• Une vraie fin : rentre à la maison et gagne jusqu'à 3 étoiles
• Fluide sur tous les téléphones, y compris les écrans 90/120 Hz
• Maintenant aussi sur iPhone et iPad, en français et en anglais
```
