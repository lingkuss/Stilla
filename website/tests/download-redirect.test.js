const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const downloadHandler = require("../api/download.js");
const {
  buildAppStoreURL,
  campaignForRequest,
  queryFromRequest,
} = downloadHandler;

test("groups existing website sources into the website campaign", () => {
  assert.equal(campaignForRequest({ source: "hero" }), "website");
  assert.equal(campaignForRequest({ source: "sleep_final" }), "website");
});

test("groups breathing and work-reset sources", () => {
  assert.equal(
    campaignForRequest({ source: "breathing_complete" }),
    "breathing_tool"
  );
  assert.equal(
    campaignForRequest({ source: "work_reset_hero" }),
    "breathing_tool"
  );
});

test("supports the five explicit broad campaigns and rejects unknown values", () => {
  assert.equal(
    campaignForRequest({ campaign: "creator_outreach" }),
    "creator_outreach"
  );
  assert.equal(
    campaignForRequest({ campaign: "untrusted-value", source: "hero" }),
    "website"
  );
});

test("builds a valid Apple campaign URL when the provider token is configured", () => {
  const destination = new URL(
    buildAppStoreURL({ source: "breathing_complete" }, "123456789")
  );
  assert.equal(destination.hostname, "apps.apple.com");
  assert.equal(destination.pathname, "/app/apple-store/id6761864704");
  assert.equal(destination.searchParams.get("pt"), "123456789");
  assert.equal(destination.searchParams.get("ct"), "breathing_tool");
  assert.equal(destination.searchParams.get("mt"), "8");
});

test("falls back safely when the provider token is unavailable or malformed", () => {
  assert.equal(
    buildAppStoreURL({ source: "hero" }, ""),
    "https://apps.apple.com/app/id6761864704"
  );
  assert.equal(
    buildAppStoreURL({ source: "hero" }, "not-a-token"),
    "https://apps.apple.com/app/id6761864704"
  );
});

test("parses campaign inputs from the request URL without reading request.query", () => {
  let legacyQueryWasRead = false;
  const request = {
    url: "/download?source=work_reset_hero",
    get query() {
      legacyQueryWasRead = true;
      throw new Error("legacy query parser should not be read");
    },
  };
  const headers = new Map();
  const response = {
    statusCode: 0,
    setHeader(name, value) {
      headers.set(name, value);
    },
    end() {},
  };

  assert.deepEqual(queryFromRequest(request), {
    campaign: null,
    source: "work_reset_hero",
  });
  downloadHandler(request, response);

  assert.equal(legacyQueryWasRead, false);
  assert.equal(response.statusCode, 302);
  assert.equal(
    headers.get("Location"),
    "https://apps.apple.com/app/id6761864704"
  );
});

test("keeps every visible website App Store CTA on the attributed router", () => {
  const websiteDirectory = path.resolve(__dirname, "..");
  const htmlFiles = fs
    .readdirSync(websiteDirectory)
    .filter((fileName) => fileName.endsWith(".html"));
  let attributedLinkCount = 0;

  for (const fileName of htmlFiles) {
    const contents = fs.readFileSync(
      path.join(websiteDirectory, fileName),
      "utf8"
    );
    assert.doesNotMatch(
      contents,
      /href=["']https:\/\/apps\.apple\.com/i,
      `${fileName} bypasses campaign attribution`
    );
    attributedLinkCount += [
      ...contents.matchAll(/href=["']\/download\?[^"']+["']/g),
    ].length;
  }

  assert.ok(attributedLinkCount >= 20, "expected the site-wide App Store CTAs");
});
