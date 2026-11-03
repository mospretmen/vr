// Serves the owner's songbook PDFs from Netlify Blobs, gated by a key.
// GET /.netlify/functions/book?f=<file name>  with Authorization: <key>
// (or &k=<key>). Streams, so big fake books pass through.
import { getStore } from "@netlify/blobs";

export default async (req: Request) => {
  const url = new URL(req.url);
  const file = url.searchParams.get("f");
  const key = req.headers.get("authorization") ?? url.searchParams.get("k");
  const expected = process.env.SONGBOOK_KEY;
  if (!expected || key !== expected) {
    return new Response("forbidden", { status: 403 });
  }
  if (!file) return new Response("missing f", { status: 400 });
  const store = getStore("songbooks");
  const body = await store.get(file, { type: "stream" });
  if (!body) return new Response("not found", { status: 404 });
  return new Response(body, {
    headers: {
      "content-type": "application/pdf",
      "cache-control": "private, max-age=3600",
    },
  });
};

export const config = { path: "/book" };
