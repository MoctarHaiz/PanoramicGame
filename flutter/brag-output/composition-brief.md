# Hyperframes Composition Brief: Panoramic (Chaka Zulu)

## Objective
Create a short launch-style brag video for Panoramic (Chaka Zulu), a hand-drawn 2D side-scrolling platformer rebuilt from an Android-only Java game into a single Flutter + Flame codebase that runs identically on Android, iOS, and the web, with a personalization feature ("hero packs") that puts a kid's own face, name, and birthday message into the game.

## Output
- Composition directory: `brag-output/composition/`
- Rendered video: `brag-output/brag.mp4`
- Format: landscape — 1920x1080
- Duration: ~19.6 seconds (narration-driven; see Voiceover timing below — stay within 15-25s)

## Source Material
- Project root: `/Users/moctar/Documents/Games/PanoramicGame-Android-Game/flutter`
- Primary files read: `README.md` (repo root and `flutter/README.md`), `pubspec.yaml`, `lib/game/*.dart`, and the real game art under `assets/images/`
- Product name: Panoramic (published on Google Play as "Chaka Zulu")
- Tagline / strongest claim: "Same speed on every phone" — the old Android build moved things by device pixels so it ran faster or slower per screen; the Flutter rebuild uses a fixed 960x640 virtual screen and a fixed 40 updates/second so it behaves identically on Android, iOS, and the web.
- Key UI or visual moment to recreate: the game's own "Panoramic — Tap to play" title card (sunset dock, palm fronds, 5 stars, treasure chest), the hero's real run and ring-throw sprite sheet in motion, and the personalization flow (a kid's face + name on the hero, ending in a birthday message on the level-complete screen).
- Copy that must appear verbatim or near-verbatim (all literal strings from the project — see Grounding below):
  - "Tap to play" (the game's own title-card text, from `menu.png`)
  - "40 updates per second" / "same speed on every phone" (from `flutter/README.md`: "Same speed on every phone... a fixed 960 x 640 'virtual' screen and a fixed 40 updates per second")
  - "Android, iOS and the web" (from the repo root `README.md`: "One codebase for Android, iOS and the web")
  - "Happy 7th Birthday, Emma!" style birthday message — grounded in `flutter/assets/hero_packs/demo/hero.json`, which stores exactly this shape of data: `{"name": "Amani", "age": 7, "message": "Happy 7th birthday, Amani!"}`. Use the fictional stand-in name "Emma" (not the real demo asset's name) per the no-personal-data rule below; keep the message pattern ("Happy [N]th Birthday, [Name]!") faithful to the real `hero.json` schema.
  - "Panoramic" (the in-game title lettering baked into `menu.png`)

## Creative Direction
- Tone preset: default
- Creative direction: warm, hand-drawn kids'-storybook energy — playful and bright like the game's own sunset art. Not corporate, not jokey-chaotic. Comfortable pacing (5 scenes), clean transitions (hard cuts + soft crossfades), one deliberately gentler/slower beat for the birthday reveal.
- Angle: this isn't a generic "we shipped cross-platform" brag. It's "we took a 10+ year old Android-only game, made it behave identically on every phone and the web, and then turned the hero into a vessel for an actual birthday gift." The emotional payoff (a kid's own face and name appearing in their platformer) is the single most video-worthy, least generic thing in this project — it must be the centerpiece, not an afterthought.
- Hook (first 2-3 seconds): Haiz Studio logo (lime mark on orange, alien icon — `HaizStudioSplash.png`) slams in, hard cut straight to the real "Panoramic — Tap to play" title card (`menu.png`). First spoken line lands right on that cut.
- Outro / punchline: pull back to the same title card, logo small in the corner, final spoken line, hold on "Tap to play."
- Avoid:
  - Generic SaaS language ("streamline," "unlock," "seamless") — this is a kids' platformer, not a SaaS tool
  - Abstract filler visuals (color washes, generic particles) — every scene must use the real sprite/background art provided in `assets/images/`
  - Redesigning the game's look — use its actual sunset/gold and sky-blue palette, not an invented brand palette
  - Inventing fake UI chrome that doesn't exist in the real game (no fabricated settings screens, no fake multiplayer, no fabricated stats/leaderboards)

## Visual Identity
- Background (sunset sky, from the title card art): warm gold/orange, approx `#F2994A` → `#FFD27A` gradient
- Secondary background (daytime sky, from `background/bg0.png`): sky blue, approx `#4FB6E8`
- Accent (Haiz Studio mark, from `HaizStudioSplash.png`): lime green `#A4CC3A` on orange `#F2890E`, charcoal `#3A3A32` panel squares
- Text: warm cream `#FFF8EC` for overlay captions on dark/art backgrounds; dark brown `#3B2A1A` where captions sit on the light parchment of the title card
- Display font: no bundled font ships with the project (the game's own titles are hand-lettered and baked into PNGs) — choose a friendly, rounded, slightly hand-drawn display face in that storybook register for any overlay captions; do not claim a specific licensed font name
- Body font: a clean rounded sans for small captions
- Visual references from the project (all copied into `composition/assets/images/`):
  - `menu.png` — the real title card (sunset dock, "Panoramic — Tap to play", 5 stars, treasure chest)
  - `HaizStudioSplash.png` — the real studio logo
  - `running/panoramic1.png` … `panoramic8.png` — real hero run-cycle frames
  - `stick/stick0.png` … `stick4.png` — real hero ring-throw frames
  - `level1Tileset.png` — real ground/platform tileset
  - `background/bg0.png` — real sunset/skyline parallax background
  - `gameOver/star1.png` … `star3.png` — real star icons from the level-complete screen
  - `levelEnd/levelEnd1.png`, `levelEnd/levelEndHome.png` — real level-complete screen art

## Storyboard
Use `brag-output/brag-plan.md` as the creative contract (full storyboard with audio-coupled ideas, SFX notes, and sequencing is there). Scene summary with updated absolute timing (adjusted slightly from the plan to fit the generated narration — see Voiceover timing below):

1. **Hook — logo to title card** — 0.0-2.5s — Haiz Studio logo hard-cuts to the real "Panoramic — Tap to play" title card. No overlay text; the game's own art carries it.
2. **Reveal — real gameplay** — 2.5-6.5s — real hero run cycle animates over the real tileset + parallax background; a swipe-up icon triggers a jump, then a tap icon triggers the real ring-throw sprite.
3. **Highlight — same speed everywhere** — 6.5-10.5s — one phone-frame holds the run cycle with a caption ticking to "40 updates/sec," then a second phone and a browser-tab frame snap in beside it, all three playing the identical cycle in lockstep. Caption: "Android, iOS and the web."
4. **Emotional beat — the hero-pack birthday reveal** — 10.5-16.0s — the hero's head swaps to a placeholder kid's face (fictional stand-in, not a real photo), "Tap to play" on the banner is replaced by the typed-on name "Emma," hard cut to the real level-complete art with "Happy 7th Birthday, Emma!" and the real stars arriving one by one.
5. **Outro / punchline** — 16.0-19.6s — back to the same title card ("Tap to play" restored), Haiz Studio mark small in the corner, final spoken line, hold.

## Voiceover
Narration is enabled (`--voice`). Three lines already generated via Kokoro (`af_heart`) and copied into `composition/assets/voice/`:

- `assets/voice/line1.wav` — 3.8s — "This Android game used to run at a different speed on every phone." — start ≈ 2.0s (lands just before/through the Scene 1→2 cut)
- `assets/voice/line2.wav` — 5.2s — "So we rebuilt it in Flutter, locked to the same speed on Android, iPhone, and the web." — start ≈ 6.5s (opens Scene 3)
- `assets/voice/line3.wav` — 3.6s — "Same game, every phone. Now it can carry your kid's name too." — start ≈ 16.0s (opens Scene 5)

These three starts plus their durations are why the overall video is ~19.6s rather than the plan's original 19s — Scene 5 should run through 19.6s so line3 isn't cut off. Adjust scene 4/5 boundary and exact starts by a few tenths of a second if needed for lip-sync-free comfort (there's no lip sync to match, just avoid dialogue overlap and avoid talking over the hard cut into Scene 4's face-swap beat). Put voice clips on their own track (e.g. `data-track-index="3"`); they don't overlap each other so they can share that index.

Music must duck under each line (approx 0.30-0.35 → 0.12-0.15) and return to normal between lines.

## Audio
- Audio role: warm bed with light, motion-matched game SFX, plus the three narration lines above
- Audio arc: logo hit → steady playful bed under gameplay and the cross-platform reveal → brief tender lift at the birthday reveal → soft fade on the final hold
- Music: `assets/music/happy-beats-business-moves-vol-1-by-ende-dot-app.mp3` (already copied into `composition/assets/music/`), volume 0.30-0.35 normally, ducked to 0.12-0.15 under each narration line
- Music treatment: enter softly under the logo hit (scene 1), steady under scenes 2-3, small lift into the strong cues near scene 4's reveal, fade to silence under the final hold (scene 5)
- Music cue guidance: cue preset already copied to `composition/assets/music/cues/happy-beats-business-moves-vol-1-by-ende-dot-app.music-cues.json` (and `.md`). Estimated tempo 120.19 BPM. Strong cues available at 16.02s, 17.02s, 18.02s, 20.02s, 21.01s, 22.01s, 23.02s — target the ones nearest the birthday-reveal beats (face swap / name type-on / level-complete cut, now around 10.5-16.0s) and nearest the Scene 5 title-card return (~16.0s), nudging within ±0.15s for readability. Earlier beat grid (3.0-15.5s, every ~0.5s) available for lighter accents (footstep ticks, throw whoosh) — use sparingly, not every beat.
- Audio-reactive treatment: subtle — the sunset glow behind the title card (scenes 1 and 5) may breathe gently with the music's low end; nothing else should visibly pulse
- Audio-coupled moments:
  - Scene 2 — swipe-up gesture icon → jump (SFX on the icon's appearance); tap gesture icon → throw whoosh (SFX on the icon's appearance)
  - Scene 3 — each device frame's snap-in gets a soft UI tick; once all three are synced, let the music carry it with no extra SFX
  - Scene 4 — soft letter-tick while "Emma" types on; a gentle chime per star on the level-complete screen, landing left to right as each star arrives
  - Scene 5 — none beyond the final spoken line and the music fade
- SFX selection guidance (exact files already copied into `composition/assets/sfx/`, chosen per `audio.md`'s tone→energy table for `default` — moderate, 3-5 cues):
  - Logo hit (scene 1): `assets/sfx/impact/impactBell_heavy_000.ogg`
  - Jump (scene 2, on the swipe-up icon): `assets/sfx/impact/impactWood_light_000.ogg` (light, warm, organic — fits the storybook register better than a harsh impact)
  - Throw whoosh (scene 2, on the tap icon): `assets/sfx/casino/card-slide-3.ogg` (its sliding/swipe character reads as a whoosh; re-pitch/trim if Hyperframes' implementation needs a tighter hit)
  - Device frame snap-ins (scene 3): `assets/sfx/interface/drop_001.ogg`, `drop_002.ogg`, `drop_003.ogg` in order for the first/second/third frame
  - Name type-on (scene 4): `assets/sfx/keyboard/keypress-001.wav`, `keypress-007.wav`, `keypress-013.wav`, `keypress-019.wav`, `keypress-025.wav` — cycle/randomize across these 5 for the letters in "Emma" so repeats don't sound identical
  - Star arrivals (scene 4): `assets/sfx/impact/impactGlass_light_001.ogg`, `_002.ogg`, `_003.ogg` — one per star, delicate/achievement character
  - "Tap to play" tap, if a tap/cursor affordance is shown on the title card: `assets/sfx/interface/click_001.ogg`
- SFX analysis guidance: prefer the files listed above as-is; if Hyperframes wants alternates, consult `<hyperframes-skill-dir>/assets/sfx/sfx-analysis.md` and prefer low/medium high-frequency-risk picks for the repeated star-chime and keypress moments
- Exact SFX choice: the files above are strong candidates grounded in the bundled library; Hyperframes should feel free to adjust exact timestamps, trim, or swap to a listed neighbor (e.g. a different `drop_00x` or `impactGlass_light_00x`) based on the implemented animation
- Audio files: music, cue presets, voice lines, and all SFX above are already copied into `brag-output/composition/assets/` (see subfolders `music/`, `voice/`, `sfx/impact/`, `sfx/interface/`, `sfx/casino/`, `sfx/keyboard/`)

## Hyperframes Instructions
Load the composition-building Hyperframes domain skills — `hyperframes-core` (composition contract + `data-*` timing), `hyperframes-animation` (motion), `hyperframes-creative` (design spec, beats, audio-reactive), `hyperframes-keyframes` (seek-safe keyframes), and `hyperframes-cli` (lint/check/render). `/brag` is its own workflow: do not enter the `hyperframes` entry-point intent interview and do not route into its generic promo / launch-video workflow. Prefer native Hyperframes conventions over anything above.

Requirements:
- Show at least one real UI, copy, or visual element from the source project (the title card, the sprite art, and the `hero.json`-grounded birthday-message pattern all qualify — use all three).
- Keep all text readable in the final render — hold each caption at least to the reading-time floor (short label ~0.8s settled; a full sentence ~0.3s/word).
- Keep the video within 15-25 seconds (target ~19.6s per the voiceover timing above).
- Include the planned music/SFX/voice layer — it is not disabled.
- Treat `/brag`'s audio notes as guidance, not a fixed cue sheet — choose exact SFX timestamps after the visual animation exists.
- Treat music cue metadata as optional timing hints; ignore cues that hurt readability, scene pacing, or the story. Use only 1-3 strong-cue locks in this video.
- Honor the planned music ducking under each narration line and the fade-out at the end.
- Use local assets only (already copied into `composition/assets/`) — no absolute paths, no remote URLs.
- Run `hyperframes check` before render — it is brag's single gate.
- Keep creation and rendering local. Remote or publishing workflows require a separate explicit user request.

## Grounding note
Every factual claim above traces to a real file: the "same speed on every phone" / "40 updates per second" / "Android, iOS and the web" lines are quoted or lightly trimmed from `flutter/README.md` and the repo root `README.md`. The birthday-message pattern is grounded in the real `hero_packs/demo/hero.json` schema (`name`, `age`, `message`: "Happy Nth birthday, Name!"); the video uses the fictional stand-in name "Emma" rather than the real demo asset's name or any real child's data, per the no-personal-data rule in Step 1 of the `/brag` skill. Do not introduce new factual claims (stats, store ratings, user counts) that aren't in the project.
