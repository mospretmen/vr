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
npm run db:generate  # generate SQL migrations from src/db/schema.ts into ./drizzle
npm run db:migrate   # apply pending migrations to DATABASE_URL
npm run db:push      # push schema directly (dev shortcut; prefer db:migrate)
npm run db:seed      # insert the 4 starter tracks + chord timelines
```

## Database setup (Neon Postgres)

The API runs with an in-memory store by default; set `DATABASE_URL` to switch to Postgres (the choice is logged at startup as `using postgres (drizzle) persistence` / `using in-memory persistence`).

1. **Create a database** — sign in at [neon.tech](https://neon.tech), create a project, and copy the connection string (looks like `postgresql://USER:PASSWORD@ep-xxx.region.aws.neon.tech/dbname?sslmode=require`). Any Postgres works too (e.g. local Docker) — the driver is plain node-postgres.
2. **Set `DATABASE_URL`** — copy `.env.example` to `.env` and paste the connection string (or export it in your shell; `npm run dev` reads the environment, not `.env`, unless you load it e.g. via `node --env-file` or `dotenv`).
3. **Migrate** — `npm run db:migrate` applies the committed SQL migrations in `./drizzle`.
4. **Seed** — `npm run db:seed` inserts the same 4 starter tracks/timelines the in-memory repo serves (12-bar blues in A/E/G, ii–V–I in C). Idempotent; safe to re-run.
5. **Run** — `DATABASE_URL=... npm run dev`.

After changing `src/db/schema.ts`, run `npm run db:generate` and commit the new files under `./drizzle`.

Driver note: connections use `pg` (node-postgres) via `drizzle-orm/node-postgres` (`src/db/client.ts`). For edge/serverless runtimes, `@neondatabase/serverless` with `drizzle-orm/neon-serverless` is a documented drop-in swap.

## Environment variables

All are optional with sane defaults; parsed in `src/config.ts` into a single typed `config` export.

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `3000` | TCP port to listen on (validated; startup fails on garbage). |
| `HOST` | `0.0.0.0` | Bind address. |
| `NODE_ENV` | `development` | `production` switches to plain JSON logs and hides 5xx details; `test` silences logging. |
| `LOG_LEVEL` | `info` | Pino log level. |
| `CORS_ORIGIN` | localhost dev origins | Comma-separated allowed origins (`*` allows any). |
| `DATABASE_URL` | unset | Neon Postgres connection string. When set, the API persists to Postgres via Drizzle; when unset, it uses the seeded in-memory repos. Also used by `drizzle-kit` (`db:migrate`, `db:push`) and `db:seed`. |

## Routes

- `GET /health` (alias `GET /healthz`) → `{ "status": "ok", "uptime": <seconds>, "version": "<package.json version>" }`
- `GET /v1/tracks` → `Track[]` — seeded backing tracks (12-bar blues in A, E, G at 120 bpm; ii–V–I in C). `Track: { id, title, artist, bpm, key }` where `key` is `{ root, type: { name, intervals } } | null` and `root` is a pitch class 0–11 (C = 0).
- `GET /v1/tracks/:id/timeline` → `{ events, key }` — chord timeline for a track. Each event is `{ startMs, durationMs, chord: { root, quality: { name, symbol, intervals } } }`. Unknown ids return `404 { "error": "not_found" }`. `:id` is validated (`^[A-Za-z0-9_-]+$`, max 64 chars); invalid ids return `400`.
- `POST /v1/practice-sessions` → `{ "accepted": <count> }` — batch sync of practice sessions (max 500 per batch). Body is `{ sessions: [{ id, startedAt, durationS, mode }] }` where `id` is a client-generated UUID (idempotency key: upserts by id, so retries are safe), `startedAt` is ISO 8601, and `mode` is one of `scale | chord | chordInScale | exercise | backingTrack | listen`. Requires an `x-device-id` header (UUID; the pre-auth stand-in for a user id) — missing/malformed header, an unknown `mode`, or a batch over 500 return `400`.
- `GET /v1/practice-sessions/summary` → `{ totalTimeS, sessionCount, timeByMode, days }` — per-device practice summary. Requires the same `x-device-id` header. `timeByMode` maps each practiced mode to seconds; `days` is the sorted unique list of `YYYY-MM-DD` dates (UTC) with practice, for client-side streak rendering.

All `/v1` routes declare JSON request/response schemas (fast serialization + wire-contract enforcement against the Swift Codable models).

Both stores implement the `TrackRepo` / `PracticeRepo` interfaces (`src/tracks/repo.ts`, `src/practice/repo.ts`). Without `DATABASE_URL` the seeded in-memory implementations serve requests; with it, the Drizzle/Postgres implementations (`src/tracks/drizzle-repo.ts`, `src/practice/drizzle-repo.ts`) do. Practice sessions are stored per `device_id` (the `x-device-id` header); `practice_sessions.user_id` is nullable until auth lands, at which point each device-id maps onto a user.

## Ops behavior

- **Logging** — Fastify's built-in pino logger: pretty-printed via `pino-pretty` in dev, single-line JSON in production. Every request-scoped line carries a `reqId` (UUID, or an upstream `X-Request-Id` if provided). `Authorization` headers are redacted. Startup and shutdown are logged.
- **Errors** — a central `setErrorHandler` logs the error with request context and responds with `{ "error": string, "statusCode": number }`. In production, 5xx responses never expose internal messages or stacks (`"internal_server_error"`). Unknown routes get `404 { "error": "not_found", "statusCode": 404 }`.
- **Security** — `@fastify/helmet` (security headers), `@fastify/cors` (origins from `CORS_ORIGIN`), `@fastify/rate-limit` (300 requests/min per client, standard `x-ratelimit-*` headers).
- **Graceful shutdown** — `SIGINT`/`SIGTERM` trigger `fastify.close()` (in-flight requests drain); if closing takes longer than 10s the process force-exits with code 1.
