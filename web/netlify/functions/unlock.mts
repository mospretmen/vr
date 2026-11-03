// In-page unlock: the songbook UI posts the owner's PIN (the key's last
// four characters) and gets the key back, plus a year-long cookie that
// /book also accepts. Recovery is self-evident — see the lock, type the
// PIN — instead of hunting for a setup link.
export default (req: Request) => {
  const key = process.env.SONGBOOK_KEY ?? "";
  const url = new URL(req.url);
  const pin = (url.searchParams.get("p") ?? "").trim();
  if (!key || pin !== key.slice(-4)) {
    return new Response("forbidden", { status: 403 });
  }
  return new Response(JSON.stringify({ key }), {
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
      "set-cookie":
        `sbk=${encodeURIComponent(key)}; Path=/; Max-Age=31536000; Secure; HttpOnly; SameSite=Lax`,
    },
  });
};

export const config = { path: "/unlock" };
