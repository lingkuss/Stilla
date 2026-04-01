import json
import os

path = 'Products.storekit'
with open(path, 'r') as f:
    data = json.load(f)

# KAI Pro Subscription Group
kai_group = {
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

data["subscription_groups"] = [kai_group]

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
