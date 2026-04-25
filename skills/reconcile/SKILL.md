---
name: reconcile
description: Reconcile a bank statement (Baselane or Amex) against the LLC expense notes. Accepts a PDF or image of a statement. Matches statement transactions to existing expense files by date and amount, backfills missing date_cleared fields, flags unmatched transactions, and regenerates the ledger. Trigger when user says "reconcile", "here is my statement", or provides a bank statement file.
---

Reconcile a bank or credit card statement against the LLC Obsidian expense notes.

## Constants

| Key | Value |
|-----|-------|
| Expense Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses` |
| Income Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Income` |
| Ledger Script | `python3 /Users/jasoncrews/Documents/Unified/generate_ledger.py` |
| Ledger File | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger` |
| LLC Wikilink | `[[Entity - 5450 E McLellan Rd Unit 227, LLC\|5450 E McLellan Rd Unit 227, LLC]]` |
| Paperless URL | `https://internal-paperless.gofer.cloud` |
| Paperless Token | `8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3` |

## Statement Types

### Baselane Checking (Operating Account)

| Field | Value |
|-------|-------|
| Detection | PDF contains "Baselane" and shows account/routing numbers |
| Date format | MM/DD/YYYY (cleared dates shown on statement) |
| Amount sign | Positive = credit/deposit; Negative = debit/withdrawal |
| Account pattern | `Assets:Banking:Baselane*` |
| Paperless correspondent lookup | `name__icontains=baselane` |
| Paperless correspondent id | 88 |
| Title format | `{Account Name}` (e.g. `Operating Account`) — correspondent + month come from Paperless template |
| Document type | 8 (Statement) |
| Storage path | 13 (Business - Statements) |
| Custom fields | `{"2": "7tmUdxi30uhfZCKb"}` |

**Matching rules:**
- Statement debits → expense files with Baselane posting
- Statement credits → transfer/contribution files (money in to Baselane)
- File must have `baselane: true` OR a posting to `Assets:Banking:Baselane*`
- Skip opening/closing balance rows and fee summary rows

---

### Amex Blue Business Plus

| Field | Value |
|-------|-------|
| Detection | PDF contains "American Express" or "Amex" and "Business Plus" or account ending pattern `X-XXXXX` |
| Date format | MM/DD/YY (transaction date) |
| Amount sign | Positive = charge/debit; Negative = payment/credit |
| Transaction section | "New Charges" > "Detail" section (skip "Fees", "Interest", totals rows) |
| Account pattern | `Liabilities:Credit:AmexBusinessPlus` |
| Closing date | Identified in statement header; determines the statement period |
| Paperless correspondent lookup | `name__icontains=amex` |
| Title format | `Blue Business Plus` — correspondent + month come from Paperless template |
| Document type | 8 (Statement) |
| Storage path | 13 (Business - Statements) |
| Custom fields | `{"2": "7tmUdxi30uhfZCKb"}` |

**Matching rules:**
- Statement charges (positive amounts) → expense files with `Liabilities:Credit:AmexBusinessPlus` posting
- Statement credits/payments → NOT matched to expense files (payments to Amex are tracked separately)
- Match on `total_amount` in frontmatter (includes tax), NOT individual posting amounts
- Date tolerance: ±3 days

---

## Instructions

### Step 0: Detect Statement Type

Read the PDF. Determine if it's:
- **Baselane** — account/routing numbers, shows "Baselane" branding
- **Amex Blue Business Plus** — "American Express", account ending format, closing date header

Apply the appropriate rules from the Statement Types section above.

---

### Step 1: Parse the Statement

Extract every transaction:

| Field | Notes |
|-------|-------|
| `cleared_date` | The date shown on the statement |
| `description` | Statement description text |
| `amount` | Normalized: positive = money out (charge/debit), negative = money in (credit/payment) |
| `type` | `charge` or `payment` |

For **Amex**: parse from the "New Charges > Detail" section. Dates are MM/DD/YY — convert to YYYY-MM-DD using the statement year. Skip fee rows, interest rows, and section totals.

For **Baselane**: skip opening/closing balance rows and fee summary rows.

**Security note:** After extracting all transactions, do not retain or reference the raw statement content further.

---

### Step 2: Load Existing Expense Files

Determine the load window from the parsed statement:
- **Window start** = earliest statement transaction date − 14 days
- **Window end** = latest statement transaction date

Only load `.md` files in Expense Dir and Income Dir whose `date` frontmatter field falls within that window. Skip files outside the window entirely.

For each file within the window with `type: transaction`, extract from frontmatter:
- `date`
- `date_cleared` (may be absent)
- `description`
- `total_amount` — use this for matching (includes tax)
- `payment_source` — for Amex matching
- `baselane` (true/false) — for Baselane matching
- `postings` — look for relevant account postings

Build an in-memory list of all transactions within the window.

---

### Step 3: Match Statement to Expense Notes

For each statement transaction, attempt to find a matching expense note using this priority order:

1. **Exact match** — `total_amount` equals statement amount AND date within ±3 days AND correct account posting
2. **Amount match** — same `total_amount`, different date (flag as "fuzzy match, verify date")
3. **No match** — flag as unmatched

**Per statement type:**

*Baselane:*
- Debits → expense files with `Assets:Banking:Baselane*` posting OR `baselane: true`
- Credits → transfer/contribution files posting TO `Assets:Banking:Baselane*`

*Amex:*
- Charges → expense files with `Liabilities:Credit:AmexBusinessPlus` posting
- Payments → skip (not matched to expense files)
- Match amount against `total_amount` frontmatter field

**General notes:**
- A file already having `date_cleared` set should still be verified
- Multiple files matching same amount → show all candidates, ask user to pick

---

### Step 4: Present Reconciliation Summary

Show the user a full table before making any changes:

```
## Reconciliation Summary — {account} — {period}

### ✅ Matched (will add/verify date_cleared)
| Statement Date | Description | Amount | Matched File | Current date_cleared | Action |
|---|---|---|---|---|---|
| ...

### ⚠️ Fuzzy Match (review needed)
| Statement Date | Description | Amount | Possible Match | Notes |
|---|---|---|---|---|
| ...

### ❌ Unmatched Statement Transactions (no expense note found)
| Statement Date | Description | Amount | Notes |
|---|---|---|---|
| ...

### 🔍 Unmatched Expense Notes (in ledger but not on statement)
List any expense notes in the statement period that have the correct account posting but did NOT match a statement transaction.
```

Ask the user to confirm before writing any changes:
- **Proceed — apply all matched cleared dates**
- **Review individually**
- **Cancel**

---

### Step 5: Apply Cleared Dates and Statement Links

For each confirmed match:

1. If the file has no `date_cleared`, add it after the `date:` line in frontmatter
2. If the file has `date_cleared` already and it matches — skip (already correct)
3. If the file has `date_cleared` that differs — warn the user and ask before overwriting
4. Add `- **Cleared:** {date}` to the Transaction Summary section in the note body (after the `- **Date:**` line), if not already present
5. Add `- **Statement:** [[{statement_wikilink}]]` to the Transaction Summary section (after the `- **Cleared:**` line), if not already present

**Statement wikilink format** — derived from the Paperless storage path template:
`{MM} - {Correspondent Name} - {Title}`

Examples:
- Baselane Feb 2026 Operating: `[[02 - Baselane - Operating Account.pdf]]`
- Amex Feb 2026: `[[02 - American Express - Blue Business Plus.pdf]]`

Use `sed` for simple insertions. Use the Edit tool for cases where surrounding context is needed.

---

### Step 5b: Ensure `baselane: true` on All Matched Files

For every matched file (both debits and credits/contributions), check that `baselane: true` is set in the frontmatter. If it is missing or set to `false`, update it:

```bash
sed -i '' 's/^baselane: false$/baselane: true/' "{file_path}"
```

If the `baselane:` field is absent entirely, add it before the `llc:` line:

```bash
sed -i '' 's/^llc:/baselane: true\nllc:/' "{file_path}"
```

This applies to **all** matched files — expense debits, member contributions, and transfer-ins. The `baselane: true` flag ensures future reconciliations can match these files correctly.

---

### Step 6: Flag Missing Expense Notes

For each unmatched statement transaction:
- If it's a **Baselane credit/transfer-in** and no contribution file exists → suggest creating one via the `/transfer` skill
- If it's a **charge/debit** and no expense file exists → suggest creating one via the `/expense` skill
- Show the user the details so they can decide

Do NOT auto-create missing files. Only flag them.

---

### Step 7: Regenerate Ledger and Verify

```bash
python3 /Users/jasoncrews/Documents/Unified/generate_ledger.py > "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger"
```

Verify no parse errors:
```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" bal -N 2>&1 | tail -5
```

Show count of cleared transactions updated.

---

### Step 8: Upload Statement to Paperless-NGX

Upload the statement PDF to Paperless for permanent record keeping.

**Determine the title and created date from the statement:**
- **Title** — just the account/product name; the Paperless storage path template prepends `{MM} - {Correspondent} -` automatically
  - Baselane: account name only, e.g. `Operating Account`
  - Amex: product name only, e.g. `Blue Business Plus`
- **Created date** — use the statement's closing/cycle-end date (e.g. `2026-02-22`), NOT today's date

**Obsidian wikilink** for use in matched expense notes: `{MM} - {Correspondent Name} - {Title}` — this matches the Paperless filename after Syncthing sync.

**Look up or create the correspondent:**
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/correspondents/?{lookup_query}"
```

If the correspondent doesn't exist, create it:
```bash
curl -s -X POST "https://internal-paperless.gofer.cloud/api/correspondents/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -H "Content-Type: application/json" \
  -d '{"name": "{Correspondent Name}"}'
```

**If the statement path contains spaces, copy to /tmp first:**
```bash
cp "{original_path}" /tmp/statement_upload.pdf
```

**Upload the statement:**
```bash
curl -s -X POST "https://internal-paperless.gofer.cloud/api/documents/post_document/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -F "document=@/tmp/statement_upload.pdf" \
  -F "title={title}" \
  -F "document_type=8" \
  -F "storage_path=13" \
  -F "created={YYYY-MM-01}" \
  -F "correspondent={correspondent_id}" \
  -F 'custom_fields={"2": "7tmUdxi30uhfZCKb"}'
```

Confirm the upload succeeded (API returns a `task_id`). If it fails, warn the user and do NOT delete the file — let them retry manually.

---

### Step 9: Security Cleanup

Only after Paperless upload is confirmed, discard statement data from context.

```bash
rm -f /tmp/statement_upload.pdf /tmp/statement_*
```

Report: "Statement saved to Paperless and data cleared from memory. All matched transactions have been marked as cleared."

---

## Matching Heuristics

| Situation | Action |
|-----------|--------|
| Transfer-in matches a member contribution file by amount and date ±1 day | Match |
| Debit matches expense file by exact amount and date ±3 days | Match |
| Amex charge matches expense file `total_amount` (not posting amount) | Match |
| Multiple files match same amount | Show all candidates, ask user to pick |
| Statement shows a fee with no matching file | Flag as missing |
| Statement credit is rent income | Match to Income Dir files |
| Amount matches but date is off by >3 days | Fuzzy match — show to user |

## Error Handling

- **PDF unreadable** — try extracting text with pdfplumber via Bash before using Read tool
- **Ambiguous match** — always ask, never assume
- **File already cleared with different date** — warn and require explicit confirmation to overwrite
- **Ledger errors after update** — show the error, identify the offending file, fix before reporting success
- **Statement path has spaces** — always copy to `/tmp/statement_upload.pdf` before curl upload
