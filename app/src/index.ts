import express, { Request, Response } from "express";
import { readFileSync } from "fs";
import { hostname } from "os";
import { join } from "path";

const PORT = Number(process.env.PORT ?? 8080);

// The release baked into this image at build time - see the Dockerfile. It's
// part of the image, so it moves with the code when slots are swapped.
interface Release {
  version: string;
  colour: string;
}
const release: Release = JSON.parse(readFileSync(join(__dirname, "release.json"), "utf8"));

// Everything the page shows about where it's running and how it's configured.
// The settings are read on every request: App Service restarts the container
// with the new values when a swap changes them.
function describe(req: Request) {
  return {
    release,
    slot: {
      // Set by App Service. These describe the slot, not the code, so they stay
      // put when the slot's contents are swapped.
      WEBSITE_SITE_NAME: process.env.WEBSITE_SITE_NAME ?? null,
      WEBSITE_HOSTNAME: process.env.WEBSITE_HOSTNAME ?? null,
      requestHost: req.headers.host ?? null,
      container: hostname(),
    },
    settings: {
      // A slot setting ("sticky"): stays with the slot during a swap.
      SLOT_ENVIRONMENT: process.env.SLOT_ENVIRONMENT ?? null,
      // An ordinary app setting: swaps along with the code.
      RELEASE_NOTES: process.env.RELEASE_NOTES ?? null,
    },
  };
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// The colour comes from the image's own build, but is still treated as
// untrusted when it's put into CSS.
function cssColour(value: string): string {
  return /^[a-z]+$|^#[0-9a-f]{3,6}$/i.test(value) ? value : "grey";
}

function row(name: string, value: string | null, note: string): string {
  const shown = value === null ? `<em>not set</em>` : `<code>${escapeHtml(value)}</code>`;
  return `<tr><th><code>${escapeHtml(name)}</code></th><td>${shown}</td><td>${escapeHtml(note)}</td></tr>`;
}

function renderPage(req: Request): string {
  const info = describe(req);
  const colour = cssColour(info.release.colour);
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(info.release.version)} (${escapeHtml(info.release.colour)})</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 52rem; margin: 2rem auto; padding: 0 1rem; }
    .release { background: ${colour}; color: white; padding: 1.5rem; border-radius: 0.5rem; }
    .release h1 { margin: 0; font-size: 2.5rem; }
    table { border-collapse: collapse; width: 100%; margin-top: 1rem; }
    th, td { text-align: left; padding: 0.4rem; border-bottom: 1px solid #ddd; vertical-align: top; }
    td:last-child { color: #555; }
    code { overflow-wrap: anywhere; }
  </style>
</head>
<body>
  <div class="release">
    <h1>${escapeHtml(info.release.version)} - ${escapeHtml(info.release.colour)}</h1>
    <p>This is the release baked into the image. It moves when the slots are swapped.</p>
  </div>

  <h2>App settings</h2>
  <table>
    ${row("SLOT_ENVIRONMENT", info.settings.SLOT_ENVIRONMENT, "Slot setting (sticky) - stays with the slot on a swap.")}
    ${row("RELEASE_NOTES", info.settings.RELEASE_NOTES, "Ordinary app setting - moves with the code on a swap.")}
  </table>

  <h2>Where this is running</h2>
  <table>
    ${row("Host header", info.slot.requestHost, "The hostname you used to reach this slot.")}
    ${row("WEBSITE_SITE_NAME", info.slot.WEBSITE_SITE_NAME, "Set by App Service.")}
    ${row("WEBSITE_HOSTNAME", info.slot.WEBSITE_HOSTNAME, "Set by App Service - the slot's own hostname.")}
    ${row("Container", info.slot.container, "The container serving this request.")}
  </table>
</body>
</html>`;
}

const app = express();

app.get("/", (req: Request, res: Response) => {
  res.type("html").send(renderPage(req));
});

// The same information as JSON, for checking a swap from the command line.
app.get("/api/info", (req: Request, res: Response) => {
  res.json(describe(req));
});

app.get("/healthz", (_req: Request, res: Response) => {
  res.send("ok");
});

app.listen(PORT, () => {
  console.log(`release ${release.version} (${release.colour}) listening on port ${PORT}`);
});
