// Postgres client factory for the Drizzle-backed repos.
//
// Driver choice: node-postgres (`pg`) over `@neondatabase/serverless`.
// `pg` works against any Postgres — Neon over TCP, local Docker, CI — which
// keeps local dev friction-free. Neon's serverless driver is a drop-in swap
// for edge/serverless runtimes where TCP is unavailable:
//
//   import { drizzle } from "drizzle-orm/neon-serverless";
//   import { Pool } from "@neondatabase/serverless";
//   const db = drizzle(new Pool({ connectionString: databaseUrl }), { schema });
//
// The pool is lazy: `new pg.Pool(...)` opens no connections; the first query
// does. So `makeDb` is safe to call at startup even before the database is
// reachable.

import { drizzle, type NodePgDatabase } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "./schema";

export type Db = NodePgDatabase<typeof schema> & { $client: pg.Pool };

export function makeDb(databaseUrl: string): Db {
  const pool = new pg.Pool({ connectionString: databaseUrl });
  return drizzle(pool, { schema });
}
