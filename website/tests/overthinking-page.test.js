const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const WEBSITE_ROOT = path.join(__dirname, "..");
const read = (fileName) => fs.readFileSync(path.join(WEBSITE_ROOT, fileName), "utf8");
const page = read("meditation-for-overthinking.html");

test("publishes a substantive, indexable overthinking practice", () => {
  assert.match(page, /<link rel="canonical" href="https:\/\/vindla-three\.vercel\.app\/meditation-for-overthinking">/);
  assert.match(page, /"@type": "HowTo"/);
  assert.match(page, /"totalTime": "PT2M"/);
  assert.equal((page.match(/<li><time>/g) || []).length, 4);
  assert.match(page, /general-wellness tool, not a substitute for professional care/);
  assert.match(page, /does not provide diagnosis, therapy, or medical treatment/);
});

test("connects the overthinking page to useful previews and measured installs", () => {
  assert.match(page, /\/try-mimir\?need=racing&amp;guide=guardian&amp;campaign=website/);
  assert.match(page, /\/try-mimir\?need=racing&amp;guide=zen&amp;campaign=website/);

  const downloadLinks = [...page.matchAll(/href="(\/download\?[^"#]+)"/g)]
    .map((match) => match[1].replaceAll("&amp;", "&"));

  assert.ok(downloadLinks.length >= 4);
  for (const link of downloadLinks) {
    const destination = new URL(link, "https://vindla-three.vercel.app");
    assert.equal(destination.searchParams.get("campaign"), "website");
    assert.match(destination.searchParams.get("source"), /^overthinking_/);
  }
});

test("preserves an approved creator campaign across overthinking and preview handoffs", () => {
  assert.match(page, /const allowedCampaigns = new Set\(\['website', 'breathing_tool', 'app_directories', 'creator_outreach', 'founder_launch'\]\)/);
  assert.match(page, /allowedCampaigns\.has\(requestedCampaign\) \? requestedCampaign : 'website'/);
  assert.match(page, /a\[href\^="\/download\?"\], a\[href\^="\/try-mimir\?"\]/);
  assert.match(page, /destination\.searchParams\.set\('campaign', activeCampaign\)/);
});

test("rewrites creator handoffs at runtime without losing their source labels", () => {
  const inlineScripts = [...page.matchAll(/<script>([\s\S]*?)<\/script>/g)];
  const campaignScript = inlineScripts.at(-1)[1];
  const initialHrefs = [
    "/download?campaign=website&source=overthinking_final",
    "/try-mimir?need=racing&guide=guardian&campaign=website",
  ];
  const links = initialHrefs.map((href) => ({
    href,
    getAttribute(name) {
      assert.equal(name, "href");
      return this.href;
    },
    setAttribute(name, value) {
      assert.equal(name, "href");
      this.href = value;
    },
  }));

  vm.runInNewContext(campaignScript, {
    URL,
    URLSearchParams,
    window: {
      location: {
        origin: "https://vindla-three.vercel.app",
        search: "?campaign=creator_outreach&source=michelle_cazella",
      },
    },
    document: {
      querySelectorAll(selector) {
        assert.equal(selector, 'a[href^="/download?"], a[href^="/try-mimir?"]');
        return links;
      },
    },
  });

  const download = new URL(links[0].href, "https://vindla-three.vercel.app");
  assert.equal(download.searchParams.get("campaign"), "creator_outreach");
  assert.equal(download.searchParams.get("source"), "overthinking_final");

  const preview = new URL(links[1].href, "https://vindla-three.vercel.app");
  assert.equal(preview.searchParams.get("campaign"), "creator_outreach");
  assert.equal(preview.searchParams.get("need"), "racing");
  assert.equal(preview.searchParams.get("guide"), "guardian");
});

test("links the new practice from discovery files", () => {
  for (const fileName of ["index.html", "sitemap.xml", "llms.txt"]) {
    assert.match(read(fileName), /meditation-for-overthinking/, `${fileName} does not link the page`);
  }
});
