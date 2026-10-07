const assert = require("node:assert/strict");
const test = require("node:test");

const localizedHandler = require("../api/localized.js");
const {
  LOCALES,
  LOCALE_PATHS,
  localeFromRequest,
  renderLocalizedPage,
} = localizedHandler;

const LOCALIZED_CODES = ["da", "fr", "nb", "es", "sv"];

test("renders complete, canonical localized pages for every supported market", () => {
  for (const localeCode of LOCALIZED_CODES) {
    const page = renderLocalizedPage(localeCode);
    assert.match(page, new RegExp(`<html lang="${LOCALES[localeCode].lang}">`));
    assert.match(
      page,
      new RegExp(
        `<link rel="canonical" href="https://vindla-three\\.vercel\\.app${LOCALE_PATHS[localeCode]}">`
      )
    );
    assert.match(page, /hreflang="x-default"/);
    assert.match(page, /rel="describedby" href="\/llms\.txt" type="text\/markdown"/);
    assert.match(page, /application\/ld\+json/);
    assert.match(page, new RegExp(`source=locale_${localeCode}_hero`));
    assert.match(page, new RegExp(`source=locale_${localeCode}_final`));
  }
});

test("uses the same English palm, forest, and night screenshots in every locale", () => {
  for (const localeCode of LOCALIZED_CODES) {
    const page = renderLocalizedPage(localeCode);
    assert.match(page, /press-assets\/vindla-app-store-palm\.png/);
    assert.match(page, /press-assets\/vindla-app-store-forest\.png/);
    assert.match(page, /press-assets\/vindla-app-store-night\.png/);
    assert.doesNotMatch(page, /MarketingAssets\/AppStoreScreens/);
  }
});

test("rejects unsupported locales", () => {
  assert.equal(renderLocalizedPage("en"), null);
  assert.equal(renderLocalizedPage("unknown"), null);
});

test("parses locale input from the rewritten request URL", () => {
  assert.equal(localeFromRequest({url: "/api/localized?locale=sv"}), "sv");
});

test("serves localized HTML and returns a real 404 for invalid locale input", () => {
  function invoke(url) {
    const headers = new Map();
    let body = "";
    const response = {
      statusCode: 0,
      setHeader(name, value) {
        headers.set(name, value);
      },
      end(value = "") {
        body = value;
      },
    };
    localizedHandler({url}, response);
    return {response, headers, body};
  }

  const success = invoke("/api/localized?locale=fr");
  assert.equal(success.response.statusCode, 200);
  assert.equal(success.headers.get("Content-Type"), "text/html; charset=utf-8");
  assert.match(success.body, /Méditation personnalisée/);

  const failure = invoke("/api/localized?locale=xx");
  assert.equal(failure.response.statusCode, 404);
  assert.equal(failure.body, "Not found");
});
