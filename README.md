# Chaka Zulu (Panoramic)

A 2D side-scrolling platformer by Haiz Studio, published on Google Play as
**Chaka Zulu** (`com.HaizStudio.ChakaZulu`).

| Folder | What it is |
|---|---|
| [`Android/`](Android/) | The original game: Java + Android Canvas, Android only. Updated in 2026 for Android 16 and current Play requirements, see [`Android/README.md`](Android/README.md). |
| [`Android3D/`](Android3D/) | The game rebuilt in full 3D (Java + OpenGL ES 3), Android only. See [`Android3D/README.md`](Android3D/README.md). |
| [`flutter/`](flutter/) | The new version: Flutter + [Flame](https://flame-engine.org). One codebase for **Android, iOS and the web**. |

## The Flutter version

Same level, art, sounds and rules as the Android game (the Java classes were
ported one to one, see the comments in `flutter/lib/game/`), plus:

- **iOS and web** support, from the same code.
- **Same speed on every phone.** The Android version moved things by device
  pixels, so it was faster or slower depending on the screen. The new version
  uses a fixed 960 x 640 "virtual" screen and a fixed 40 updates per second.
- **No stretching.** Wide phones show more of the level instead of a stretched picture.
- **Smoother** movement (positions are interpolated between updates).
- Tap the **pause** button to pause; a **level complete** screen at the end of the level.
- Keyboard controls on computers: arrows / WASD, space to throw, P to pause.
- **Personalization** ("hero packs"): a child's face on the hero (big-head style),
  their name on the menu, and a birthday message at the end of the level.

### Controls

| Action | Touch | Keyboard |
|---|---|---|
| Jump | swipe up | Up / W |
| Crouch, or let go of the top of the screen | swipe down | Down / S |
| Step forward | swipe right | Right / D |
| Throw a ring | tap | Space |
| Pause | tap the pause button | P / Esc |

### Run it

```bash
cd flutter
flutter pub get
flutter run -d chrome                         # web
flutter run                                   # a connected Android phone / iOS simulator
flutter test                                  # game rule tests
```

Building for iOS needs Xcode on a Mac; building for Android needs Android Studio
(Android SDK).

### Personalized versions (hero packs)

```bash
cd flutter
python3 tool/make_hero_pack.py photo.jpg --id emma --name Emma --age 7 --box 120,80,300,300
```

This writes `assets/hero_packs/emma/` (a round `face.png` + `hero.json` with the
name and message). Add `- assets/hero_packs/emma/` to the assets list in
`pubspec.yaml`, then:

- **Web link** (no install, works on iPhone and Android): build the web version
  and open it with `?hero=emma` at the end of the address.
- **Dedicated build**: `flutter build apk --dart-define=HERO=emma`.

A demo pack with a drawn placeholder face is included: open the web version
with `?hero=demo`.

### Assets

`flutter/tool/import_android_assets.py` copies the art, sounds and level from
`Android/` into `flutter/assets/` (splits the very wide background image,
converts OGG sounds to MP3 for iOS, and finds the hero's head in every
animation frame for the personalization).

## Not ported yet

- Ads (AdMob banner / interstitial / rewarded) and Firebase (analytics, push
  notifications). Use the official `google_mobile_ads` and `firebase_*` Flutter
  plugins; they support Android and iOS.
- Release signing for Google Play (reuse the existing upload key so the new
  version installs as an update of the current app) and the App Store setup.
- App icon and store screenshots.
