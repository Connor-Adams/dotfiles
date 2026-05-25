---
name: wcli
description: Use when fetching live state from the Wander backend API during investigation — reservations, invoices, customers, listings, organizations, PMS sync drift, or any prod data lookup by ID. Pulls live data via the `wcli` CLI. Trigger on phrases like "show me reservation X", "what's the invoice state for...", "find org Y", "what's the unit ID for...", "what PMS is on this unit", "bed count wrong", "rooms mismatched", "stale listing data", "PMS sync issue", "fetch from prod", "use wcli", or any `wcli` command appearing in the task.
---

# `wcli` — Wander backend live lookups

`wcli` is auto-generated from the backend's API routes. ~36 modules, 260+ leaves, all currently read-only. Every leaf's `--help` ends with a `Source: services/api/src/routes/...:LINE` link back into the wander backend repo at `~/Developer/Work/wander/`. That source-file linkage is the killer feature — use it.

## 1. Pre-flight: know which env you're on

**First action of any wcli use** — before any other call:

```bash
cat ~/.wandercli/config.json
```

Read `currentTarget` and `currentOrgId`. Surface them. The default target is `https://api.wander.com` — that's **production**. A query you didn't think was a prod hit probably is. Don't assume staging.

## 2. Safety rule (future-proof)

Every wcli leaf today starts with `get-` and is read-only — even ones with HTTP method `POST` or `PATCH` (search-via-body, `read-only despite PATCH`, etc.). The package is at v0.1.0; mutations may land later.

**If you see a leaf whose name does NOT start with `get-`, or `--help` shows `method: DELETE`: STOP and ask Connor before invoking.** Do not bake "wcli is safe" as a permanent assumption.

## 3. Discovery pattern (three steps, no recursion)

```bash
wcli --help                  # 36-module index. Read once per session.
wcli <module> --help         # leaf list with one-liners.
wcli <module> <leaf> --help  # flags, endpoint, enum values, Source: path.
```

Don't `--help` recursively into every module. Pick the module from the top-level index and go straight to the leaf.

## 4. Output discipline

Every list call: `--fields <minimal>` + `--take <small>` + `--pretty`. Endpoints return large JSON; full payloads shred context.

`--fields` projection rules:
- `A.B` keeps the entire `B` object
- `A.B.C` keeps only `C` under `B`
- comma-separated for multiple paths, e.g. `--fields data.id,data.name,data.address.city`

## 5. Source-file as a feature

When the user asks "what does this endpoint return" / "what are the possible states" / "what triggers this code path" — read the file from `Source:`, don't infer from one JSON payload. Path is relative to `~/Developer/Work/wander/`. This is the canonical CLI-surface → handler → Zod schema bridge.

## 6. Cross-org / cross-env

Prefer `--org-id <alias|id>` per-call over mutating global state with `wcli auth use-org` or `wcli housekeeping set-target`. Mid-session global flips are how a "staging check" turns into a prod hit.

The only documented org alias is `wos` (= `cl92umiay27616ls6hf5nyl2d`).

## 7. Failure recovery

- **401** → `wcli auth list-orgs` to verify token presence and alias spelling. Don't try to re-auth silently — surface to Connor; tokens are scoped to (target × org) and may be expired.
- **404** → check `currentTarget` first. Wrong env masquerades as missing record.
- **"Unknown command"** → CLI may be stale. Mention this; suggest `npm i -g @wandercom/wander-cli` if the leaf was added recently.

## 8. Top-5 cheatsheet

Each command verified against live `--help`. Leaf shapes may drift; if surprised, run `wcli <module> <leaf> --help`.

### Listings, units, PMS

Find an org by name:
```bash
wcli organizations get-organizations --search "<name fragment>" \
  --fields data.id,data.name,data.type --take 5
```
`type` is `OWNER | BRANDED | WANDER`.

Get an org by ID:
```bash
wcli organizations get-organization --id <orgId> --pretty
```

Find a unit by name/address (scope to org if you can — much smaller):
```bash
wcli listings get-units --search "<term>" --owner-org-id <orgId> --take 10 \
  --fields data.id,data.name,data.address.city,data.address.state
```
`get-light-listings` is the POST-body equivalent if the query string gets unwieldy.

Bed/bedroom/bath counts for a listing:
```bash
wcli listings get-listing --id <listingId> --pretty
wcli listings get-rooms   --id <listingId> --pretty
```
`get-listing` returns top-level aggregate counts. `get-rooms` is the room-by-room source. **If those two disagree, that mismatch *is* the bug** — capture it before going further.

What PMS is a unit on?
```bash
wcli pms get-pms-integrations --unit-id <unitId> --pretty
```
Returns integration(s) including `pmsType` and `pmsIntegrationId` (needed for `get-property-listings`).

Sync status for a listing (always check first when symptom is "data is stale"):
```bash
wcli listings get-resource-sync-statuses --id <listingId> --pretty
```

Wander vs PMS source-of-truth diff:
```bash
wcli pms get-property-listings --unit-id <unitId> --pms-integration-id <pmsIntegrationId> --pretty
wcli listings get-listing --id <listingId> --pretty
```
Drift between these is the canonical sync-bug signal.

Org units overview by PMS / onboarding status:
```bash
wcli pms get-organization-units-overview --organization-id <orgId> --pms-type HOSTAWAY --pretty
```
Valid `--pms-type`: `HOSTAWAY, HOSTFULLY, GUESTY, LODGIFY, ICAL, OWNERREZ, TRACK, STREAMLINE, NEXTPAX, ESCAPIA, RENTALSUNITED, CIIRUS, WANDER_TEST, HOSPITABLE`. Filter broken syncs with `--onboarding-status PMS_INTEGRATION_FAILED`.

### Reservations

Slice by state:
```bash
wcli reservations get-reservations --state checkout-today --org-id <orgId> --take 20 \
  --fields data.id,data.checkInDate,data.checkOutDate,data.unitId,data.customerId
```
Valid `--state`: `checkin-today, checkout-today, requests, active, past, upcoming`.

One reservation in detail:
```bash
wcli reservations get-reservation-detail --id <reservationId> --pretty
```

`--channels` filter accepts the full PMS enum (`WANDER_APPS, OTA_AIRBNB, OTA_BOOKINGCOM, ..., PMS_HOSTAWAY, ...`), repeatable.

### Invoices

Two views of one invoice — pick deliberately:
```bash
wcli invoices get-invoice         --id <invoiceId> --pretty   # SaaS view (curated for OS)
wcli invoices get-invoice-invoices --id <invoiceId> --pretty  # raw record view
```
List form similarly: `get-invoices` (query params) vs `get-invoices-invoices` (POST search body for complex filters).

Refunds and payments live in the same module: `get-refunds`, `get-refund --id`, `get-payment --id`, `get-user-payments`.

### Customers

```bash
wcli customers get-customers --query "<term>" --take 10 \
  --fields data.id,data.name,data.email
```

Two kinds of customer detail — important to pick the right one:
```bash
wcli customers get-user-customer-details    --id <customerId> --pretty   # registered-user customer
wcli customers get-contact-customer-details --id <customerId> --pretty   # contact-only customer
```

Notes attached to a customer: `wcli customers get-notes --customer-id <id>`.

### Organizations

Covered above (search + by-id). One more:
```bash
wcli organizations get-organization-members --organization-id <orgId> --pretty
```

## 9. Bug-squash bridge

When a Linear ticket body contains IDs that look like reservation / invoice / customer / listing / org IDs, the matching `wcli get-*` call is the **first** investigation step — before Loki. Live state beats logs for "is this still happening / what does the record actually look like." This skill pairs with `hackathon-bug-squash`.

## 10. Discipline

- **wcli hits production by default.** Run a query once; reuse the output. Don't re-fetch the same data turn after turn.
- **Have an ID before querying.** If you don't have one, ask Connor — don't list-and-pick at random.
- **Capture findings to kindex.** Sync drift, payment-state quirks, and customer-kind confusion all recur. Add a concept node with the entity ID, what was wrong, and the diff between sources.
- **Source-link in writeups.** Every command's `--help` prints the backend route + source path — quote it when you describe what you found.

## Extending

If a workflow recurs that isn't in the cheatsheet, add a recipe here rather than re-deriving it from `--help` next session. Top-level discovery (`wcli <module> --help`) covers the ~31 modules not detailed above (`access`, `agreements`, `assets`, `chat`, `discounts`, `editor`, `help-center`, `influencers`, `internal`, `invites`, `marketing`, `media`, `notifications`, `onboarding`, `owners`, `payouts`, `pricing`, `reviews`, `seo`, `site-search`, `staff`, `statements`, `stripe`, `surveys`, `tasks`, `taxes`, `tools`, `users`, `vendors`, `website`).
