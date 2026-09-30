import { readFileSync } from "node:fs";

export interface Config {
  /** NODE_ENV, defaults to "development". */
  nodeEnv: string;
  isProduction: boolean;
  /** TCP port to listen on (PORT, default 3000). */
  port: number;
  /** Bind address (HOST, default 0.0.0.0). */
  host: string;
  /** Pino log level (LOG_LEVEL, default "info"). */
  logLevel: string;
  /** Allowed CORS origins (CORS_ORIGIN, comma-separated). */
  corsOrigins: string[];
  /** Neon Postgres connection string (DATABASE_URL). When set, the server uses Drizzle/Postgres repos; otherwise in-memory. */
  databaseUrl: string | undefined;
  /** Version from package.json, surfaced in the health payload. */
  version: string;
}

/** Dev origins allowed when CORS_ORIGIN is not set. */
const DEFAULT_CORS_ORIGINS = [
  "http://localhost:3000",
  "http://localhost:5173",
  "http://127.0.0.1:5173",
];

function readPackageVersion(): string {
  try {
    const raw = readFileSync(new URL("../package.json", import.meta.url), "utf8");
    return (JSON.parse(raw) as { version?: string }).version ?? "0.0.0";
  } catch {
    return "0.0.0";
  }
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const nodeEnv = env.NODE_ENV ?? "development";

  const port = Number(env.PORT ?? 3000);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error(`Invalid PORT: ${JSON.stringify(env.PORT)}`);
  }

  const corsOrigins = env.CORS_ORIGIN
    ? env.CORS_ORIGIN.split(",").map((o) => o.trim()).filter(Boolean)
    : DEFAULT_CORS_ORIGINS;

  return {
    nodeEnv,
    isProduction: nodeEnv === "production",
    port,
    host: env.HOST ?? "0.0.0.0",
    logLevel: env.LOG_LEVEL ?? "info",
    corsOrigins,
    databaseUrl: env.DATABASE_URL,
    version: readPackageVersion(),
  };
}

/** Config loaded from the real process environment. */
export const config = loadConfig();
