import type { FastifyInstance } from "fastify";
import {
  PRACTICE_MODES,
  type PracticeRepo,
  type PracticeSession,
} from "./repo";

// --- JSON schemas (validation + fast serialization + contract enforcement) ---
// These mirror the wire types in repo.ts, which in turn mirror the Swift
// Codable models. `additionalProperties: false` means the serializer strips
// anything that drifts outside the contract.

const UUID_PATTERN =
  "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$";

// Pre-auth device identity: required, must be a UUID. Missing or malformed
// values fail header validation → 400. (No `additionalProperties: false`
// here — requests carry arbitrary other headers.)
const deviceIdHeadersSchema = {
  type: "object",
  properties: {
    "x-device-id": { type: "string", pattern: UUID_PATTERN },
  },
  required: ["x-device-id"],
} as const;

// The device identity is taken from the x-device-id header; a `deviceId` in
// the body is accepted (the client's stored model includes it) but the
// header value is authoritative.
const sessionSchema = {
  type: "object",
  properties: {
    id: { type: "string", pattern: UUID_PATTERN },
    deviceId: { type: "string", pattern: UUID_PATTERN },
    startedAt: { type: "string", format: "date-time" },
    durationS: { type: "number", minimum: 0 },
    mode: { type: "string", enum: PRACTICE_MODES },
  },
  required: ["id", "startedAt", "durationS", "mode"],
  additionalProperties: false,
} as const;

const postSessionsBodySchema = {
  type: "object",
  properties: {
    sessions: {
      type: "array",
      items: sessionSchema,
      maxItems: 500,
    },
  },
  required: ["sessions"],
  additionalProperties: false,
} as const;

const acceptedSchema = {
  type: "object",
  properties: {
    accepted: { type: "integer" },
  },
  required: ["accepted"],
  additionalProperties: false,
} as const;

const summarySchema = {
  type: "object",
  properties: {
    totalTimeS: { type: "number" },
    sessionCount: { type: "integer" },
    timeByMode: {
      type: "object",
      properties: {
        scale: { type: "number" },
        chord: { type: "number" },
        chordInScale: { type: "number" },
        exercise: { type: "number" },
        backingTrack: { type: "number" },
        listen: { type: "number" },
      },
      additionalProperties: false,
    },
    days: {
      type: "array",
      items: { type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$" },
    },
  },
  required: ["totalTimeS", "sessionCount", "timeByMode", "days"],
  additionalProperties: false,
} as const;

// --- Route types ---

interface DeviceIdHeaders {
  "x-device-id": string;
}

/** Session as posted by the client: deviceId optional (header wins). */
type IncomingSession = Omit<PracticeSession, "deviceId"> & {
  deviceId?: string;
};

export async function practiceRoutes(
  app: FastifyInstance,
  opts: { repo: PracticeRepo },
): Promise<void> {
  const { repo } = opts;

  app.post<{ Body: { sessions: IncomingSession[] }; Headers: DeviceIdHeaders }>(
    "/practice-sessions",
    {
      schema: {
        headers: deviceIdHeadersSchema,
        body: postSessionsBodySchema,
        response: { 200: acceptedSchema },
      },
    },
    async (req) => {
      const deviceId = req.headers["x-device-id"];
      const sessions: PracticeSession[] = req.body.sessions.map((s) => ({
        id: s.id,
        deviceId,
        startedAt: s.startedAt,
        durationS: s.durationS,
        mode: s.mode,
      }));
      const accepted = await repo.upsertSessions(sessions);
      return { accepted };
    },
  );

  app.get<{ Headers: DeviceIdHeaders }>(
    "/practice-sessions/summary",
    {
      schema: {
        headers: deviceIdHeadersSchema,
        response: { 200: summarySchema },
      },
    },
    async (req) => repo.getSummary(req.headers["x-device-id"]),
  );
}
