import { defineConfig } from "drizzle-kit";

export default defineConfig({
  dialect: "postgresql",
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dbCredentials: {
    // Neon Postgres connection string, see .env.example
    url: process.env.DATABASE_URL ?? "",
  },
});
