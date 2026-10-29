# Brag Plan: Panoramic (Chaka Zulu)

## What is this app?
A hand-drawn 2D side-scrolling platformer, originally an Android-only Java game, rebuilt from scratch in Flutter + Flame so it runs pixel-identical (same speed, same layout, no stretching) on Android, iOS, and the web — and can be personalized with a kid's own face, name, and a birthday message baked into the ending.

## The angle
This isn't "we shipped a cross-platform game," it's "we took a 10+ year old Android game, made it run at the exact same speed and feel on any phone (including ones that didn't exist when it was written), and then turned the hero into a vessel for a birthday gift." The video should earn its claim with the real art and the real hero-pack mechanic, not an abstract "it's cross-platform!" slide. The emotional payoff — a kid's face and name appearing in their own platformer — is the thing nobody else's dev-log brag video has, and it's real, not a mockup.

## Hook (first 2-3 seconds)
Haiz Studio logo (lime-on-orange, the alien mascot) slams in, hard cut straight to the game's own title card: the sunset dock, palm leaves, five stars, and the hand-lettered "Panoramic — Tap to play" banner. No narration yet except a single spoken line landing on the cut: "This game used to run at a different speed on every phone."

## Key moments (the middle)
- The hero sprite (the real `panoramic*.png` run cycle) running across the real tileset ground with the real sunset/skyline parallax behind it, then a swipe-up jump and the ring-throw sprite firing — these are the actual in-game frames, composited and animated, not a redrawn mockup.
- The "same everywhere" claim shown concretely: one phone-shaped frame holding the run cycle, with a readout-style caption ticking to "40 updates/sec" while two more device silhouettes (a second phone, a browser tab) snap in beside it playing the same frame in lockstep — proving identical behavior instead of just claiming it.
- The hero-pack reveal: the generic hero's round head is replaced by a placeholder kid's face, the name "Emma" types onto the menu banner where "Tap to play" was, then a hard cut to the level-complete screen (stars + the game's own `levelEnd` art) with the message "Happy 7th Birthday, Emma!" This is the single most video-worthy, least generic beat in the whole project.

## Outro / punchline
Pull back to the same sunset title card from the hook, Haiz Studio mark small in the corner. Final spoken line: "Same game. Every phone. Now it's got your kid's name on it too." Hold on "Tap to play."

## User flow worth showing
Entry → key action → result, taken directly from the game's own controls and its headline feature:
1. **Entry:** the title card, tap to play.
2. **Key action:** swipe up to jump, tap to throw a ring — shown as the real sprite mid-jump and mid-throw, with the swipe/tap gesture simulated on screen.
3. **Result:** the personalized ending — the kid's face on the hero, their name on the menu, and the birthday message on the level-complete screen.

## Tone
- Preset: default
- Creative direction: warm, hand-drawn kids'-storybook energy — playful and bright like the game's own sunset art, not corporate, not jokey-chaotic. The personalization beat should land like a warm surprise, not a punchline.
- Interpretation: comfortable pacing, 5 scenes, each allowed to breathe for 2.5-5.5s. Transitions stay clean (hard cuts and soft crossfades) rather than flashy. The one moment that's allowed to slow down slightly is the birthday reveal — everything else stays brisk.

## Format: landscape — 1920x1080
## Duration: 19s

## Visual identity (from the project)
- Background (sunset sky): warm gold/orange, approx `#F2994A` → `#FFD27A` gradient (from the menu art's sky)
- Secondary background (daytime sky): sky blue, approx `#4FB6E8` (from `background/bg0.png`)
- Accent (Haiz Studio mark): lime green `#A4CC3A` on orange `#F2890E`, with charcoal `#3A3A32` panel squares
- Text: warm cream/off-white `#FFF8EC` for overlay captions, dark brown `#3B2A1A` where text sits on light art (matches the in-game "Tap to play" signpost)
- Display treatment: no bundled font files ship with the project — the game's own titles are hand-lettered and baked into PNGs. Use a friendly, rounded, slightly hand-drawn-feeling display face for overlay captions (storybook/kids'-app register), and a clean rounded sans for any smaller caption text. Do not invent a specific licensed font name; pick something in that register.
- Strongest visual element: the "Panoramic — Tap to play" title card (sunset dock, palm fronds, 5 stars, treasure chest) and the hero run/throw sprite sheet — use both directly.

## Share copy (draft)
We rebuilt our old Android-only platformer in Flutter so it runs at the exact same speed on every phone — then gave it a feature no other platformer has: your own kid's face and name in the game, with a birthday message waiting at the end.

## Audio direction
- Role: warm bed with light, motion-matched game SFX
- Music: one of the bundled "Happy Beats / Business Moves" tracks — `happy-beats-business-moves-vol-1-by-ende-dot-app.mp3` (120 BPM, cue preset available)
- Music treatment: start under the logo hit at low-mid volume, build slightly into the gameplay scenes, dip under the spoken lines throughout (narration leads, music supports), small lift at the birthday reveal, soft fade on the final title-card hold
- Music cue guidance: preset read from `happy-beats-business-moves-vol-1-by-ende-dot-app.music-cues.json`. Estimated tempo 120.19 BPM. Target strong cues near 16.02s, 17.02s, and 18.02s for the birthday-reveal beats (face swap → name type-on → level-complete cut); nudge within ~0.15s as needed for readability. Earlier beat grid (3.0-15.5s, every ~0.5s) available for lighter accents (footstep ticks, ring-throw whoosh) — use sparingly, not every beat.
- Audio-reactive treatment: subtle — the sunset glow behind the title card may breathe gently with the music's low end; nothing else should visibly pulse to the beat
- SFX posture: moderate — logo hit, soft game-UI tap on "Tap to play," footstep/run texture under the run cycle, a whoosh on the ring throw, a gentle chime on the birthday message and stars, soft fade-out tone on the final hold
- Audio-coupled moments: swipe-up gesture paired with a light jump sound; tap gesture paired with the throw whoosh; name "Emma" typing on with soft letter ticks; stars on the level-complete screen landing one by one with a chime each
- Restraint rule: music must never fight the two spoken lines — duck it under narration; do not let SFX density turn the birthday scene busy, it should feel tender, not celebratory-loud

## Storyboard

### Scene 1 — Hook: logo to title card — 2.5s
Haiz Studio logo (lime mark on orange, alien icon) fills the frame, hard cut to the real "Panoramic — Tap to play" title card (sunset dock, palm leaves, 5 stars, treasure chest). No overlay text — the game's own art carries the scene.
Sequential/interaction: none
Audio intent: a confident, warm open — the logo lands with a clean hit, then the title card breathes
Audio-coupled idea: logo hit synced to the hard cut; spoken line "This game used to run at a different speed on every phone" starts right on the cut to the title card
Music: soft entrance under the logo hit, low-mid volume
Transition mood: hard cut → Scene 2

### Scene 2 — Reveal: real gameplay — 4s
The actual hero run-cycle sprite animates left-to-right over the real tileset ground and sunset/skyline parallax background. Mid-scene: a swipe-up gesture icon appears near the hero and it jumps; immediately after, a tap icon appears and the hero throws the ring (real throw sprite), whoosh as it arcs off-frame.
Sequential/interaction: yes — swipe-up gesture icon → jump, then tap icon → throw, in that order, each held long enough to register as a beat, not simultaneous
Audio intent: playful momentum, light foot-texture under the run, a clear whoosh on the throw
Audio-coupled idea: jump lands on a light SFX tied to the swipe icon's appearance; throw whoosh tied to the tap icon
Music: light beat-grid footstep accents permitted here, used sparingly (not every beat)
Transition mood: clean wipe → Scene 3

### Scene 3 — Highlight: same speed everywhere — 4s
One phone-shaped frame holds the run cycle with a small readout caption ticking up to "40 updates/sec." Two more frames (a second phone, a browser tab) snap in beside it, each playing the identical run cycle in lockstep — proving the claim side by side rather than stating it.
Sequential/interaction: yes — phone 1 settles first, then phone 2 snaps in, then the browser tab snaps in, each a beat apart, all three then hold in sync together
Audio intent: a light confirming tick on each frame's arrival, settling into a steady, in-sync feel once all three are on screen
Audio-coupled idea: each frame's snap-in gets a soft UI tick; once synced, let the music carry it with no extra SFX
Music: steadier, slightly fuller than Scene 2
Transition mood: soft crossfade → Scene 4

### Scene 4 — Emotional beat: the hero-pack birthday reveal — 5.5s
The hero's round head swaps to a placeholder kid's face (fictional stand-in, not a real child's photo). On the title card's banner, "Tap to play" fades and the name "Emma" types on in its place. Hard cut to the real level-complete screen (stars + level-end art) with the message "Happy 7th Birthday, Emma!" settling in.
Sequential/interaction: yes — face swap settles first (hold ~1s to register), then name types on letter by letter (hold the full word after), then hard cut to the birthday message + stars arriving one by one left to right
Audio intent: tender, warm, the one moment allowed to slow down slightly — this is the heart of the video
Audio-coupled idea: soft letter-tick while "Emma" types on; a gentle chime per star on the level-complete screen; warm pad swell under the birthday message itself
Music: small, restrained lift into the strong cues near 16-18s; duck further under the spoken line if narration lands here
Transition mood: dramatic but soft (slow crossfade, not a flash) → Scene 5

### Scene 5 — Outro / punchline — 3s
Back to the same sunset title card from Scene 1 ("Tap to play" restored), Haiz Studio mark small in the corner. Final spoken line lands here: "Same game. Every phone. Now it's got your kid's name on it too."
Sequential/interaction: none
Audio intent: a settled, satisfied close
Audio-coupled idea: none beyond the spoken line
Music: gentle fade to silence under the final hold
Transition mood: soft crossfade from Scene 4, hold to black

**Music mood for this video:** upbeat but warm — happy-beats energy dialed back to playful-sincere rather than corporate-hype
**Audio summary:** a warm, bright music bed carries the whole video at low-mid volume so the spoken lines and the game's own sound language (jump, throw whoosh, star chimes) stay the focus, with a brief tender lift at the birthday reveal and a soft fade on the final hold.

## Voiceover script
Three short lines, warm and conversational, not a hype-read. Music ducks under each line and returns between them.

1. (lands on the Scene 1 → Scene 2 cut) "This Android game used to run at a different speed on every phone."
2. (opens Scene 3, over the matching-devices reveal) "So we rebuilt it in Flutter — locked to the same speed on Android, iPhone, and the web."
3. (opens Scene 5, over the title-card return) "Same game, every phone. Now it can carry your kid's name too."
