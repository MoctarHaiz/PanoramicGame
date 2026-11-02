# Chaka Zulu 2.0: Godot rebuild for iOS + Android in `New/`

## Context

`Old/` holds the Android-only Java game (about 2,900 lines, custom Canvas engine, 960×640 virtual
screen, 40 updates per second). It's on Google Play as **Chaka Zulu** (`com.HaizStudio.ChakaZulu`).
The menu calls the game and its hero **Panoramic**.

The goal is one Godot project for both stores. It keeps the same level and rules, uses new art and
sound made with free local tools, and adds ads with consent, store art, and a release on both stores.

`Old/` is never modified. Nothing is committed or uploaded unless you ask. Work happens on branch `godot-remake`.

## What the old game is (audit)

**Play.** A side-scroller in landscape.
- The world scrolls left on its own. Panoramic stays near the left edge.
- Swipe up: jump. Tap: throw a ring. Swipe right: step forward. Swipe down: crouch, or let go of the top.
- If a jump takes his centre to the top of the screen, he grabs it and **hangs** there (staff
  overhead) while the world scrolls under him. That's the only way across the widest holes.
- When his body touches the top of a ledge during a jump, he lands on it. So walls up to 10
  tiles tall can be climbed from the ground.
- A wall stops the scrolling until he jumps over it.
- Red Bobs (red smiling balls) are the score: 104 in the level.
- 50 bandits run at him. A ring hits a bandit; two hits knock it out. A bandit that touches him
  takes one of his 3 lives.
- Falling into a hole or the water ends the game.
- At the end there's a HOME sign and a tree-trunk house. The old game had no ending there: the hero
  ran off the screen.

**Level.** One map, 800×20 tiles of 32 units (25,600 × 640), from `Old/app/src/main/res/raw/level.csv`:
- Ground at row 18.
- Water at columns 75, 106 and 451–503 (with stepping-stone platforms).
- Holes at 197, 208, 264, 281, 538–641 and 678–744.
- A 12-tall tower at 142, a staircase up to row 6 (157–196), a tunnel slab (334–405), and 13-tall
  pillars every 9 columns (537–582).

**Numbers (per 40 Hz tick in the old code), converted to units per second at 960×640.** The old
code moved things in raw screen pixels, so the game ran at a different speed on every phone. The
reference here is the phone in the 2019 screenshots (1440×720, play area about 1320×720), where
the level was designed and tuned. Each number below is noted in the code next to its old value.

| What | Old | New |
|---|---|---|
| World scroll (tiles) | 8 px/tick | 233 u/s |
| Background scroll | 2 px/tick | 0.25 × world |
| Gravity (hero) | 3 px/tick² | 4,267 u/s² |
| Jump | −H/20 per tick | 1,280 u/s (6 tiles high, 0.6 s in the air) |
| Bandit run (relative to the ground) | 10 px/tick | 291 u/s |
| Bandit gravity / hop | 4 / −10 | 5,689 u/s² / 356 u/s |
| Ring | 20 px/tick | 582 u/s |
| Step forward (swipe right) | 15 px | 11 u |
| Hero box | 64×128 | 64×128 (chest and feet boxes are the middle half) |
| Bandit box | 48×96 | 48×96, 50 of them, one every 512 u, 2 hits |
| Lives | 3 | 3 |
| Interstitial | every 3 game overs | every 5 (config), when leaving the game over screen |

**Identity.**
- Android package `com.HaizStudio.ChakaZulu`. The old gradle says version code 3 (the last built
  bundle is 2), so the new one is **10**, version 2.0.0.
- AdMob account `ca-app-pub-6252973855685631`: app `~9782480278`, banner `/5308882795`, interstitial `/7987017025`.
- Music: `audio/chaka.mp3` (2 min 10 s). Sound effects: ring throw and bandit hit.
- Icon: Panoramic's head (anime style: dark-brown skin, wild black hair, red scarf, blue shoulder
  guard) on coral `#ff7675`.

**Store history and risks.**
- **Signing key.** The old upload keystore (`keystore.jks`) and its password are in the history of a
  **public** GitHub repo (commits from 2024). Treat that key as leaked.
- **Third-party art.** The bandit (anime ninja), the tile set, the backgrounds, the menu, the game
  over and the level end look like stock art. Redrawing everything removes that risk.
- **Real person.** "Chaka Zulu" refers to Shaka Zulu, the 19th-century Zulu king. That's allowed
  in both stores, but the hero must be a respectful tribute, not a caricature. Flagged once; you decide.
- **About text.** The old About says "not for commercial purposes", which conflicts with ads.
  It will be rewritten.

## Decisions (defaults, confirmed by you)

- **Engine:** Godot 4.7.2 + GDScript, Compatibility renderer.
- **Screen:** landscape, design 960×640, `canvas_items` stretch with `keep_height`. The world is
  always 20 tiles tall; wider phones see further ahead. 120 Hz.
- **Art:** all new, made with free local tools (code drawing, hand-written SVG → PNG, numpy). Old
  colours kept as anchors. Panoramic keeps his identity (skin, hair, red scarf, blue shoulder
  guard), rebuilt as a rigged cut-out character so every move is smooth.
- **Name:** "Chaka Zulu" in the stores and on the menu logo; the hero is Panoramic.
- **Ads:**
  - Bottom banner. The world is drawn above it, so it never covers the ground.
  - Interstitial after every 5th game over, when leaving that screen.
  - Google's consent form (UMP) and Apple's tracking prompt (ATT).
- **Extras behind switches, off at launch:** Firebase, Remove ads, leaderboards.
- **Languages:** English and French.

## New in 2.0 (beyond a faithful port)

- **A real ending.** Reaching HOME ends the level. The result screen shows the Red Bobs collected,
  bandits beaten, lives left and 1 to 3 stars. Best score and stars are saved.
- **Same speed on every phone.** Frame-rate independent, so smooth at 60, 90 and 120 Hz.
- **Readable hang.** A vine runs along the top of the screen to show where Panoramic can grab.
- **Tutorial.** On the first play, a hand shows swipe up, tap and swipe down.
- **Juice:**
  - Squash and stretch on jumps and landings.
  - A sparkle burst and "+1" pop on each Red Bob.
  - Hit-stop, shake, flash and haptics when hurt.
  - Bandits tumble when knocked out.
  - Dust on landing, screen transitions, button springs and a full set of sounds.
- **Pause:** with the pause button, the Android back button, or when the app goes to the background.

## Project layout (`New/`)

```
project.godot  export_presets.cfg  README.md  .gitignore
config/game_config.cfg           ad units, store ids, switches
assets/{art,audio,fonts,icons}/  localization/strings.csv (en, fr)
src/autoload/   config save device audio haptics services nav ui
src/services/   ads analytics share store leaderboards push   (each does nothing without its plugin)
src/game/       level.gd (map), world.gd (pure rules), views (tiles, parallax, hero rig, bandits, rings, bobs), hud, pause, results
src/screens/    boot, menu, settings/about
tests/          run_tests (logic, speeds at 30/60/120 Hz, level reachability), bot, capture, film
tools/          art/*.py + svg/, sfx_synth.py, audio.py, build_android.sh, build_ios.sh, store_art.py
docs/           PLAN.md RELEASE.md privacy-policy.html art/{STYLE,MANIFEST}.md store/
```

## Work order and gates

1. **Tooling** (done: Godot 4.7.2 with templates, JDK 17, Android SDK 36, Xcode 27.1, Python, ffmpeg).
2. **Core.** Level loader, world rules, a plain-shape view, tests. A bot plays the whole level.
   - Gate: tests pass; the bot finishes the level; screenshots on 4+ screen shapes.
3. **Look.**
   - STYLE.md first, then the art: hero rig, bandit rig, tiles, parallax sky/sun/hills/city,
     props, Red Bob, ring, HOME, logo, interface kit.
   - Sounds synthesised; the music remastered.
   - Gate: a before/after board and every screen at native size.
4. **Feel.** Juice and transitions. Gate: frame strips of jump, hang, hit, pickup and win.
5. **Services.** AdMob + UMP + ATT, share, haptics, each one followed by a build and an emulator run.
   Gate: test ads and the consent form on the emulator.
6. **Devices.** Android emulator and your phone (signed APK), iOS Simulator and your iPhone.
   Gate: you play it and say it works.
7. **Store art.** Icon (iOS, Play, adaptive), screenshots per language, feature graphic.
8. **Publish.** Privacy policy online, AdMob, Play Console, App Store Connect, click by click, with
   `docs/RELEASE.md` kept up to date.

## Things only you can do

- **Play Console:**
  - Upload key reset, if we make a new key (Play takes about 2 days to switch).
  - App content, listing, release.
- **AdMob:**
  - The iOS app and its ad units.
  - The consent (GDPR) and IDFA messages, published.
- **Apple:**
  - The app record in App Store Connect (bundle `com.HaizStudio.ChakaZulu`, team ZUGMSRF5HZ).
  - Signing in Xcode on your Mac.
- **Privacy policy:** publish it on haizstudio.github.io (same place as Super Gassamanh).
- **Testing:** play on your phones.
