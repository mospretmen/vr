import { randomUUID } from "node:crypto";
import Fastify, {
  type FastifyError,
  type FastifyInstance,
  type FastifyServerOptions,
} from "fastify";
import helmet from "@fastify/helmet";
import cors from "@fastify/cors";
import rateLimit from "@fastify/rate-limit";
import { config as defaultConfig, type Config } from "./config";
import { createInMemoryTrackRepo, type TrackRepo } from "./tracks/repo";
import { tracksRoutes } from "./tracks/routes";

export interface AppOptions {
  /** Tracks repository. Defaults to the seeded in-memory implementation. */
  trackRepo?: TrackRepo;
  /** Config to run with. Defaults to the env-derived singleton. */
  config?: Config;
  /** Logger override (e.g. `false` in tests). Defaults to env-appropriate pino settings. */
  logger?: FastifyServerOptions["logger"];
}

/**
 * Env-appropriate pino settings: silent under test, pretty-printed in dev,
 * plain JSON to stdout in production. Authorization headers are redacted.
 */
function loggerOptions(cfg: Config): FastifyServerOptions["logger"] {
  if (cfg.nodeEnv === "test") return false;

  const base = {
    level: cfg.logLevel,
    redact: {
      paths: ["req.headers.authorization", "headers.authorization"],
      censor: "[REDACTED]",
    },
  };

  if (cfg.isProduction) return base;

  return {
    ...base,
    transport: {
      target: "pino-pretty",
      options: { translateTime: "SYS:HH:MM:ss.l", ignore: "pid,hostname" },
    },
  };
}

const healthSchema = {
  response: {
    200: {
      type: "object",
      properties: {
        status: { type: "string" },
        uptime: { type: "number" },
        version: { type: "string" },
      },
      required: ["status", "uptime", "version"],
      additionalProperties: false,
    },
  },
} as const;

export function buildApp(opts: AppOptions = {}): FastifyInstance {
  const cfg = opts.config ?? defaultConfig;
  const trackRepo = opts.trackRepo ?? createInMemoryTrackRepo();

  const app = Fastify({
    logger: opts.logger ?? loggerOptions(cfg),
    // Honor an upstream X-Request-Id, otherwise generate a UUID. The id is
    // attached as `reqId` to every request-scoped log line.
    requestIdHeader: "x-request-id",
    genReqId: () => randomUUID(),
  });

  // --- Security / ops middleware ----------------------------------------
  app.register(helmet);
  app.register(cors, {
    origin: cfg.corsOrigins.includes("*") ? true : cfg.corsOrigins,
  });
  app.register(rateLimit, { max: 300, timeWindow: "1 minute" });

  // --- Centralized error handling ----------------------------------------
  app.setErrorHandler((err: FastifyError, req, reply) => {
    const statusCode =
      typeof err.statusCode === "number" &&
      err.statusCode >= 400 &&
      err.statusCode <= 599
        ? err.statusCode
        : 500;

    const logContext = { err, method: req.method, url: req.url, statusCode };
    if (statusCode >= 500) {
      req.log.error(logContext, "request errored");
    } else {
      req.log.warn(logContext, "request failed");
    }

    // Never leak internals (messages, stacks) for 5xx in production.
    const error =
      statusCode >= 500 && cfg.isProduction
        ? "internal_server_error"
        : err.message || "internal_server_error";

    return reply.code(statusCode).send({ error, statusCode });
  });

  app.setNotFoundHandler((req, reply) => {
    req.log.info({ method: req.method, url: req.url }, "route not found");
    return reply.code(404).send({ error: "not_found", statusCode: 404 });
  });

  // --- Routes --------------------------------------------------------------
  const healthHandler = async () => ({
    status: "ok",
    uptime: process.uptime(),
    version: cfg.version,
  });
  app.get("/health", { schema: healthSchema }, healthHandler);
  app.get("/healthz", { schema: healthSchema }, healthHandler);

  app.register(
    async (v1) => {
      await v1.register(tracksRoutes, { repo: trackRepo });
    },
    { prefix: "/v1" },
  );

  return app;
}
