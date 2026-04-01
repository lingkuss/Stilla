import json

path = 'Products.storekit'
with open(path, 'r') as f:
    data = json.load(f)

# Ensure the KAI Pro subscription is correctly structured
kai_subscription = {
    "adHocOffers": [],
    "codeOffers": [],
    "displayPrice": "4.99",
    "familyShareable": true,
    "groupNumber": 1,
    "internalID": "KAI_PRO_MONTHLY_ID",
    "localizations": [
        {
            "description": "Unlimited personalized meditation journeys.",
            "displayName": "KAI Pro Monthly",
            "locale": "en_US"
        }
    ],
    "productID": "sub.monthly.kai",
    "recurringSubscriptionPeriod": "P1M",
    "referenceName": "KAI Pro Monthly",
    "subscriptionGroupID": "KAIPROGROUP",
    "type": "AutoRenewable"
}

data["subscription_groups"] = [
    {
        "id": "KAIPROGROUP",
        "localizations": [],
        "name": "KAI Pro",
        "subscriptions": [kai_subscription]
    }
]

# Double check all other products
for p in data["products"]:
    # Ensure they have internal IDs
    if "internalID" not in p:
        p["internalID"] = p["productID"].replace(".", "_").upper()

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
