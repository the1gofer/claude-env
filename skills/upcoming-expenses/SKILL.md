---
name: upcoming-expenses
description: Report upcoming expected expenses for the LLC rental property, show what's already been paid, whether the account covers everything, and what members need to contribute to cover any shortfall at 50/50.
---

Report upcoming expected expenses for 5450 E McLellan Rd Unit 227, LLC. Answer three questions:
1. What recurring bills have been paid or are expected this period?
2. Will the Baselane account cover all bills — and what is the surplus or deficit?
3. What do the members need to contribute to cover any shortfall, split 50/50?

## Constants

| Key | Value |
|-----|-------|
| Ledger File | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger` |
| Recurring Journal | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/recurring.journal` |

## Instructions

Parse "$ARGUMENTS" to determine the forecast period. Examples:
- `"may"` or `"may 2026"` → forecast for that month
- `"next 2 months"` → current + next month
- `"april and may"` → both months
- Empty / no argument → default to current month + next month

Then execute these steps:

---

### Step 1: Get Recurring Bills (Paid + Expected)

Use `--forecast=START..END` (explicit range) to generate all scheduled transactions. Bare `--forecast` without a range can incorrectly suppress periodic transactions with similarly-named historical entries:

```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" \
  --forecast={START}..{END} print date:{START}..{END} 2>&1
```

Also pull actual recorded transactions for the same period:

```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" \
  print date:{START}..{END} 2>&1
```

A bill is **paid** if a real transaction with the same description exists in the actual output. Deduplicate — don't show a bill twice. Mark paid ✅, unpaid ❌.

**Always include the current Amex Business Plus balance as a line item** — it is a real bill paid from Baselane. Use "Amex Business Plus" as the description, marked ❌ unless a payment was already recorded this period.

---

### Step 2: Get Account Balances

**Baselane balance — always use `--end {TOMORROW}` (today + 1 day, YYYY-MM-DD) so future-dated transactions don't reduce the balance before they actually clear:**

```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" \
  bal Assets:Banking:Baselane:checking:operating Liabilities:Credit:AmexBusinessPlus -N --end {TOMORROW} 2>&1
```

Note: `Assets:Banking:Baselane:checking:operating:restricted` holds earnest money deposits — exclude this from available funds.

---

### Step 3: Calculate Surplus / Deficit

- **Total bills** = sum of all unpaid items in the table (including Amex)
- **Net Available** = Baselane operating balance (unrestricted only) minus Amex balance
- **Surplus / Deficit** = Net Available minus Total unpaid bills

If deficit: calculate each member's required contribution to cover it 50/50, adjusted for any existing imbalance between members' prior contributions.

To check member imbalance:
```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" \
  bal Liabilities:Members:Jason:Owed:Transfer Liabilities:Members:Shannon:Owed:Transfer -N 2>&1
```
A more negative balance = that member has contributed more. Adjust the 50/50 split accordingly so contributions equalize over time.

If surplus: state that no contributions are needed and how much will remain after all bills clear.

---

### Step 4: Present Report

```
## Upcoming Expenses — {Period}

### Recurring Bills
| Date | Description | Amount | Status |
|------|-------------|--------|--------|
| May 1 | Mortgage | $1,536.75 | ✅ Paid |
| May 1 | SRP Electric | $60.38 | ✅ Paid |
| May 1 | Resort Village HOA | $380.00 | ❌ Due |
| TBD | Amex Business Plus | $21.99 | ❌ Due |
| **Total** | | **$1,999.12** | |
| **Unpaid** | | **$401.99** | |

### Account Status
- **Baselane Operating (today):** $1,999.13
- **Amex owed:** -$21.99
- **Net Available:** $1,977.14
- **Total Unpaid Bills:** -$401.99
- **Surplus / Deficit:** +$1,575.15

### Member Contributions Needed
{If surplus}: No contributions needed — Baselane covers all bills with $X.XX to spare after everything clears.
{If deficit}: Shortfall of $X.XX — Jason should contribute $X.XX, Shannon should contribute $X.XX (adjusted for current imbalance of $X.XX).
```

Keep the recommendation concrete — exact dollar amounts, no ranges. If one member is ahead on prior contributions, reflect that in the split.

---

## Error Handling

- If `--forecast` returns no transactions: check that `recurring.journal` is included and the date range is correct.
- If the period is ambiguous (e.g. just "next month"), resolve to the calendar month after today's date.
- If member transfer balances are hard to parse, query each separately: `hledger bal Liabilities:Members:Jason:Owed:Transfer -N` and `hledger bal Liabilities:Members:Shannon:Owed:Transfer -N`.
