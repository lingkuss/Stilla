import json

with open('Products.storekit', 'r') as f:
    data = json.load(f)

# 1. Add KAI Pro Subscription Group
if "subscription_groups" not in data or not data["subscription_groups"]:
    data["subscription_groups"] = [
        {
            "id": "KAIPROGROUP",
            "localizations": [],
            "name": "KAI Pro",
            "subscriptions": [
                {
                    "adHocOffers": [],
                    "codeOffers": [],
                    "displayPrice": "4.99",
                    "familyShareable": true,
                    "groupNumber": 1,
                    "internalID": "SUBMONTHLYKAI",
                    "introductoryOffer": {
                        "internalID": "KAI7DAYTRIAL",
                        "numberOfPeriods": 1,
                        "paymentMode": "free",
                        "subscriptionPeriod": "P1W"
                    },
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
            ]
        }
    ]

with open('Products.storekit', 'w') as f:
    json.dump(data, f, indent=2)
