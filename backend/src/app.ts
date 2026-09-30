import Fastify, { type FastifyInstance } from "fastify";
import { createInMemoryTrackRepo, type TrackRepo } from "./tracks/repo";
import { tracksRoutes } from "./tracks/routes";

export interface AppOptions {
  /** Tracks repository. Defaults to the seeded in-memory implementation. */
  trackRepo?: TrackRepo;
}

export function buildApp(opts: AppOptions = {}): FastifyInstance {
  const app = Fastify({ logger: false });
  const trackRepo = opts.trackRepo ?? createInMemoryTrackRepo();

  app.get("/health", async () => ({ status: "ok" }));

  app.register(
    async (v1) => {
      await v1.register(tracksRoutes, { repo: trackRepo });
    },
    { prefix: "/v1" },
  );

  return app;
}
