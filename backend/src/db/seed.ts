// Seed script: `npm run db:seed`.
//
// Inserts the same 4 starter tracks/timelines the in-memory repo serves
// (12-bar blues in A, E, G at 120 bpm; ii–V–I in C). Idempotent: tracks are
// upserted by id and their chord timelines replaced, so re-running is safe.
//
// Requires DATABASE_URL and an already-migrated schema (`npm run db:migrate`).

import { makeDb } from "./client";
import { seedTracks } from "../tracks/repo";
import { upsertSeededTrack } from "../tracks/drizzle-repo";

async function main(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.error("db:seed requires DATABASE_URL to be set");
    process.exit(1);
  }

  const db = makeDb(databaseUrl);
  try {
    const seeds = seedTracks();
    for (const seeded of seeds) {
      await upsertSeededTrack(db, seeded);
      console.log(
        `seeded ${seeded.track.id} (${seeded.timeline.events.length} chord events)`,
      );
    }
    console.log(`done: ${seeds.length} tracks`);
  } finally {
    await db.$client.end();
  }
}

main().catch((err) => {
  console.error("db:seed failed:", err);
  process.exit(1);
});
