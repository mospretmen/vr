# Fretspace Roadmap

## Phase 1 — Practice & Visualization MVP (current)

The daily-use core: put on the headset, calibrate to your guitar in ~30
seconds, see any scale/chord/arpeggio on your real fretboard.

- [x] Music theory engine (scales, modes, pentatonics, triads, sevenths,
      diatonic triads, tunings) — `MusicTheory`, 26 tests green
- [x] Fret geometry + two-point calibration solver — `FretboardKit`
- [x] visionOS app shell: control panel, immersive overlay, pinch calibration,
      2D chart panel
- [ ] Build & run on device (needs Xcode installed, then Apple Developer
      provisioning for hand tracking)
- [ ] Calibration polish: preview markers while placing points, subtle snap
      animation, persistence across sessions (store transform relative to a
      world anchor via `WorldTrackingProvider` world anchors)
- [x] Position boxes (one box at a time, box picker in control panel)
- [x] Exercise engine v1: scale runs (up/down through a box) and triad
      inversion drills, with step-through UI and dim lookahead preview
- [x] Left-handed mode (mirror string order)
- [ ] 3-notes-per-string patterns; auto-advance exercises via listen mode
      (play the target note to advance) once Phase 3 audio is validated
- [ ] App icon, onboarding flow, App Store metadata

## Phase 2 — Backing tracks & chord timelines

Play a backing track; the overlay follows the progression (scale context +
current chord emphasized), chart panel shows the progression ahead.

- [x] Chord timeline data model (`ChordTimeline` in MusicTheory, mirrored by
      backend `chord_events` schema and `/v1/tracks/:id/timeline` wire format)
- [x] Clock-driven timeline playback preview (BackingTrackController: play/
      pause/loop, now+next chord, overlay follows via activeChord/activeScale)
- [x] Bundled starter progressions (blues A/E/G, ii–V–I, pop loop) offline in
      the app and seeded in the backend API
- [ ] Real audio: AVAudioEngine track playback with beat-accurate dispatch
      (replace the bare clock), bundled audio stems
- [ ] Overlay transitions synced to chord changes (pre-announce next chord
      ~1 beat early, crossfade colors)
- [ ] In-app track browser backed by the API; Neon-backed repo behind the
      existing TrackRepo interface

## Phase 3 — Live listening & effects

The wow layer: the app hears what you play.

- [x] Chord recognition core: chromagram template matcher + decision
      smoother (`AudioAnalysis` target, unit tested with synthetic chroma)
- [x] Scaffolding: mic→FFT→chroma extractor, ListenModeController, chord
      aura particle entity (untested until Xcode/device builds are possible)
- [ ] Validate the template matcher on real guitar signal; upgrade to an
      on-device CoreML classifier behind the same interface if needed
- [ ] **Chord aura** tuning on device: emitter placement, palettes,
      intensity from RMS dynamics instead of match confidence
- [ ] Note-by-note feedback for exercises (did you hit the target note?)
- [ ] Latency budget: < 60 ms mic-to-visual

## Phase 4 — Product & commerce

- [ ] Accounts (Sign in with Apple), practice stats sync (backend + web
      dashboard)
- [ ] StoreKit 2: subscription (track packs + listen mode premium?) —
      pricing TBD
- [ ] Notation panel upgrade: real staff/tab rendering, possibly MusicXML
      import
- [ ] Object-tracking "instant lock" as premium calibration for popular
      guitar models
- [ ] Localization; App Store launch

## Deliberately out of scope for now

- Multiplayer/shared sessions (SharePlay) — revisit post-launch
- Non-guitar instruments (bass works already via tunings; ukulele/mandolin
  need geometry presets)
- Android/Quest — native visionOS bet is intentional
