const APP_STORE_ID = "6761864704";
const DIRECT_APP_STORE_URL = `https://apps.apple.com/app/id${APP_STORE_ID}`;

const CAMPAIGNS = new Set([
  "website",
  "breathing_tool",
  "app_directories",
  "creator_outreach",
  "founder_launch",
]);

const SOURCE_CAMPAIGN_RULES = [
  [/^(breathing|work_reset)/, "breathing_tool"],
  [/^(app_director|directory|indie|taplist|apprater|appswap|app_lottery)/, "app_directories"],
  [/^(creator|newsletter|partner)/, "creator_outreach"],
  [/^(founder|launch|product_hunt|indie_hackers|show_hn|linkedin)/, "founder_launch"],
];

function singleQueryValue(value) {
  return Array.isArray(value) ? value[0] : value;
}

function campaignForRequest(query = {}) {
  const requestedCampaign = singleQueryValue(query.campaign);
  if (CAMPAIGNS.has(requestedCampaign)) {
    return requestedCampaign;
  }

  const source = String(singleQueryValue(query.source) || "")
    .trim()
    .toLowerCase();
  const matchedRule = SOURCE_CAMPAIGN_RULES.find(([pattern]) => pattern.test(source));
  return matchedRule ? matchedRule[1] : "website";
}

function buildAppStoreURL(query = {}, providerToken = process.env.APPLE_PROVIDER_TOKEN) {
  const normalizedProviderToken = String(providerToken || "").trim();
  if (!/^\d+$/.test(normalizedProviderToken)) {
    return DIRECT_APP_STORE_URL;
  }

  const destination = new URL(
    `https://apps.apple.com/app/apple-store/id${APP_STORE_ID}`
  );
  destination.searchParams.set("pt", normalizedProviderToken);
  destination.searchParams.set("ct", campaignForRequest(query));
  destination.searchParams.set("mt", "8");
  return destination.toString();
}

function queryFromRequest(request) {
  const requestURL = new URL(
    request.url || "/download",
    "https://vindla-three.vercel.app"
  );
  return {
    campaign: requestURL.searchParams.get("campaign"),
    source: requestURL.searchParams.get("source"),
  };
}

function downloadHandler(request, response) {
  const destination = buildAppStoreURL(queryFromRequest(request));
  response.statusCode = 302;
  response.setHeader("Cache-Control", "private, no-store, max-age=0");
  response.setHeader("Location", destination);
  response.end();
}

module.exports = downloadHandler;
module.exports.buildAppStoreURL = buildAppStoreURL;
module.exports.campaignForRequest = campaignForRequest;
module.exports.queryFromRequest = queryFromRequest;
