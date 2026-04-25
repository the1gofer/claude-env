---
name: member-balances
description: Show what the LLC owes each member over time — cumulative monthly balances for Jason and Shannon, with the difference between them.
---

Show cumulative monthly member balances for 5450 E McLellan Rd Unit 227, LLC — what the LLC owes Jason and Shannon over time, and the difference between them.

## Constants

| Key | Value |
|-----|-------|
| Ledger File | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger` |

## Instructions

Parse "$ARGUMENTS" for an optional period or filter. Examples:
- `"2026"` → show only 2026 months
- `"transfers only"` → show only the Transfer sub-account
- Empty / no argument → show all months from inception to today

### Step 1: Get Cumulative Monthly Totals

```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" \
  bal Liabilities:Members:Jason Liabilities:Members:Shannon -N --monthly --cumulative --depth 3 2>&1
```

If "transfers only" or similar is requested, use depth 4 and filter to `Liabilities:Members:Jason:Owed:Transfer` and `Liabilities:Members:Shannon:Owed:Transfer`.

### Step 2: Present Report

Build a markdown table with one row per month. For each month calculate:
- **Owed to Jason** = absolute value of Jason's balance (positive number — the LLC owes him this)
- **Owed to Shannon** = absolute value of Shannon's balance
- **Difference** = Jason's amount minus Shannon's amount (positive = Jason is ahead, negative = Shannon is ahead, $0.00 if equal — always show as a number, never as words like "Even")

```
## Member Balances — What the LLC Owes Each Member

| Month | Owed to Jason | Owed to Shannon | Difference |
|---|---|---|---|
| Nov 2025 | $36,483.82 | $36,483.82 | $0.00 |
| Dec 2025 | $39,058.87 | $39,058.89 | -$0.02 |
| ...      | ...         | ...          | ...        |
| **Current** | **$XX,XXX.XX** | **$XX,XXX.XX** | **$X.XX** |
```

Format all amounts as `$X,XXX.XX`. Positive difference = Jason ahead, negative = Shannon ahead.

Add a brief note below the table on what the bulk of the balance represents (e.g. down payment equity vs. operational advances) and whether the 50/50 split is on track.
