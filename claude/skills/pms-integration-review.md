---
name: pms-integration-review
description: "Reviews any PMS integration for completeness against the testing checklist, identifies gaps, and produces a structured report. Use when the user wants to audit, diagnose, or review a PMS integration. Examples: 'review the CiiRUS integration', 'what's missing from Hostaway?', 'audit PMS integration gaps'"
---

# PMS Integration Review

Audits a PMS integration against the canonical checklist (`TESTING_PMS.md`) and
produces a structured gap report with severity ratings.

**Args:** `--pms <NAME>` (e.g., `--pms CIIRUS`, `--pms GUESTY`)

If no `--pms` is provided, ask the user which integration to review.

## On Activation

1. Parse the PMS name from args or ask the user.
2. Normalize to uppercase (e.g., `ciirus` -> `CIIRUS`).
3. Set `PMS_DIR` = `services/sync/src/pms/<lowercase>/`
4. Set `FIXTURE_DIR` = `services/sync/src/testing/<lowercase>/`

## Prerequisites Check

Before starting the audit, verify the integration exists:

```
- [ ] PMS_DIR exists and contains manifest.ts
- [ ] PMS name appears in PmsType enum (types/index.ts)
- [ ] PMS manifest is registered in ALL_MANIFESTS (pms/index.ts)
```

If any prerequisite fails, report it and stop.

## Audit Phases

Run all 8 phases sequentially. Each phase checks specific files and code
patterns. Collect results into a structured report at the end.

---

### Phase 1: File Structure Completeness

Check for required files per `pms/CLAUDE.md`:

```
- [ ] manifest.ts        — definePmsProvider() wiring
- [ ] config.ts          — PMS-specific config layer
- [ ] types.ts OR schemas.ts — API response type definitions
- [ ] endpoints.ts       — defineEndpoints() declarations
- [ ] fetch-plans.ts     — FetchPlanMap orchestration
- [ ] auth-plan.ts       — defineAuthPlan() auth flow
- [ ] mappings/index.ts  — mapping barrel exports
```

**Compare against reference integrations** (Guesty, Hostaway, Track,
Streamline): list files in at least two reference `pms/*/` directories and flag
any file present in references but absent in the target.

Also check for:

- `webhook-config.ts` — required if PMS supports webhooks
- `mappings/quote.ts` — required if PMS has a quoting API
- `mappings/coupon.ts` — required if PMS has a coupon / promo-code API (e.g.
  Hostaway, Track). Most PMSs don't — flag as N/A in that case.

---

### Phase 2: Authentication

Read `auth-plan.ts` and `endpoints.ts` to verify:

```
- [ ] Auth strategy is consistent (per-org vs platform credentials)
      — If auth-plan stores per-org creds, endpoints must use them (not platformBasic env vars)
      — If platformBasic, auth-plan should reflect that model
- [ ] Token refresh flow (if applicable) — expiry type, refresh steps
- [ ] Credential encryption — encryptedFields covers sensitive data
- [ ] Auth fixtures present (authFixtures in auth plan)
- [ ] Test credentials present (testCredentials in auth plan)
```

**Critical check:** grep for `platformBasic` in endpoints.ts and compare with
auth-plan credential schema. If auth-plan defines per-org fields that are never
referenced by endpoints, flag as CRITICAL (multi-tenant isolation broken).

**Discovery scoping check (platformBasic PMSs only):** When endpoints use
`platformBasic`, the platform API account sees ALL tenants' data. Verify that
`listProperties` in `fetch-plans.ts` passes an org-scoping identifier from
`credentialPaths` as a query param. Known patterns:

- CiiRUS: `management_company_user_id` from `cred.supplierId`
- Streamline: `advertiser_id` from `credential.advertiserId`

If `platformBasic` is used and `listProperties` has NO credential-based scoping
param, flag as CRITICAL (multi-tenant discovery leak — all suppliers' properties
get mixed into one org).

---

### Phase 3: Operations & Mapping Coverage

Read `manifest.ts` to extract declared operations, then verify each has a
corresponding mapping and fetch plan.

#### 3a. Inbound Sync Operations

Cross-reference manifest operations with the TESTING_PMS.md checklist:

```
- [ ] property:INBOUND    — mapping + fetch plan + fixture
- [ ] availability:INBOUND — mapping + fetch plan + fixture
- [ ] pricing:INBOUND     — mapping + fetch plan + fixture
- [ ] booking:INBOUND     — mapping + fetch plan + fixture
- [ ] review:INBOUND      — mapping + fetch plan + fixture (if PMS has reviews)
- [ ] listProperties      — fetch plan + fixture
- [ ] listCoupons         — fetch plan + mapping + fixture (if PMS has a
      coupon API; verify `manifest.operations.listCoupons`,
      `fetch-plans.platform.listCoupons`, `mappings.coupon`, and
      `FIXTURE_DIR/read/expected/list-coupons.json`)
```

For `listCoupons` specifically, also verify the coupon mapping handles the
`AMOUNT` vs `PERCENTAGE` split (one populated, the other empty per item) and the
`provider` literal matches the manifest's `pmsType`.

For each declared operation, verify:

1. A mapping file exists in `mappings/`
2. A fetch plan exists in `fetch-plans.ts` under `sync.<domain>.read`
3. An expected fixture exists in `FIXTURE_DIR/read/expected/<domain>.json`

**`listProperties` no-status-filter check:** Read the `listProperties` plan in
`fetch-plans.ts` and inspect the `query` parameters passed to the underlying
`call()`. The plan MUST NOT pass any status / lifecycle filter to the PMS —
including but not limited to `isActive`, `is_active`, `status=active`,
`bookable=true`, `archived=false`, `includeArchived=false`, `published=1`,
`live=true`, `deleted=false`. We fetch every unit the PMS exposes and derive the
canonical `isActive` flag in the property mapping (see Phase 4).

If `listProperties` passes any such filter, flag as **CRITICAL** — once a unit
is filtered out at the boundary, downstream consumers cannot distinguish
"deactivated", "deleted", and "never existed", and reactivation / audit flows
break.

#### 3b. Outbound Command Operations

```
- [ ] getBookingQuote   — fetch plan + mapping + quote endpoint
- [ ] reserveBooking    — fetch plan + mapping
- [ ] modifyBooking     — fetch plan + mapping (or documented as unsupported)
- [ ] cancelBooking     — fetch plan + mapping
```

For each command:

1. Check if declared in manifest operations
2. Verify fetch plan in `fetch-plans.ts` under `commands.<operation>`
3. Verify mapping exists
4. For getBookingQuote: check if PMS API supports quoting (grep for `quote` in
   endpoint docs or types)

##### Schema-vs-capture audit (write-side)

Write-side response schemas (`getBookingQuote`, `reserveBooking`,
`modifyBooking`, `cancelBooking`) drift from documentation more often than
read-side schemas, and a wrong schema produces a `Schema decode failed` runtime
error that surfaces as `canUsePmsQuote: false` to the monorepo with no signal of
the underlying cause. For every write-side command:

```
- [ ] A captured fixture exists at FIXTURE_DIR/write/calls.json with a real
      response body for this command (not a hand-authored stub)
- [ ] The endpoint's response schema in types.ts / schemas.ts has fields that
      match the captured response (no required fields the response is
      missing; no envelope assumed when the response is flat)
```

Flag any write-side command whose schema cannot be verified against a real
capture as **HIGH** severity — production calls will fail with no useful
diagnostic until someone instruments the validation path. Reference: CIIRUS
`unitQuote.create` shipped Apr 2026 with an envelope-wrapped schema; real
response is flat and includes charge types (`clean_fee`, `tax_three`) the
mapping didn't recognize. The bug went undetected until first production use
because no fixture existed for the command.

---

### Phase 4: Property Mapping Depth

Read `mappings/property.ts` and compare mapped fields against the checklist:

```
- [ ] name & description
- [ ] address & coordinates (street, locality, region, postalCode, country, lat, lng)
- [ ] bedrooms & bathrooms
- [ ] room details (bed types, counts from bedroom_configuration or equivalent)
- [ ] maxGuests / occupancy
- [ ] photos (url, order, caption)
- [ ] amenities (mapped to canonical enum via lookup table)
- [ ] petPolicy (allowPets, maxPets, description)
- [ ] pet fees (in fees array)
- [ ] housePolicy (smoking, children, infants, events, quiet hours)
- [ ] cancellationPolicy (name, tiers, description)
- [ ] checkIn / checkOut times
- [ ] minNights (default minimum stay)
- [ ] currency
- [ ] area + areaUnit
- [ ] propertyType
- [ ] license number (if PMS provides)
- [ ] isActive (derived from PMS lifecycle fields — see check below)
- [ ] property hash / change detection
```

**`isActive` derivation check:** Every property mapping MUST emit a canonical
`isActive: boolean`. Verify:

1. The mapping populates `isActive` on the assembled `CanonicalProperty` (grep
   `mappings/property.ts` for `isActive`).
2. `isActive` is **derived** from the PMS's lifecycle fields and not implied by
   absence (we fetch every unit, so every unit reaches the mapping).
3. The derivation AND-combines every lifecycle signal the PMS exposes that gates
   booking eligibility. That may be a single field or many — both are correct as
   long as the formula reflects every signal the PMS publishes. Examples:
   - **Hostaway / Guesty:** a single status field is fine (`status === "active"`
     / `isListed === true`) — that is the only signal these PMSs expose.
   - **Track:** must combine multiple
     (`isActive && isBookable && cancellationPoliciesIds[0]`).

   Cross-check the formula against status fields documented in `types.ts` /
   `schemas.ts` and the stage 1 discovery digest (if available). A single-field
   derivation is suspicious only when the PMS also publishes additional gating
   signals that are being ignored.
4. The mapping does NOT throw when status-dependent data (pricing, cancellation
   policy) is absent for non-bookable units — these are handled with
   `optional()` in the fetch plan (Phase 3) and conditional spreads in the
   mapping. A mapping that requires `pricing` or `cancellationPolicy` to be
   present will fail for inactive units and silently exclude them from sync.

If `isActive` is missing entirely, flag as **CRITICAL** (downstream cannot gate
guest-visibility). If the formula omits a lifecycle signal the PMS exposes (e.g.
only `isActive` when the PMS also exposes `isBookable` or a cancellation-policy
attachment), flag as **MEDIUM** with the specific signals that should be
combined.

For each field:

- **MAPPED**: field() or block() targeting the canonical field
- **IGNORED**: explicit ignore() with reason
- **MISSING**: neither mapped nor ignored — this is a gap

Also check: does the PMS API return data for unmapped fields? Read the types
file to see if response schemas include fields like `cancellation_policy`,
`pet_policy`, `house_rules`, `bedroom_configuration` that are present in the API
but not mapped.

---

### Phase 5: Webhook & Infrastructure

```
- [ ] webhook-config.ts exists (if PMS supports webhooks)
      — eventFields, externalIdFields, eventMappings, shaping
- [ ] OR documented reason why no webhooks (polling model)
- [ ] Rate limits configured in manifest config
- [ ] Read fixtures present (FIXTURE_DIR/read/calls.json + expected/)
- [ ] Write fixtures present (FIXTURE_DIR/write/calls.json + expected/)
- [ ] Review fixtures present (FIXTURE_DIR/read/expected/review.json if review:INBOUND)
- [ ] Webhook fixtures present (if webhooks supported)
```

---

### Phase 6: Test Coverage

Count and categorize test files in `PMS_DIR/__tests__/`:

```
- [ ] mapping.unit.test.ts          — mapping transform tests
- [ ] auth-plan.unit.test.ts        — auth flow tests (if non-trivial auth)
- [ ] commands.integration.test.ts  — live command tests
- [ ] platform.integration.test.ts  — listProperties live test
- [ ] platform.unit.test.ts         — platform operation unit tests
- [ ] sync-reads.integration.test.ts — live read sync tests
- [ ] webhook.unit.test.ts          — webhook parsing tests (if webhooks)
```

Compare test file count against reference integrations:

- Guesty: 10 test files
- Track: 9 test files
- Hostaway: 9 test files
- Streamline: 8 test files

Flag if target has < 3 test files.

#### Diagnostic logging on validation failures

`AdapterValidationError` carries the raw response body in its `raw` field, but
the default RPC error log only surfaces the schema mismatch message — not the
raw body. Without a targeted log, schema drift in a write-side endpoint produces
`canUsePmsQuote: false` to the monorepo with no signal of the actual response
shape, and debugging requires a code change + deploy to capture it.

Verify there is targeted raw-payload logging on validation failures for at least
quote and reserve endpoints. The pattern (added in PR #439) lives in
`services/sync/src/external/command-handler.ts` next to the success-path
`Effect.tap`:

```ts
Effect.tapError((err) =>
  data.command === "<command>" &&
    data.pmsType === "<PMS>" &&
    err._tag === "AdapterValidationError"
    ? Effect.logWarning("Raw quote response from PMS (validation failed)").pipe(
      Effect.annotateLogs({
        "sync.pms.type": data.pmsType,
        "sync.raw_quote": JSON.stringify(err.raw),
      }),
    )
    : Effect.void
),
```

```
- [ ] tapError raw-payload log scoped to {pmsType, command, AdapterValidationError}
      for at least getBookingQuote (and reserveBooking if applicable)
```

Flag absence as **MEDIUM** severity — the integration works without it, but any
future schema drift becomes a blind spot that costs deploys to debug.

---

### Phase 7: Cross-Repo & External Dependencies

Check items that require work outside the sync service. The checklist differs
based on whether the PMS is **migrated** (existed in monorepo first, moved to
sync service) or **sync-native** (built directly in the sync service).

**Determine migration status:** Check whether the PMS has an existing
integration in the monorepo. If the wander monorepo is accessible, look for a
PMS-specific `create-integration.ts` file at
`src/wos-saas/module/src/logic/pms/<pms-name>/create-integration.ts`. If the
file exists, the PMS is migrated (or mid-migration). If no monorepo code exists
for the PMS, it is sync-native. Note: presence in enrolled-orgs.ts
`SUPPORTED_PMS_TYPES` means the PMS is effectively migrated to the sync service,
but should NOT be used as an indicator of completion status — absence does NOT
mean sync-native, it could be mid-migration.

#### Migrated PMSs (Guesty, Hostaway, Track, Streamline, OwnerRez)

```
- [ ] PMS type in monorepo enrolled-orgs.ts SUPPORTED_PMS_TYPES
- [ ] buildAuthPayload() case in enrolled-orgs.ts
- [ ] Credential passing from monorepo pmsIntegration table
- [ ] DB migration for rate_limit_config (if needed)
- [ ] Doppler env vars configured (platform credentials)
```

#### Sync-native PMSs (CiiRUS, future integrations)

These PMSs bypass enrolled-orgs entirely. No monorepo DB rows (`pmsIntegration`,
`pmsUnitMapping`) are created. The onboarding flow is: frontend → monorepo
`create-integration.ts` (pure relay) → sync service `POST /sync/credentials` →
discovery via `listProperties` → `ingest-property` back to monorepo.

```
- [ ] monorepo create-integration.ts relays to sync service credentials endpoint
- [ ] EnrollmentService supports additive enrollment (enrollOrg method)
- [ ] Doppler env vars configured (platform credentials)
- [ ] ingest-property.ts handles PMS canonical values (check safeParse fallback)
```

**Onboarding flow completeness check:** Regardless of migration status, verify
whether the full onboarding path is wired end-to-end:

```
- [ ] Frontend can trigger PMS connection for this PMS type
- [ ] Monorepo create-integration handles this PMS (relay or full flow)
- [ ] Sync service receives credentials and kicks off discovery
- [ ] E2E onboarding flow has been tested (frontend → monorepo → sync → discovery)
```

If the onboarding flow is not wired, flag as **CRITICAL** — the integration
cannot be used in production without it, regardless of how complete the sync
service side is. This is a common blind spot: all mappings and commands can be
perfect, but if there's no way to onboard an org, nothing works.

These are informational — the skill cannot verify them directly but should
remind the user to check.

#### Monorepo per-PMS feature-flag wiring audit

The wandercom/wander monorepo carries per-PMS feature-flag arrays that gate
capabilities. Missing the PMS from any one of them produces a silent fallback
(no error, just degraded behavior). For PMSs that expose a quote API, verify the
monorepo PR added the PMS to:

```
- [ ] PMS_PARTNERS_SUPPORTING_BOOKING_QUOTES
      (src/pms/pms/schemas/src/defs/pms/constants.ts)
      Without it, booking-service short-circuits with canUsePmsQuote=false and
      invoicing falls back to DB pricing. CRITICAL — produces undercharged
      invoices.
- [ ] PMS_PARTNERS_REQUIRING_PRE_CONFIRMATION (same file)
      Without it, Stripe payment intent skips the last-minute availability
      check. HIGH — risks taking payment for unavailable dates.
- [ ] fetchBookingQuoteLogic switch case
      (src/pms/pms/module/src/logic/sync-pms/fetch-booking-quote.ts)
      Defensive: when useSyncService returns false, the dispatch falls into
      `default → canUsePmsQuote: false`. MEDIUM — only fires if the env var
      gating fails.
- [ ] SYNC_SERVICE_ORGS Doppler config
      (sentinel for sync-native PMSs, or per-org for migrated PMSs)
      Without it, useSyncService returns false; quotes don't route through
      sync. CRITICAL.
```

**Note: this set of lists is an active anti-pattern** — there's an open ticket
to consolidate them. Until that lands, all four are required for a quote-capable
PMS.

#### Silent-fallback risk audit

For sync-native PMSs (no monorepo `pmsUnitMapping` rows), the invoicing fallback
in `src/invoicing/module/src/logic/bookings/actions.ts` —
`processPmsQuoteResponse` — returns `undefined` when `supportsQuoting` is false,
allowing fallback to DB pricing. DB pricing for most CiiRUS-style PMSs only
carries nightly rates from the pricing read; cleaning fees and taxes only live
in the live quote endpoint. Falling back means undercharged invoices with no
signal in logs.

```
- [ ] Verify the PMS pricing read populates fees/taxes into the wos pricing
      tables, OR
- [ ] Verify the PMS is in PMS_PARTNERS_SUPPORTING_BOOKING_QUOTES so the
      fallback path is never taken
```

If neither is true, flag as **CRITICAL** — the integration will silently produce
undercharged invoices for any booking made before the live quote path is wired.

---

### Phase 8: Per-PMS Documentation

Per the convention in `services/sync/src/pms/CLAUDE.md` ("## Per-PMS
Documentation"), each PMS should have a `README.md` at `PMS_DIR/README.md`
documenting deviations from the generic authoring guide. Without it, debugging
an integration-specific failure requires reverse-engineering from source.

Read `PMS_DIR/README.md` (if present) and verify it covers the minimum content
set:

```
- [ ] README.md exists at PMS_DIR/README.md
- [ ] Link to PMS API documentation (developer reference, OpenAPI / Swagger,
      or vendor docs URL)
- [ ] Link to PMS dashboard (sandbox dashboard at minimum; production dashboard
      if applicable)
- [ ] Auth shape documented — credential field names, auth strategy (HTTP Basic
      / OAuth / per-tenant subdomain), and any dual-pair / multi-credential
      selection rules
- [ ] Sandbox credential safety note — explicitly state whether the sandbox
      credentials are a real test account safe for write operations (creating /
      modifying / cancelling bookings) or a read-only sandbox where writes are
      forbidden or unsafe
- [ ] Documented quirks / edge cases / unexpected behavior — section name
      doesn't matter. PMS-specific surprises should be
      captured: payload sanitization rules, required upstream resources,
      dual-auth selection, pagination quirks, rate-limit idiosyncrasies, or
      anything else that would otherwise have to be discovered by reading
      source or watching a sync fail.
```

**Severity:**

- README.md missing entirely → flag as **MEDIUM** (no documented deviations).
  Then scan `endpoints.ts` / `auth-plan.ts` / `fetch-plans.ts` for obvious
  gotchas that warrant a README (unusual auth tags, custom request headers, side
  effects in plan nodes, non-optional fan-out calls that depend on sibling
  resources) and list each as a recommended documentation topic.
- README.md exists but missing one of the five required sections → flag each gap
  as **LOW**, except:
  - Missing sandbox-safety note for a PMS where bookings cost real money or
    affect a shared production tenant → **MEDIUM**.
  - Missing documented quirks when known issues exist in the source (e.g. the
    code has comments like `// XYZ rejects @`, custom payload rewriters,
    workaround flags, or non-optional fan-out calls that depend on sibling
    resources) → **MEDIUM**, regardless of what section name (if any) the README
    uses for its quirks notes.

---

## Report Format

After all phases complete, produce a structured report. **The verdict and
summary go FIRST** — readers need the conclusion before the evidence.

```markdown
# PMS Integration Review: <PMS_NAME>

## Verdict

One-paragraph overall assessment: is this integration production-ready? What is
the single biggest blocker? Give a clear signal up front — don't bury it after
pages of detail.

## Summary

- Files: X/Y required files present
- Operations: X/Y checklist operations implemented
- Test files: X (vs ~10 for a mature integration)
- Fixtures: read ✅/❌, write ✅/❌, webhook ✅/❌/N/A
- Per-PMS README: ✅ (X/5 required sections) / ❌ missing

## Critical Issues (must fix)

1. [PHASE] Description — what's wrong and why it matters

## Medium Issues (completeness gaps)

1. [PHASE] Description — what's missing vs other integrations

## Low Issues (nice to have)

1. [PHASE] Description — minor gaps or acceptable tradeoffs

## Recommendations

Prioritized list of next steps. **Feature gaps and missing flows come first,
test coverage comes last.** If there are unsure/unverified features, those rank
above missing tests. Order:

1. Missing or broken functionality (onboarding flow, auth, commands)
2. Unverified features (mappings based on assumptions, untested against live
   API)
3. Missing fixtures or data gaps
4. Test coverage improvements

## Checklist Status

Every item MUST have an explicit status marker. Never leave items as bare
unmarked lines — that is ambiguous and hard to scan.

Use these markers:

- ✅ DONE — implemented and verified
- ❌ MISSING — not implemented, should be
- ⚠️ ATTENTION — implemented but needs review (hardcoded values, assumptions,
  partial implementation). **Bold the specific concern** (e.g., "**hardcoded
  USD**", "**unmapped field available in API**")
- ➖ N/A — not applicable (PMS API doesn't support it, not relevant)

### Authentication

- ✅ Item — evidence
- ❌ Item — what's missing
- ⚠️ Item — **what needs attention**

### Property — Inbound Sync

...

### Taxes, Fees & Invoice Reconciliation

...

### Webhooks

...

### Infrastructure

...

### Availability & Pricing — Inbound Sync

...

### Booking

...

### Coupons

(Mark whole section ➖ N/A if PMS has no coupon API.)

- ✅/❌ `listCoupons` operation declared in manifest
- ✅/❌ Coupon mapping populates `amount` (minor units) for AMOUNT type and
  `percentage` for PERCENTAGE type, never both
- ✅/❌ `provider` literal matches manifest's `pmsType`
- ✅/❌ Sentinel values normalized (e.g. `-1` → `0` for unlimited redemptions)
- ✅/❌ `list-coupons.json` fixture present and exercises both discount types

### Onboarding Flow

...

### Documentation

- ✅/❌ README.md exists at PMS_DIR/README.md
- ✅/❌ Link to API documentation
- ✅/❌ Link to dashboard (sandbox / production)
- ✅/❌ Auth shape documented
- ✅/❌ Sandbox credential safety note (write-safe vs read-only)
- ✅/❌ Quirks / edge cases / unexpected behavior documented (any section name,
  or inline)
```

## Severity Classification

| Severity | Criteria                                                                                 |
| -------- | ---------------------------------------------------------------------------------------- |
| CRITICAL | Breaks multi-tenant isolation, data corruption, money errors, missing required operation |
| MEDIUM   | Feature gap vs other integrations, missing tests, incomplete fixtures                    |
| LOW      | Acceptable tradeoff, API doesn't support it, cosmetic                                    |

## Tips

- Always read `types.ts` / `schemas.ts` to understand what data the PMS API
  actually returns before flagging a mapping gap. If the API doesn't return a
  field, it's not a gap.
- Compare with at least two reference integrations (Guesty + Hostaway) for
  context on what "complete" looks like.
- Check the PMS API documentation if available to understand capabilities.
- When flagging auth issues, explain the specific multi-tenant impact.
- For monetary fields, verify the conversion factor (10^8, 10^6, cents, etc.) is
  consistent across all mappings.
- **Amenity/bed mappers in monorepo:** Don't automatically flag a missing
  `pmsAmenityMappers` or `pmsBedMappers` entry in `ingest-property.ts` as
  critical. The monorepo has a `safeParse` fallback — if the PMS maps amenities
  to canonical enum values that match the monorepo's `AmenitySchema` Zod enum,
  no explicit mapper is needed. Verify by extracting all canonical amenity
  values from the PMS mapping and checking them against the enum. Same logic
  applies to `UnitRoomBedTypeSchema` for bed types.
- **Migrated vs sync-native:** Before flagging enrolled-orgs or monorepo DB
  gaps, determine whether the PMS is migrated or sync-native (see Phase 7).
  Sync-native PMSs have a completely different onboarding path.
- **Coupons are optional:** Only some PMSs (Hostaway, Track) expose a native
  coupon / promo-code API. If the PMS has no such API, mark the entire Coupons
  section ➖ N/A — don't flag missing `listCoupons` or `mappings/coupon.ts` as a
  gap. Confirm by checking if a coupon endpoint appears in `endpoints.ts` or the
  PMS's API docs.
