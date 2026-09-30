# Fretspace Backend

Fastify + TypeScript API for Fretspace, the visionOS guitar-practice app. Serves backing tracks and their chord timelines (which drive the in-headset fretboard overlay), plus practice-session data.

## Stack

- Fastify 5 (TypeScript, ESM), run with `tsx`
- Drizzle ORM targeting **Neon Postgres** (`DATABASE_URL`)
- Vitest for tests

## Dev commands

```sh
npm install
npm run dev        # start API with watch mode (http://localhost:3000)
npm test           # vitest
npm run typecheck  # tsc --noEmit
npm run db:generate  # generate SQL migrations from src/db/schema.ts
npm run db:push      # push schema to the database
```

Copy `.env.example` to `.env` and set `DATABASE_URL` to your Neon connection string before running Drizzle commands.

## Routes

- `GET /health` → `{ "status": "ok" }`
- `GET /v1/tracks` → `Track[]` — seeded backing tracks (12-bar blues in A, E, G at 120 bpm; ii–V–I in C). `Track: { id, title, artist, bpm, key }` where `key` is `{ root, type: { name, intervals } } | null` and `root` is a pitch class 0–11 (C = 0).
- `GET /v1/tracks/:id/timeline` → `{ events, key }` — chord timeline for a track. Each event is `{ startMs, durationMs, chord: { root, quality: { name, symbol, intervals } } }`. Unknown ids return `404 { "error": "not_found" }`.

Tracks are currently served from a seeded in-memory repository (`src/tracks/repo.ts`); the `TrackRepo` interface is the seam for a future Drizzle/Neon implementation.
