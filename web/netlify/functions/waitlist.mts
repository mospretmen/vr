// Waitlist signup — stores an email + preferred platform in Neon.
// DATABASE_URL must be set in the Netlify environment (never in git).
import { neon } from "@neondatabase/serverless";

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const PLATFORMS = new Set(["visionpro", "ios", "web", "any"]);

export default async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const url = process.env.DATABASE_URL;
  if (!url) return Response.json({ error: "not configured" }, { status: 503 });

  let body: { email?: string; platform?: string };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "bad request" }, { status: 400 });
  }
  const email = body.email?.trim().toLowerCase() ?? "";
  const platform = PLATFORMS.has(body.platform ?? "") ? body.platform! : "any";
  if (!EMAIL.test(email) || email.length > 254) {
    return Response.json({ error: "invalid email" }, { status: 422 });
  }

  const sql = neon(url);
  await sql`
    INSERT INTO waitlist (email, platform) VALUES (${email}, ${platform})
    ON CONFLICT (email) DO UPDATE SET platform = ${platform}`;
  return Response.json({ ok: true });
};
