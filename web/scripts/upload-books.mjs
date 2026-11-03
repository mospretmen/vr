// Uploads the owner's songbook PDFs into the site's Netlify Blobs store.
// Needs NETLIFY_AUTH_TOKEN + SITE_ID env (read from netlify CLI config).
import { getStore } from "@netlify/blobs";
import fs from "fs";
import os from "os";
import path from "path";

const FILES = [
  "REALBK1.PDF", "REALBK2.PDF", "REALBK3.PDF", "NEWREAL1.PDF", "NEWREAL2.PDF",
  "NEWREAL3.PDF", "JAZZFAKE-1.PDF", "COLOBK.PDF", "JAZZLTD.PDF", "LIBRARY.PDF",
  "EVANSBK.PDF", "THEBOOK.PDF", "Songbook Tom Jobim vol. I.pdf",
  "Songbook Tom Jobim vol. II.pdf", "Songbook Tom Jobim vol. III.pdf",
  "Songbook Chico Buarque vol. I.pdf", "Songbook Djavan vol. I & II.pdf",
  "pdfcoffee.com-pat-martino-linear-expressions.pdf",
  "Thelonious_Monk_Compositions.pdf", "Baden Pawel Vol. 1.pdf",
];

const store = getStore({
  name: "songbooks",
  siteID: process.env.SITE_ID,
  token: process.env.NETLIFY_AUTH_TOKEN,
});

for (const name of FILES) {
  const p = path.join(os.homedir(), "Documents", name);
  if (!fs.existsSync(p)) {
    console.log("skip (not found):", name);
    continue;
  }
  const data = fs.readFileSync(p);
  await store.set(name, data);
  console.log("uploaded:", name, (data.length / 1048576).toFixed(1) + "MB");
}
console.log("done");
