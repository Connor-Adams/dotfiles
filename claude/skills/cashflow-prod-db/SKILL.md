---
name: cashflow-prod-db
description: Use when needing to query, inspect, or audit the Cashflow production Postgres database. Covers connection setup via Railway CLI, safety guardrails (read-only default), and common diagnostic query patterns. Triggers - "query prod", "check prod db", "prod data", "run against prod", "audit prod", "/cashflow-prod-db".
---

# Cashflow — Production Database Access

## Overview

Connect to the Cashflow production Postgres instance via Railway CLI and run
diagnostic/audit queries. **Read-only by default** — never run INSERT, UPDATE,
DELETE, DROP, ALTER, or TRUNCATE unless Connor explicitly asks and confirms the
exact SQL.

## Prerequisites

- `railway` CLI installed and authenticated (`railway login`)
- Railway project linked: `cd /Users/connoradams/Developer/cashflow && railway status`
  should show `Project: Cashflow Tracker, Environment: production`
- `psql` available (via `brew install libpq` or `postgresql`)

## Connection

Get the public connection URL and connect:

```bash
cd /Users/connoradams/Developer/cashflow
DB_URL=$(railway variables -s Postgres --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['DATABASE_PUBLIC_URL'])")
psql "$DB_URL" -c "SELECT 1"
```

For multi-statement queries, pipe via heredoc:

```bash
psql "$DB_URL" <<'SQL'
SELECT COUNT(*) FROM transactions;
SQL
```

For repeated queries in one session, store the URL:

```bash
export CASHFLOW_PROD_DB=$(railway variables -s Postgres --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['DATABASE_PUBLIC_URL'])")
psql "$CASHFLOW_PROD_DB" -c "..."
```

**IMPORTANT:** Never echo or log the full DATABASE_PUBLIC_URL — it contains
credentials. Truncate or mask when displaying to user.

## Safety Rules

1. **Read-only by default.** Only SELECT. If Connor asks for a write operation,
   confirm the exact SQL before executing.
2. **Never dump credentials** in conversation output. Truncate or mask the
   connection string when displaying.
3. **Set statement_timeout** for expensive queries:
   ```bash
   psql "$DB_URL" -c "SET statement_timeout = '30s'; SELECT ..."
   ```
4. **Avoid full table scans** on large tables without a WHERE clause. Key tables
   and approximate row counts (as of 2026-06):
   - `transactions` — ~5,500 rows (small, full scans OK)
   - `receipts` — ~2,000 rows
   - `accounts` — ~30 rows
   - `fx_rates` — ~3,000 rows
   - `receipt_items` — ~8,000 rows
5. **Do not** connect the local app to prod DB for write operations. If needed for
   read-only debugging, disable ALL schedulers first (see CLAUDE.md / conventions.md).

## Column Name Mapping

Sequelize camelCase → Postgres snake_case:

| Sequelize | Postgres |
|-----------|----------|
| `txnType` | `txn_type` |
| `finalCategory` | `final_category` |
| `finalBusiness` | `final_business` |
| `merchantClean` | `merchant_clean` |
| `merchantRaw` | `merchant_raw` |
| `accountType` | `account_type` |
| `householdId` | `household_id` |
| `createdByUserId` | `created_by_user_id` |
| `ownershipType` | `ownership_type` |
| `myShareAmount` | `my_share_amount` |
| `partnerShareAmount` | `partner_share_amount` |
| `businessAmount` | `business_amount` |
| `linkedTransactionId` | `linked_transaction_id` |
| `finalSplitType` | `final_split_type` |
| `finalPctMe` | `final_pct_me` |
| `finalPctPartner` | `final_pct_partner` |
| `cadAmount` | `cad_amount` |
| `reviewFlag` | `review_flag` |

## Common Query Patterns

### Spend audit
```sql
-- Dashboard spend by txnType (what's included vs excluded)
SELECT txn_type, COUNT(*) AS cnt,
  ROUND(SUM(ABS(amount))::numeric, 2) AS total_abs
FROM transactions
WHERE amount < 0
GROUP BY txn_type
ORDER BY total_abs DESC;
```

### Transaction breakdown by month
```sql
SELECT id, date, amount, txn_type, final_category,
  COALESCE(merchant_clean, merchant_raw) AS merchant
FROM transactions
WHERE date >= '2026-05-01' AND date <= '2026-05-31'
  AND currency = 'CAD'
ORDER BY amount ASC
LIMIT 50;
```

### Account overview
```sql
SELECT id, name, account_type, institution, currency
FROM accounts
ORDER BY institution, name;
```

### Investment account transactions
```sql
SELECT t.id, a.name, t.txn_type, t.amount, t.currency, t.date
FROM transactions t
JOIN accounts a ON t.account_id = a.id
WHERE a.account_type = 'investment'
ORDER BY t.date DESC
LIMIT 20;
```

### Unclassified rows
```sql
-- Positive deposits with no txnType classification
SELECT txn_type, COUNT(*) AS cnt, ROUND(SUM(amount)::numeric, 2) AS total
FROM transactions
WHERE amount > 0 AND (txn_type IS NULL OR txn_type = 'unknown')
GROUP BY txn_type;
```

### Category spend (dashboard-consistent)
```sql
-- Excludes non-spend txnTypes to match dashboard logic
SELECT final_category, COUNT(*) AS cnt,
  ROUND(SUM(ABS(amount))::numeric, 2) AS total
FROM transactions
WHERE amount < 0
  AND (txn_type IS NULL OR txn_type NOT IN
    ('transfer','investment','dividend','payment','refund','reward','income'))
  AND currency = 'CAD'
GROUP BY final_category
ORDER BY total DESC
LIMIT 20;
```

### Duplicate detection
```sql
SELECT date, amount, currency, merchant_clean, COUNT(*) AS dupes
FROM transactions
WHERE currency = 'CAD'
GROUP BY date, amount, currency, merchant_clean
HAVING COUNT(*) > 1
ORDER BY dupes DESC, ABS(amount) DESC
LIMIT 20;
```

## Troubleshooting

- **"could not connect"**: Railway TCP proxy may be down. Check `railway status`.
  The proxy URL is `turntable.proxy.rlwy.net` — if it changed, re-fetch via
  `railway variables -s Postgres --json`.
- **"permission denied"**: Ensure `railway status` shows `Environment: production`.
  Switch with `railway environment production`.
- **Slow query**: Add `EXPLAIN ANALYZE` prefix to diagnose. The DB is ~33 MB —
  most queries should be <100ms.
- **SSL required**: The Railway proxy handles SSL termination. If you get SSL
  errors, try appending `?sslmode=require` to the URL.
