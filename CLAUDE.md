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
- **Quality bar (owner directive): state of the art, no exceptions.** Every
  feature ships with structured logging, user-facing error surfacing, and
  motion polish as part of the feature — not as a later pass.
  - Logging: `AppLog.<category>` (os.Logger) in the app; pino in the backend.
    Never log user-identifying content.
  - Errors: raw errors never reach the UI. Log them, map them to a
    `UserFacingError` case (title + recovery guidance), route it to
    `AppModel.presentedError` — the single alert surface.
  - API changes: the JSON wire format is pinned by WireFormatTests in
    GuitarCore against backend/src/tracks/repo.ts. Change both sides and the
    fixtures together, never one alone.

## Environment notes

- Xcode 27 is fully set up locally (license accepted, xcode-select points
  at it, visionOS 27 SDK + simulator runtime installed). Build with
  `xcodebuild -scheme FretspaceVision -destination 'generic/platform=visionOS Simulator'
  -derivedDataPath .derived-data CODE_SIGNING_ALLOWED=NO` from
  apps/FretspaceVision. Keep derived data and build logs in the repo's
  gitignored `.derived-data/`; screenshots in `captures/`. Never write
  outside the working directory without asking the owner first.
- **Device deploys via AppleScript — ALWAYS stop before run.** If a
  previous debug session is still attached, `run` silently queues behind a
  "Replace 'FretspaceVision'?" sheet and the status reads "not yet
  started" forever (this shipped v1 three times while we thought v2/v3
  were live). Sequence:
  `tell application "Xcode" to stop workspace document "FretspaceVision.xcodeproj"`,
  delay 2, then `run ...`. If status stays "not yet started", inspect for
  sheets via System Events and click "Replace".
- **CI builds the real app**: the "visionOS app (simulator build)" job
  compiles the full app against the visionOS SDK on every push — it is the
  required gate. `swiftc -parse` locally is only a fast pre-flight.
- SwiftUI type-checker budget: keep view bodies small — one section per
  computed property/subview (the monolithic control-panel Form hit "unable
  to type-check this expression in reasonable time" on CI).
- Audio-thread code (ChromaExtractor) is deliberately not actor-isolated;
  keep its state immutable and let AsyncStream carry data out.
