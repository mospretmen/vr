# App Store Submission — Working Draft

Working title "Fretspace" — check name availability in App Store Connect
before attachment forms (fallbacks: "Fretspace VR", "Fretspace Guitar").

## Positioning

**Subtitle (30 chars):** `See scales on your real guitar`

**Promo text (170 chars):**
> Put on Vision Pro, pick up your guitar, and see scales, chords, and
> exercises glowing on your actual fretboard. Practice with backing tracks
> that light the way.

**Description draft:**
> Fretspace turns your real guitar into an interactive instrument. A
> 30-second calibration locks a fretboard overlay onto your own neck — any
> guitar or bass, right- or left-handed — and from then on scales, chords,
> triads, and exercise patterns appear exactly where your fingers go.
>
> - Every scale, mode, and pentatonic box, on your strings
> - Triad and 3-notes-per-string drills that step as you play
> - Backing progressions with chord-by-chord overlay sync
> - A floating chart panel that mirrors the neck
> - Practice streaks and time tracking
>
> No cameras pointed at you, no account required, nothing tracked.

**Keywords (100 chars):**
`guitar,fretboard,scales,chords,practice,lessons,music theory,backing
tracks,bass,trainer`

**Category:** Music (primary), Education (secondary).

## Review checklist

- [ ] Usage strings present (already in project.yml): hands tracking, mic
- [ ] PrivacyInfo.xcprivacy accurate (done: no tracking, UserDefaults
      CA92.1, anonymous usage data) — re-audit before each submission
- [ ] App Privacy questionnaire in ASC must match the manifest: "Data Not
      Linked to You → Usage Data" only (device-UUID practice sync)
- [ ] Mic permission must be requested in-context (listen mode start), not
      at launch — already implemented
- [ ] Immersive-space apps: provide a clear exit affordance (End Session
      button — present) and test Digital Crown behavior
- [ ] Age rating 4+; no UGC, no web views
- [ ] Demo video for review notes: reviewers likely have no guitar —
      include a video showing calibration + overlay, and note that all
      screens are reachable without an instrument
- [ ] Screenshots: require device captures on visionOS (simulator captures
      not allowed for the required 2560×1440 Vision Pro shots) — plan a
      capture session on device

## Monetization (Phase 4 decision, capture thinking now)

Leading option: free core (scales/chords on your guitar, 5 starter
progressions) + "Fretspace Pro" subscription — full exercise library,
track packs, listen mode, stats sync. StoreKit 2, family-shareable.
Alternative: one-time purchase + track-pack IAPs. Decide after TestFlight
feedback on which features feel premium.

## Pre-launch infrastructure

- [ ] Deploy backend (Neon DB exists as target; API host TBD —
      fly.io/render/railway all fit the Fastify+pg shape)
- [ ] Point `TrackLibraryClient`/`PracticeSyncClient` baseURL at prod via
      build configuration (currently localhost defaults)
- [ ] TestFlight external group: guitar-playing testers with Vision Pro
