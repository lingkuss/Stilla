const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const WEBSITE_ROOT = path.join(__dirname, "..");
const read = (fileName) => fs.readFileSync(path.join(WEBSITE_ROOT, fileName), "utf8");
const previewPage = read("try-mimir.html");

test("publishes a truthful, indexable Mimir preview", () => {
  assert.match(previewPage, /<link rel="canonical" href="https:\/\/vindla-three\.vercel\.app\/try-mimir">/);
  assert.match(previewPage, /"@type": "WebApplication"/);
  assert.match(previewPage, /The preview is prewritten/);
  assert.match(previewPage, /This is a short prewritten sample, not a generated session/);
  assert.match(previewPage, /Full sessions are generated around your own words inside Vindla/);
});

test("offers three moments, three guides, and all nine written combinations", () => {
  for (const need of ["racing", "focus", "sleep"]) {
    assert.match(previewPage, new RegExp(`name="need" value="${need}"`));
  }
  for (const guide of ["zen", "guardian", "urban"]) {
    assert.match(previewPage, new RegExp(`name="guide" value="${guide}"`));
  }

  assert.equal((previewPage.match(/title: '[^']+',\n\s+lines: \[/g) || []).length, 9);
  assert.equal((previewPage.match(/lines: \[/g) || []).length, 9);
  assert.match(previewPage, /<fieldset class="mimir-choice-group">/);
  assert.match(previewPage, /aria-live="polite"/);
});

test("keeps every preview install CTA on the measured website campaign", () => {
  const downloadLinks = [...previewPage.matchAll(/href="(\/download\?[^"#]+)"/g)]
    .map((match) => match[1].replaceAll("&amp;", "&"));

  assert.ok(downloadLinks.length >= 3);
  for (const link of downloadLinks) {
    const destination = new URL(link, "https://vindla-three.vercel.app");
    assert.equal(destination.searchParams.get("campaign"), "website");
    assert.match(destination.searchParams.get("source"), /^mimir_preview_/);
  }
});

test("preserves only approved broad campaigns through preview and share flows", () => {
  assert.match(previewPage, /const allowedCampaigns = new Set\(\['website', 'breathing_tool', 'app_directories', 'creator_outreach', 'founder_launch'\]\)/);
  assert.match(previewPage, /allowedCampaigns\.has\(requestedCampaign\) \? requestedCampaign : 'website'/);
  assert.match(previewPage, /destination\.searchParams\.set\('campaign', activeCampaign\)/);
  assert.match(previewPage, /shareURL\.searchParams\.set\('campaign', activeCampaign\)/);

  const breathePage = read("breathe.html");
  assert.match(breathePage, /\/try-mimir\?campaign=breathing_tool&amp;source=breathing_complete/);
});

test("links the preview from acquisition and discovery surfaces", () => {
  for (const fileName of ["index.html", "breathe.html", "press.html", "llms.txt", "sitemap.xml"]) {
    assert.match(read(fileName), /try-mimir/, `${fileName} does not link the Mimir preview`);
  }
});
