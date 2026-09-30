import { buildApp, type AppOptions } from "./app";
import { config } from "./config";
import { makeDb } from "./db/client";
import { DrizzleTrackRepo } from "./tracks/drizzle-repo";
import { DrizzlePracticeRepo } from "./practice/drizzle-repo";

// Persistence: Drizzle/Postgres when DATABASE_URL is set, otherwise the
// seeded in-memory repos (buildApp's defaults).
let repos: Pick<AppOptions, "trackRepo" | "practiceRepo"> = {};
const persistence = config.databaseUrl ? "postgres (drizzle)" : "in-memory";
if (config.databaseUrl) {
  const db = makeDb(config.databaseUrl);
  repos = {
    trackRepo: new DrizzleTrackRepo(db),
    practiceRepo: new DrizzlePracticeRepo(db),
  };
}

const app = buildApp(repos);
app.log.info({ persistence }, "using %s persistence", persistence);

/** How long to wait for in-flight requests before forcing exit. */
const CLOSE_TIMEOUT_MS = 10_000;

let shuttingDown = false;

async function shutdown(signal: NodeJS.Signals): Promise<void> {
  if (shuttingDown) return;
  shuttingDown = true;

  app.log.info({ signal }, "received %s, shutting down gracefully", signal);

  const forceExit = setTimeout(() => {
    app.log.error(
      "close timed out after %dms, forcing exit",
      CLOSE_TIMEOUT_MS,
    );
    process.exit(1);
  }, CLOSE_TIMEOUT_MS);
  forceExit.unref();

  try {
    await app.close();
    app.log.info("server closed cleanly");
    process.exit(0);
  } catch (err) {
    app.log.error({ err }, "error during shutdown");
    process.exit(1);
  }
}

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.once(signal, () => void shutdown(signal));
}

app
  .listen({ port: config.port, host: config.host })
  .then((address) => {
    app.log.info(
      { env: config.nodeEnv, version: config.version },
      "Fretspace API listening at %s",
      address,
    );
  })
  .catch((err) => {
    app.log.error({ err }, "failed to start server");
    process.exit(1);
  });
