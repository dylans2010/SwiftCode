---
name: in-app-purchases-storekit
description: "Implement in-app purchases and subscriptions with StoreKit 2."
category: Platform
tags: [storekit, in-app purchase, subscriptions]
tools: [project_entitlements, swift_list_types]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# In App Purchases Storekit

Implement in-app purchases and subscriptions with StoreKit 2.

## When to use this skill
- The user asks for work involving: storekit, in-app purchase, subscriptions.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Define products in App Store Connect and a StoreKit config file.
2. Load products with Product.products(for:).
3. Purchase and verify transactions; finish them.
4. Listen to Transaction.updates and restore with AppStore.sync.

## Rules
- Entitlement checks from verified transactions.
- Handle pending/ask-to-buy.

## Verification
- [ ] Sandbox purchase/restore tested.
- [ ] Unverified transactions rejected.

## Avoid
- Unlocking before verification.
- Not finishing transactions.

## Recommended SwiftCode tools
- `project_entitlements`
- `swift_list_types`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
