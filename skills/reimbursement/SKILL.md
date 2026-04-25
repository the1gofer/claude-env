---
name: reimbursement
description: Record a member reimbursement between Jason and Shannon for the LLC. Accepts natural language like "Shannon reimbursed Jason $2.06" or "Jason paid Shannon $50". Reduces the payer's outstanding liability and records the settlement. Shows the proposed note for confirmation before saving, then updates and verifies the ledger.
---

Record a member-to-member reimbursement that reduces an outstanding LLC liability.

## Constants

| Key | Value |
|-----|-------|
| Expense Output Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses` |
| Default LLC Wikilink | `[[Entity - 5450 E McLellan Rd Unit 227, LLC\|5450 E McLellan Rd Unit 227, LLC]]` |
| Members | Jason, Shannon |
| Ledger Script | `python3 /Users/jasoncrews/Documents/Unified/generate_ledger.py` |
| Ledger File | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger` |

## Instructions

### Step 1: Parse the Input

Parse `$ARGUMENTS` for natural language like:
- `"Shannon reimbursed Jason $2.06"`
- `"Jason paid Shannon $50"`
- `"Shannon paid me back $2.06 for the Salad and Go meal"`
- `"I paid Shannon $10 for supplies"`

Extract:
- **Payer** — who handed over the money (e.g. "Shannon reimbursed" → Shannon paid)
- **Recipient** — who received the money (e.g. "reimbursed Jason" → Jason received)
- **Amount** — dollar amount
- **Category hint** — if mentioned (e.g. "meal", "supplies", "Salad and Go") use to identify which liability account

Normalize first-person references ("me", "I") to the appropriate member name based on context. When ambiguous, ask.

If any field is missing or ambiguous, use AskUserQuestion to gather:
1. **Who paid** — Shannon or Jason?
2. **Who received** — the other member
3. **Amount**
4. **Category** — which liability account does this reduce? (Meals, Supplies, Repairs, Transfer, etc.)

---

### Step 2: Look Up the Open Liability

Run hledger to find the current open balance on the recipient's liability account:

```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" \
  bal "Liabilities:Members:{recipient}:Owed" -N
```

Show the user the current balances so they can confirm which category this reimbursement applies to. If a category hint was given, pre-select the matching account (e.g. "meal" → `Liabilities:Members:{recipient}:Owed:Meals`).

If the reimbursement amount is larger than the open liability in that category, warn the user and ask to confirm or adjust.

---

### Step 3: Build the Postings

A reimbursement reduces what the LLC owes the recipient and records the payer's contribution.

**Liability account being reduced:**
```
Liabilities:Members:{recipient}:Owed:{category}
```

**Postings:**
```yaml
postings:
  - account: "Liabilities:Members:{recipient}:Owed:{category}"
    amount: {amount}
    note: "{payer} reimbursed {recipient} ${amount} — {category} settlement"
  - account: "Equity:Members:{payer}:Contributions"
    amount: -{amount}
    note: "Reimbursement paid by {payer} (personal funds)"
```

**Tags:** `[rental, reimbursement, llc-liability]`

**Description:** `"{payer} Reimbursement to {recipient} — {category}"`

**Date:** today (`date +%Y-%m-%d`) unless specified in the input.

**Filename:** `{YYYY-MM-DD} - {payer} Reimbursement to {recipient} - {category}.md`

---

### Step 4: Show Full File for Confirmation

**Before writing anything**, display the complete file content to the user exactly as it will be saved:

```
Here is the note that will be saved. Please confirm or let me know what to change:

---
[full file content]
---
```

Use AskUserQuestion with options: **Looks good — save it** / **Make changes** / **Cancel**.

If the user wants changes, update the draft and show it again. Only write after explicit confirmation.

---

### Step 5: Write the Reimbursement File

**Path:** `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses/{filename}`

Check for existing file with same name — warn if found.

**File format:**

```
---
type: transaction
date: {YYYY-MM-DD}
description: "{description}"
total_amount: {amount}
paid_by: {payer}
tags: [rental, reimbursement, llc-liability]
postings:
  - account: "Liabilities:Members:{recipient}:Owed:{category}"
    amount: {amount}
    note: "{payer} reimbursed {recipient} ${amount} — {category} settlement"
  - account: "Equity:Members:{payer}:Contributions"
    amount: -{amount}
    note: "Reimbursement paid by {payer} (personal funds)"
llc: "[[Entity - 5450 E McLellan Rd Unit 227, LLC|5450 E McLellan Rd Unit 227, LLC]]"
---

# {description}

## Transaction Summary
- **Paid By:** {payer}
- **Received By:** {recipient}
- **Amount:** ${formatted_amount}
- **Date:** {YYYY-MM-DD}
- **Reduces:** Liabilities:Members:{recipient}:Owed:{category}

## Accounting Postings
| Account | Amount | Note |
| :--- | :--- | :--- |
| Liabilities:Members:{recipient}:Owed:{category} | ${amount} | {payer} reimbursed {recipient} — {category} settlement |
| Equity:Members:{payer}:Contributions | -${amount} | Reimbursement paid by {payer} (personal funds) |

## Related
- [[R01 - Rentals/Expenses/_Expense Dashboard|Expense Dashboard]]
```

---

### Step 6: Regenerate Ledger and Verify

```bash
python3 /Users/jasoncrews/Documents/Unified/generate_ledger.py > "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger"
```

Verify the transaction posted correctly:
```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" print date:{YYYY-MM-DD} desc:{keyword}
```

Show the updated balance on the affected liability account:
```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" \
  bal "Liabilities:Members:{recipient}:Owed:{category}" -N
```

Run a full balance check:
```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" bal -N
```

If hledger reports errors, fix the file and re-verify. Show the user the updated liability balance as confirmation that the debt has been reduced.

---

## Error Handling

- **Ambiguous payer/recipient:** Always ask — never assume who paid whom.
- **Amount exceeds open liability:** Warn the user. Could be a different category or an over-payment.
- **No open liability found:** Warn the user — there may not be a recorded debt to settle. Ask them to confirm the category or check the original expense.
- **File already exists:** Warn and ask to overwrite or change description.
- **Ledger errors:** Inspect YAML formatting and fix before reporting success.
