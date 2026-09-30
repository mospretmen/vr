import type { FastifyInstance } from "fastify";
import type { TrackRepo } from "./repo";

// --- JSON schemas (validation + fast serialization + contract enforcement) ---
// These mirror the wire types in repo.ts, which in turn mirror the Swift
// Codable models. `additionalProperties: false` means the serializer strips
// anything that drifts outside the contract.

const chordQualitySchema = {
  type: "object",
  properties: {
    name: { type: "string" },
    symbol: { type: "string" },
    intervals: { type: "array", items: { type: "integer" } },
  },
  required: ["name", "symbol", "intervals"],
  additionalProperties: false,
} as const;

const chordSchema = {
  type: "object",
  properties: {
    root: { type: "integer", minimum: 0, maximum: 11 },
    quality: chordQualitySchema,
  },
  required: ["root", "quality"],
  additionalProperties: false,
} as const;

const scaleTypeSchema = {
  type: "object",
  properties: {
    name: { type: "string" },
    intervals: { type: "array", items: { type: "integer" } },
  },
  required: ["name", "intervals"],
  additionalProperties: false,
} as const;

const keySchema = {
  type: ["object", "null"],
  properties: {
    root: { type: "integer", minimum: 0, maximum: 11 },
    type: scaleTypeSchema,
  },
  required: ["root", "type"],
  additionalProperties: false,
} as const;

const trackSchema = {
  type: "object",
  properties: {
    id: { type: "string" },
    title: { type: "string" },
    artist: { type: ["string", "null"] },
    bpm: { type: "number" },
    key: keySchema,
  },
  required: ["id", "title", "artist", "bpm", "key"],
  additionalProperties: false,
} as const;

const timelineEventSchema = {
  type: "object",
  properties: {
    startMs: { type: "number" },
    durationMs: { type: "number" },
    chord: chordSchema,
  },
  required: ["startMs", "durationMs", "chord"],
  additionalProperties: false,
} as const;

const timelineSchema = {
  type: "object",
  properties: {
    events: { type: "array", items: timelineEventSchema },
    key: keySchema,
  },
  required: ["events", "key"],
  additionalProperties: false,
} as const;

const trackIdParamsSchema = {
  type: "object",
  properties: {
    id: {
      type: "string",
      minLength: 1,
      maxLength: 64,
      pattern: "^[A-Za-z0-9_-]+$",
    },
  },
  required: ["id"],
  additionalProperties: false,
} as const;

const timelineNotFoundSchema = {
  type: "object",
  properties: { error: { type: "string" } },
  required: ["error"],
  additionalProperties: false,
} as const;

export async function tracksRoutes(
  app: FastifyInstance,
  opts: { repo: TrackRepo },
): Promise<void> {
  const { repo } = opts;

  app.get(
    "/tracks",
    {
      schema: {
        response: { 200: { type: "array", items: trackSchema } },
      },
    },
    async () => repo.listTracks(),
  );

  app.get<{ Params: { id: string } }>(
    "/tracks/:id/timeline",
    {
      schema: {
        params: trackIdParamsSchema,
        response: { 200: timelineSchema, 404: timelineNotFoundSchema },
      },
    },
    async (req, reply) => {
      const timeline = await repo.getTimeline(req.params.id);
      if (!timeline) {
        return reply.code(404).send({ error: "not_found" });
      }
      return timeline;
    },
  );
}
