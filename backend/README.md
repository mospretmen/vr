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

## Environment variables

All are optional with sane defaults; parsed in `src/config.ts` into a single typed `config` export.

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `3000` | TCP port to listen on (validated; startup fails on garbage). |
| `HOST` | `0.0.0.0` | Bind address. |
| `NODE_ENV` | `development` | `production` switches to plain JSON logs and hides 5xx details; `test` silences logging. |
| `LOG_LEVEL` | `info` | Pino log level. |
| `CORS_ORIGIN` | localhost dev origins | Comma-separated allowed origins (`*` allows any). |
| `DATABASE_URL` | unset | Neon Postgres connection string; only needed for `drizzle-kit` commands today. |

## Routes

- `GET /health` (alias `GET /healthz`) → `{ "status": "ok", "uptime": <seconds>, "version": "<package.json version>" }`
- `GET /v1/tracks` → `Track[]` — seeded backing tracks (12-bar blues in A, E, G at 120 bpm; ii–V–I in C). `Track: { id, title, artist, bpm, key }` where `key` is `{ root, type: { name, intervals } } | null` and `root` is a pitch class 0–11 (C = 0).
- `GET /v1/tracks/:id/timeline` → `{ events, key }` — chord timeline for a track. Each event is `{ startMs, durationMs, chord: { root, quality: { name, symbol, intervals } } }`. Unknown ids return `404 { "error": "not_found" }`. `:id` is validated (`^[A-Za-z0-9_-]+$`, max 64 chars); invalid ids return `400`.

Both `/v1` routes declare JSON response schemas (fast serialization + wire-contract enforcement against the Swift Codable models).

Tracks are currently served from a seeded in-memory repository (`src/tracks/repo.ts`); the `TrackRepo` interface is the seam for a future Drizzle/Neon implementation.

## Ops behavior

- **Logging** — Fastify's built-in pino logger: pretty-printed via `pino-pretty` in dev, single-line JSON in production. Every request-scoped line carries a `reqId` (UUID, or an upstream `X-Request-Id` if provided). `Authorization` headers are redacted. Startup and shutdown are logged.
- **Errors** — a central `setErrorHandler` logs the error with request context and responds with `{ "error": string, "statusCode": number }`. In production, 5xx responses never expose internal messages or stacks (`"internal_server_error"`). Unknown routes get `404 { "error": "not_found", "statusCode": 404 }`.
- **Security** — `@fastify/helmet` (security headers), `@fastify/cors` (origins from `CORS_ORIGIN`), `@fastify/rate-limit` (300 requests/min per client, standard `x-ratelimit-*` headers).
- **Graceful shutdown** — `SIGINT`/`SIGTERM` trigger `fastify.close()` (in-flight requests drain); if closing takes longer than 10s the process force-exits with code 1.
