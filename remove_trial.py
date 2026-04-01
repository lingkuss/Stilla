import json

path = 'Products.storekit'
with open(path, 'r') as f:
    data = json.load(f)

# Remove trial in the KAI Pro group
if "subscription_groups" in data:
    for group in data["subscription_groups"]:
        if group["name"] == "KAI Pro":
            for sub in group["subscriptions"]:
                if "introductoryOffer" in sub:
                    del sub["introductoryOffer"]

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
