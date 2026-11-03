// Serves the owner's songbook PDFs from Netlify Blobs, gated by a key.
// GET /.netlify/functions/book?f=<file name>  with Authorization: <key>,
// &k=<key>, or the sbk cookie set by /go. Streams, so big fake books
// pass through. ?probe=1 answers 204/403 so the app can show real state.
import { getStore } from "@netlify/blobs";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization",
};

function cookieKey(req: Request): string | null {
  const raw = req.headers.get("cookie");
  if (!raw) return null;
  for (const part of raw.split(";")) {
    const [name, ...rest] = part.trim().split("=");
    if (name === "sbk") return decodeURIComponent(rest.join("="));
  }
  return null;
}

export default async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  const url = new URL(req.url);
  const file = url.searchParams.get("f");
  const key = req.headers.get("authorization")
    ?? url.searchParams.get("k")
    ?? cookieKey(req);
  const expected = process.env.SONGBOOK_KEY;
  const authorized = Boolean(expected) && key === expected;
  if (url.searchParams.has("probe")) {
    return new Response(null, { status: authorized ? 204 : 403, headers: CORS });
  }
  if (!authorized) {
    return new Response("forbidden", { status: 403, headers: CORS });
  }
  if (!file) return new Response("missing f", { status: 400 });
  const store = getStore("songbooks");
  const body = await store.get(file, { type: "stream" });
  if (!body) return new Response("not found", { status: 404 });
  return new Response(body, {
    headers: {
      ...CORS,
      "content-type": "application/pdf",
      "cache-control": "private, max-age=3600",
    },
  });
};

export const config = { path: "/book" };
