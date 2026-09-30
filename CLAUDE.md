# Fretspace — VR Guitar Practice for Apple Vision Pro

Mixed-reality app that locks a scale/chord overlay onto the player's **physical
guitar fretboard**, with a floating chart panel. Working title "Fretspace";
final name TBD before App Store submission.

## Architecture decisions (settled 2026-09-29 — don't relitigate)

- **Native visionOS** (Swift 6, SwiftUI, RealityKit, ARKit). WebXR was ruled
  out: no passthrough-camera access, no object tracking, no App Store listing.
- **Manual two-point calibration** for v1 guitar targeting: user pinches at the
  nut center, then the 12th-fret center. The 12th fret is half the scale
  length, so this also recovers the instrument's true scale length. ARKit
  object tracking is a possible later premium upgrade, not v1.
- **MVP = practice/visualization mode** (scales, chords, triads on the
  overlay + 2D chart panel). Backing-track sync and live mic chord detection
  are later phases — see docs/ROADMAP.md.
- **Backend**: Node + Fastify + Drizzle on **Neon** (Postgres).
  **Web companion**: React + Vite + Tailwind. These serve accounts, the
  backing-track/chord-timeline library, and practice stats — not the MVP.

## Repo layout

- `packages/GuitarCore/` — Swift package, **pure logic, fully testable on this
  Mac with `swift test`** (no Xcode needed):
  - `MusicTheory` target: PitchClass/Note, ScaleType/Scale, ChordQuality/Chord,
    Tuning, FretboardModel (maps music → string/fret highlights with roles).
  - `FretboardKit` target: FretboardGeometry (fret-spacing math, marker
    positions in local board space, left-handed mirroring) and
    FretboardCalibration (two world-space points + normal hint → rigid
    transform; rejects degenerate input).
  - `AudioAnalysis` target: Chromagram, ChordMatcher (template matching,
    cosine similarity, 0.7 confidence gate), ChordDecisionSmoother
    (N-consecutive-frames debounce). The app-side mic→FFT front-end is
    `apps/.../Sources/Audio/ChromaExtractor.swift`; keep DSP thin there and
    all decisions in this testable target.
- `apps/FretspaceVision/` — visionOS app sources + `project.yml` (XcodeGen).
  Requires Xcode + visionOS SDK to build: `brew install xcodegen`, then
  `cd apps/FretspaceVision && xcodegen generate` and open the project.
  - Local fretboard space convention: origin at nut center, +X toward bridge,
    +Y out of the board, +Z low string → high string. Keep all geometry in
    this space; only `overlayAnchor` carries the world transform.
- `backend/` — Fastify API + Drizzle schema (users, backing_tracks,
  chord_events timeline, practice_sessions).
- `web/` — React companion shell.
- `docs/ROADMAP.md` — phase plan and feature backlog.

## Conventions

- All rendering data flows one way: `AppModel` (observable, @MainActor) →
  `FretboardOverlayBuilder.build(...)` (stateless, pure data → Entity tree) →
  swapped under `overlayAnchor` in `ImmersiveView`. Never mutate entities from
  views; rebuild instead. `model.overlayDidChange()` bumps `overlayRevision`
  to trigger rebuilds.
- String index 0 = lowest-pitched string; fret 0 = open string, everywhere.
- New scales/chords/tunings are data, not code: add a static preset to the
  relevant catalog (`ScaleType.all`, `ChordQuality.all`, `Tuning.all`).
- Run `cd packages/GuitarCore && swift test` before considering any core
  change done.

## Environment notes

- This Mac currently has Command Line Tools only (no Xcode.app) — the app
  target can't be built here until Xcode is installed; the packages can.
