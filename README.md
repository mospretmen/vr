# Fretspace

**See the fretboard. In the room.**

Fretspace is a mixed-reality guitar practice app for Apple Vision Pro. A
30-second pinch calibration locks a luminous overlay onto your *real*
guitar's fretboard — any guitar or bass, right- or left-handed — and from
then on the neck itself teaches you:

- **Scales & modes** — every scale type across the full neck or one
  position box at a time, with spelled degrees (♭3, ♭7…) and mode context
  ("A Dorian · 2nd mode of G major")
- **Triads & inversions** — all three inversions on any string set as
  connected shapes; drop-2 seventh voicings on four-string sets; the
  harmonized scale ladder (I–ii–iii…) climbing the neck
- **Exercises** — scale runs, 3-notes-per-string patterns, voicing
  drills; with listen mode on, playing the target note advances the step
- **Backing progressions** — the overlay follows chord timelines
  (12-bar blues, ii–V–I, pop loops…) with pre-announced changes, chart
  panel, and metronome
- **Listen mode** — on-device chord recognition drives the display and a
  chord-colored aura from the guitar
- **Practice stats** — per-mode time, day streaks, anonymous sync

## Monorepo

| Path | What | Verified by |
|---|---|---|
| `packages/GuitarCore` | Music theory, fretboard geometry, calibration solver, audio analysis — pure Swift, no UI | 94 Swift tests |
| `apps/FretspaceVision` | The Vision Pro app (SwiftUI · RealityKit · ARKit) | syntax-gated in CI; builds with Xcode 27 + visionOS SDK |
| `backend` | Fastify API — track library, chord timelines, practice sync (Drizzle/Neon, in-memory dev mode) | 28 tests |
| `web` | Product site + companion (React · Vite · Tailwind v4) with an interactive fretboard explorer sharing the same theory engine | 56 tests |
| `docs` | ROADMAP · TESTING (Vision Pro setup) · APP_STORE | — |

## Quick start

```sh
# Core engine (Command Line Tools are enough)
swift test --package-path packages/GuitarCore

# Vision Pro app (Xcode 27+, see docs/TESTING.md for device setup)
brew install xcodegen
cd apps/FretspaceVision && xcodegen generate && open FretspaceVision.xcodeproj

# Backend API (in-memory without DATABASE_URL; Neon Postgres with it)
cd backend && npm install && npm run dev

# Web (dev proxy expects the backend on :3000)
cd web && npm install && npm run dev
```

## How guitar targeting works

Pinch once at the **nut**, once at the **12th fret**. The 12th fret is
exactly half the scale length, so those two points recover the
instrument's true scale length and orientation — no per-model scanning.
The calibration persists as an ARKit world anchor, so next session the
overlay is already on your guitar.

Architecture conventions live in `CLAUDE.md`; the phase plan in
`docs/ROADMAP.md`.
