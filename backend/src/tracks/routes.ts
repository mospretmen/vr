import type { FastifyInstance } from "fastify";
import type { TrackRepo } from "./repo";

export async function tracksRoutes(
  app: FastifyInstance,
  opts: { repo: TrackRepo },
): Promise<void> {
  const { repo } = opts;

  app.get("/tracks", async () => repo.listTracks());

  app.get<{ Params: { id: string } }>(
    "/tracks/:id/timeline",
    async (req, reply) => {
      const timeline = await repo.getTimeline(req.params.id);
      if (!timeline) {
        return reply.code(404).send({ error: "not_found" });
      }
      return timeline;
    },
  );
}
