// Short device-setup link: /go?p=<pin> 302-redirects to the full
// songbook one-tap URL with the key filled in server-side. The pin is
// the key's last four characters — enough to stop drive-by visits on a
// personal site without making the URL untypable.
export default (req: Request) => {
  const key = process.env.SONGBOOK_KEY ?? "";
  const pin = new URL(req.url).searchParams.get("p");
  if (!key || pin !== key.slice(-4)) {
    return new Response("not found", { status: 404 });
  }
  const lib = encodeURIComponent("https://vr-music-app.netlify.app/book?f=");
  return Response.redirect(
    `https://vr-music-app.netlify.app/#/songbook/admin?lib=${lib}&key=${key}`, 302);
};

export const config = { path: "/go" };
