const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const WEBSITE_ROOT = path.join(__dirname, "..");
const LLMS_PATH = path.join(WEBSITE_ROOT, "llms.txt");
const SITE_ORIGIN = "https://vindla-three.vercel.app";

test("publishes a spec-shaped llms.txt with factual product guidance", () => {
  const contents = fs.readFileSync(LLMS_PATH, "utf8");

  assert.match(contents, /^# Vindla\n\n> /);
  assert.match(contents, /consumer wellness product, not medical care/);
  assert.match(contents, /does not diagnose, treat, or cure medical conditions/);
  assert.match(contents, /## Product/);
  assert.match(contents, /## Trust and availability/);
  assert.match(contents, /## Localized product pages/);
});

test("keeps every Vindla llms.txt link on a public website route", () => {
  const contents = fs.readFileSync(LLMS_PATH, "utf8");
  const links = [...contents.matchAll(/\]\((https:\/\/[^)]+)\)/g)].map((match) => match[1]);

  assert.ok(links.length >= 10);
  for (const link of links) {
    if (link.startsWith(SITE_ORIGIN)) {
      const route = new URL(link).pathname;
      const staticFile = route === "/"
        ? path.join(WEBSITE_ROOT, "index.html")
        : path.join(WEBSITE_ROOT, `${route.slice(1)}.html`);
      const isLocalizedRoute = ["/da", "/fr", "/nb", "/es", "/sv"].includes(route);

      assert.ok(isLocalizedRoute || fs.existsSync(staticFile), `Missing website route for ${link}`);
    }
  }
});

