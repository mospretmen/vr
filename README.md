# Fretspace

**See the fretboard. In the room.**

Fretspace is a mixed-reality guitar practice app for Apple Vision Pro. It
locks scale, chord, and arpeggio overlays onto your *real* guitar's fretboard,
shows a floating chart panel beside you, and (in later phases) listens to what
you play — lighting up the room with chord-colored effects and following
backing tracks chord by chord.

## Monorepo

| Path | What | Stack |
|---|---|---|
| `packages/GuitarCore` | Music theory + fretboard geometry/calibration engine | Swift package (no UI, tested) |
| `apps/FretspaceVision` | The Vision Pro app | SwiftUI · RealityKit · ARKit |
| `backend` | API: tracks, chord timelines, accounts, stats | Node · Fastify · Drizzle · Neon |
| `web` | Companion dashboard / landing | React · Vite · Tailwind |
| `docs` | Roadmap & design docs | — |

## Quick start

```sh
# Core engine (works with Command Line Tools alone)
cd packages/GuitarCore && swift test

# Vision Pro app (requires Xcode 16+ with visionOS SDK)
brew install xcodegen
cd apps/FretspaceVision && xcodegen generate
open FretspaceVision.xcodeproj   # build to Vision Pro / simulator

# Backend
cd backend && npm install && npm run dev

# Web companion
cd web && npm install && npm run dev
```

## How guitar targeting works (v1)

1. Start a session (mixed immersion) and tap **Calibrate to My Guitar**.
2. Pinch once at the center of the **nut**, once at the center of the
   **12th fret**.
3. The 12th fret is exactly half the scale length, so those two points
   recover your instrument's true scale length and orientation — the overlay
   fits any guitar or bass, no per-model 3D scanning required.

See `docs/ROADMAP.md` for the phase plan and `CLAUDE.md` for architecture
conventions.
