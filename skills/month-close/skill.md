---
name: month-close
description: Close the books for a given month — auto-detects what's done, shows a checklist, walks through each incomplete item using the appropriate skill, then generates a member report.
---

Perform month-end close for 5450 E McLellan Rd Unit 227, LLC.

## Constants

| Key | Value |
|-----|-------|
| Ledger File | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger` |
| Expense Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses` |
| Income Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Income` |
| Paperless API | `https://internal-paperless.gofer.cloud/api` |
| Paperless Token | `8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3` |
| Member Report Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Reports` |

## Instructions

Parse "$ARGUMENTS" for the month to close. Examples:
- `"april"` or `"april 2026"` → close April 2026
- `"last month"` or empty → default to the previous calendar month

Resolve to `{YYYY-MM}`, `{START}` = first day, `{END}` = last day.

---

## Phase 1: Auto-Detect Status

Run all checks in parallel. For each item determine ✅ Complete or ❌ Incomplete.

### 1A — Recurring Bills

```bash
# Mortgage recorded?
hledger -f {LEDGER} print date:{START}..{END} desc:Mortgage 2>&1

# SRP recorded?
hledger -f {LEDGER} print date:{START}..{END} desc:SRP 2>&1

# HOA recorded?
hledger -f {LEDGER} print date:{START}..{END} desc:HOA 2>&1
```

For each found transaction, check if `date_cleared` is set in the source file. A bill is:
- ✅ **Recorded & Cleared** — transaction exists AND has a date_cleared
- 🔶 **Recorded, Not Cleared** — transaction exists but no date_cleared (submitted/pending)
- ❌ **Missing** — no transaction found

### 1B — Income

```bash
hledger -f {LEDGER} print date:{START}..{END} acct:Income 2>&1
```

- ✅ if rent income recorded for the month
- ❌ if no income transactions found (flag as "needs verification — unit may be vacant")

### 1C — Member Contributions

```bash
hledger -f {LEDGER} print date:{START}..{END} desc:"Member Contribution" 2>&1
```

Check if contributions exist and have date_cleared set. Mark each member separately.

### 1D — Amex Balance

```bash
hledger -f {LEDGER} bal Liabilities:Credit:AmexBusinessPlus -N 2>&1
```

- ✅ if balance is $0.00 (fully paid)
- 🔶 if balance > $0 but an Amex payment was recorded this month
- ❌ if balance > $0 and no payment recorded this month

### 1E — Uncleared Transactions (Reconciliation Status)

```bash
# Baselane: any transactions in month without a cleared date?
hledger -f {LEDGER} print date:{START}..{END} acct:Assets:Banking:Baselane:checking:operating not:cleared 2>&1

# Amex: any charges without cleared dates?
hledger -f {LEDGER} print date:{START}..{END} acct:Liabilities:Credit:AmexBusinessPlus not:cleared 2>&1
```

- ✅ **Reconciled** — zero uncleared transactions for that account
- ❌ **Needs Reconciliation** — one or more uncleared transactions remain

### 1F — hledger Integrity Check

```bash
hledger -f {LEDGER} check 2>&1
```

- ✅ if no errors
- ❌ if errors reported (show the errors)

### 1G — Paperless Documents

```bash
# Documents filed for property 5450 this month
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/documents/?created__date__gte={START}&created__date__lte={END}&custom_field_query=2__icontains__5450&page_size=50" 2>/dev/null
```

Count documents filed. Report the count — this is informational, not pass/fail.

---

## Phase 2: Present Checklist

Display the full checklist before doing anything else. Use this format:

```
## Month-End Close — {Month} {YYYY}

### Checklist

**Recurring Bills**
- ✅ Mortgage — recorded & cleared {date}
- 🔶 SRP Electric — recorded, pending clearance
- ❌ Alta Mesa Resort Village HOA — not recorded

**Income**
- ✅ Rent — $X,XXX.XX recorded ({date})
- *(or)* ❌ Rent — not recorded (verify if unit was vacant)

**Member Activity**
- ✅ Jason contribution — $X,XXX.XX, cleared {date}
- ❌ Shannon contribution — not recorded

**Amex**
- ✅ Amex balance — $0.00 (fully paid)
- *(or)* 🔶 Amex balance — $XX.XX outstanding

**Reconciliation**
- ✅ Baselane — fully reconciled ({N} transactions cleared)
- ❌ Amex — {N} uncleared transactions

**Integrity**
- ✅ hledger check — clean
- *(or)* ❌ hledger check — errors found

**Documents**
- ℹ️ Paperless — {N} documents filed for {Month}

---
{X} of {Y} items complete. {N} items need attention.
```

---

## Phase 3: Work Through Incomplete Items

After presenting the checklist, ask the user if they want to work through the incomplete items now:

Use AskUserQuestion with options: "Yes, walk me through them" / "No, just show the report".

If yes, go through each ❌ item in order. For each one:

1. **Explain** what's missing and why it matters
2. **Invoke the appropriate skill** or provide the exact action needed:

| Item | Action |
|------|--------|
| Mortgage not recorded | Ask for payment confirmation PDF → invoke `loan_payment` skill |
| SRP not recorded | Ask for payment confirmation PDF → invoke `expense` skill |
| HOA not recorded | Ask for payment confirmation PDF → invoke `expense` skill |
| Rent not recorded | Ask if rent was received → invoke `income` skill |
| Amex not paid | Show current balance, ask for payment confirmation → invoke `loan_payment` skill |
| Baselane not reconciled | Ask for Baselane statement PDF → invoke `reconcile` skill |
| Amex not reconciled | Ask for Amex statement PDF → invoke `reconcile` skill |
| Member contribution missing | Ask if contribution was made → invoke `transfer` skill |
| hledger errors | Show errors, attempt to diagnose and fix inline |

After each item is resolved, re-run its check and update its status to ✅ before moving to the next.

For 🔶 items (recorded but not cleared): note that these are pending and will clear when the statement arrives — do not block close on these.

---

## Phase 4: Generate Member Report

Once all ❌ items are resolved (or user skips), generate the member report.

### Data to gather:

```bash
# Month income
hledger -f {LEDGER} bal Income -N --begin {START} --end {END} 2>&1

# Month expenses
hledger -f {LEDGER} bal Expenses -N --begin {START} --end {END} 2>&1

# Month transactions detail
hledger -f {LEDGER} print date:{START}..{END} 2>&1

# Member balances (cumulative)
hledger -f {LEDGER} bal Liabilities:Members:Jason Liabilities:Members:Shannon -N --depth 3 2>&1

# Baselane balance as of end of month
hledger -f {LEDGER} bal Assets:Banking:Baselane:checking:operating -N --end {NEXT_MONTH_START} 2>&1

# Amex balance
hledger -f {LEDGER} bal Liabilities:Credit:AmexBusinessPlus -N 2>&1
```

### Report format:

Write the report to `{Member Report Dir}/{YYYY-MM} - Monthly Member Report.md`:

```markdown
# Monthly Member Report — {Month} {YYYY}
**5450 E McLellan Rd Unit 227, LLC**
*Prepared: {today}*

## Summary
| | Amount |
|---|---|
| Rental Income | $X,XXX.XX |
| Total Expenses | $X,XXX.XX |
| **Net Operating Income** | **$X,XXX.XX** |

## Bills
| Date | Description | Amount | Paid From |
|------|-------------|--------|-----------|
| {date} | Mortgage | $1,536.75 | Baselane Operating |
| {date} | SRP Electric | $XX.XX | Baselane Operating |
| {date} | Alta Mesa Resort Village HOA | $380.00 | Baselane Operating |
| {date} | Amex Business Plus | $XX.XX | Baselane Operating |

## Member Contributions This Month
| Member | Amount | Cleared |
|--------|--------|---------|
| Jason | $X,XXX.XX | {date} |
| Shannon | $X,XXX.XX | {date} |

## Account Balances (End of Month)
| Account | Balance |
|---------|---------|
| Baselane Operating | $X,XXX.XX |
| Amex Business Plus | $X.XX |

## What the LLC Owes Each Member (Cumulative)
| | Jason | Shannon | Difference |
|---|---|---|---|
| Total Owed | $XX,XXX.XX | $XX,XXX.XX | $X.XX |

## Close Status
{List any items still pending (🔶) with expected resolution date}
{Or: "All items complete — books closed for {Month} {YYYY}."}
```

Show the report content to the user for review, then write it to disk.

---

## Error Handling

- If hledger check fails: show errors verbatim, attempt to identify which file caused it
- If Paperless is unreachable: skip document count, note in report
- If a skill invocation is needed mid-flow: clearly hand off to that skill, then return to the close checklist after it completes
- If income check shows nothing: ask the user to confirm vacancy before marking ❌ — a vacant unit with no income is not an error
