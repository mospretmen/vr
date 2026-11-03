// Short device-setup link: /go?p=<pin> 302-redirects to the full
// songbook one-tap URL with the key filled in server-side. The pin is
// the key's last four characters — enough to stop drive-by visits on a
// personal site without making the URL untypable.
export default (req: Request) => {
  const key = process.env.SONGBOOK_KEY ?? "";
  const url = new URL(req.url);
  // Pin in the PATH (/go/XXXX) — typed query strings get stripped by
  // mobile address bars; a plain path survives. ?p= still accepted.
  const pin = url.pathname.split("/").filter(Boolean).pop() === "go"
    ? url.searchParams.get("p")
    : url.pathname.split("/").filter(Boolean).pop();
  if (!key || pin !== key.slice(-4)) {
    return new Response("not found", { status: 404 });
  }
  const lib = encodeURIComponent("https://vr-music-app.netlify.app/book?f=");
  const dest = `/#/songbook/setup?lib=${lib}&key=${key}`;
  // Not an HTTP redirect: iOS WebKit drops URL fragments across 302s,
  // and the whole device config rides in the fragment. A client-side
  // location.replace carries it intact on every browser.
  const html = `<!doctype html><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fretspace setup</title>
<body style="background:#09090b;color:#a1a1aa;font-family:system-ui;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
<p>Setting up your songbook…</p>
<script>location.replace(${JSON.stringify(dest)});</script>
</body>`;
  // The key also rides in a year-long HttpOnly cookie: /book accepts it,
  // so the device stays authorized even when the browser purges
  // localStorage (iOS does). The fragment setup remains as a fallback.
  return new Response(html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "set-cookie":
        `sbk=${encodeURIComponent(key)}; Path=/; Max-Age=31536000; Secure; HttpOnly; SameSite=Lax`,
    },
  });
};

export const config = { path: ["/go", "/go/:pin"] };
