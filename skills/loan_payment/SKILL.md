---
name: loan_payment
description: Record a loan or credit card payment from a payment confirmation. Accepts a Paperless-ngx document URL, reads the confirmation, extracts payment data, and generates a structured Obsidian transaction file with double-entry postings.
---

Process a payment confirmation from Paperless-ngx into a structured Obsidian transaction file for loan/credit card payments.

## Constants

| Key | Value |
|-----|-------|
| Paperless API Base | `https://internal-paperless.gofer.cloud/api` |
| Paperless API Fallback | `http://192.168.39.25:8000/api` |
| Auth Header | `Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3` |
| Expense Output Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses` |
| Default LLC Wikilink | `[[Entity - 5450 E McLellan Rd Unit 227, LLC\|5450 E McLellan Rd Unit 227, LLC]]` |
| Default Property Short | `5450` |
| Temp Dir | `/tmp/paperless_preview` |

## Liability Accounts

| Alias | Account | Description |
|-------|---------|-------------|
| `amex` | `Liabilities:Credit:AmexBusinessPlus` | Amex Business Plus credit card |
| `mortgage` | `Liabilities:Property:5450:Mortgage` | UWM mortgage |

## Payment Source Accounts

| Alias | Account | Description |
|-------|---------|-------------|
| `operating` | `Assets:Banking:Baselane:checking:operating` | LLC operating checking |
| `capex` | `Assets:Banking:Baselane:checking:capex` | Capital expenditure reserve |
| `vacancy` | `Assets:Banking:Baselane:checking:VacancyReserve` | Vacancy reserve |
| `jason` | `Liabilities:Members:Jason:Owed:Transfer` | Jason personal funds |
| `shannon` | `Liabilities:Members:Shannon:Owed:Transfer` | Shannon personal funds |

## Instructions

Parse "$ARGUMENTS" to determine the input mode. Try each in order:

**Mode A — Paperless URL or ID:** If the argument contains `/documents/` or is a plain number, extract the document ID and follow Steps 1–2 normally.

**Mode B — Natural language or inline text:** Everything else. Parse conversational input to extract as much as possible before asking questions. Examples of supported forms:

- `"record the mortgage payment $1,842 from operating"` → liability: mortgage, amount, source: operating
- `"Amex payment $500 from Baselane"` → liability: amex, amount, source: operating
- `"mortgage payment, $1,800 principal $42 interest from operating"` → with principal/interest split
- `"paid the Amex bill $650 from LLC checking"` → liability: amex, amount, source: operating
- `"Jason paid the mortgage $1,842 personally"` → liability: mortgage, amount, source: jason

Extract from natural language:
- **Liability** — "mortgage", "Amex", "credit card" → map to Liability Accounts table
- **Amount** — total payment amount
- **Principal / Interest split** — if both mentioned, extract separately
- **Payment source** — "from operating", "from Baselane", "personally", member name → map to Payment Source Accounts table
- **Date** — if mentioned; otherwise default to today

Skip any Step 3 questions already answered. Only ask what's still missing.

**If no argument or empty:** Ask the user to describe the payment or provide a Paperless document URL.

Then execute these steps in order:

---

### Step 1: Fetch Document Metadata

Run via Bash:
```bash
mkdir -p /tmp/paperless_preview
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/documents/{DOC_ID}/" \
  -o /tmp/paperless_preview/doc_{DOC_ID}_meta.json
```

If the primary URL fails, retry with fallback `http://192.168.39.25:8000/api/documents/{DOC_ID}/`.

Read the JSON and extract:
- `title` — document title
- `correspondent` — creditor name (resolve via `/api/correspondents/{id}/` if numeric)
- `created_date` — document date
- `tags` — array of tag IDs (resolve names via `/api/tags/?page_size=100`)
- `original_file_name` — for receipt wikilink

---

### Step 2: Download and Read the Payment Confirmation

Download the document preview:
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -o /tmp/paperless_preview/doc_{DOC_ID}_preview.png \
  "https://internal-paperless.gofer.cloud/api/documents/{DOC_ID}/preview/"
```

Check if the file is actually a PDF:
```bash
file /tmp/paperless_preview/doc_{DOC_ID}_preview.png
```

If it's a PDF, rename to `.pdf`. If the preview fails, try the thumbnail endpoint.

Use the Read tool to view the downloaded image/PDF. Extract:
- **Date** of the payment
- **Amount** paid
- **Creditor/Payee** (credit card company, mortgage servicer, etc.)
- **Payment source** (which bank account, confirmation number)
- **Remaining balance** (if shown)
- **Check number** — if the document is a physical check (look for check number in corner, "NOT NEGOTIABLE", "DUP-", or "DUPLICATE" indicators), set `IS_CHECK = true` and record the check number

Cross-reference with Paperless metadata.

---

### Step 3: Present Data and Ask for Missing Fields

Show extracted data:

```
## Payment Confirmation Data (Extracted)
- Date: YYYY-MM-DD
- Creditor: Name
- Amount Paid: $XX.XX
- Payment Source: (if visible)
- Confirmation #: (if visible)
- Remaining Balance: (if visible)
```

Then use AskUserQuestion to gather/confirm:

1. **Description** — short title (suggest based on data, e.g., "Amex Bill Pay from Baselane")
2. **Liability being paid** — Which account? Options from Liability Accounts table.
3. **Payment source** — Which account funded the payment? Options from Payment Source Accounts table.
4. **Date** — confirm or override the extracted date

**If `IS_CHECK = true`**, also ask in the same AskUserQuestion call:

5. **Mailing date** — date the check was mailed (suggest today's date)
6. **Tracking number** — USPS or other carrier tracking number (optional, leave blank if not available)

---

### Step 4: Build Accounting Postings

The payment reduces a liability (debit / positive) and reduces an asset (credit / negative):

```yaml
postings:
  - account: "{liability_account}"
    amount: {amount}
    note: "Payment on {creditor_name}"
  - account: "{payment_source_account}"
    amount: -{amount}
    note: "Paid from {source_display}"
```

**Tags:**
- Always: `banking`
- Credit card payment: add `credit-card`
- Mortgage payment: add `mortgage`
- If paid by member personally: add `member-contribution`

**paid_by:** `"LLC"` if paid from Baselane, member name if paid personally.

---

### Step 5: Generate the Transaction File

**Filename:** `{YYYY-MM-DD} - {Description}.md`
**Path:** `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses/{filename}`

Before writing, check if a file with the same name already exists.

**Receipt wikilink:** Build from Paperless metadata using the storage path pattern: `{created_date} - {correspondent_name} - {title}.pdf`. Format as `[[receipt_filename]]`.

Show the user the complete file for confirmation, then write it using the Write tool.

**File format:**

```
---
type: transaction
date: {YYYY-MM-DD}
description: "{description}"
total_amount: {amount}
paid_by: "{paid_by}"
tags: [{tag_list}]
postings:
  - account: "{liability_account}"
    amount: {amount}
    note: "Payment on {creditor_name}"
  - account: "{payment_source_account}"
    amount: -{amount}
    note: "Paid from {source_display}"
receipt: "[[{receipt_filename}]]"
llc: "{llc_wikilink}"
{if IS_CHECK}check_number: "{check_number}"
{/if IS_CHECK}---

# {description}

## Transaction Summary
- **Creditor:** {creditor_name}
- **Amount Paid:** ${formatted_amount}
- **Date:** {YYYY-MM-DD}
- **Payment Source:** {source_display}
- **Confirmation:** {confirmation_number_if_available}
- **Receipt:** [[{receipt_filename}]]
{if IS_CHECK}- **Check #:** {check_number}
- **Mailed:** {mailing_date}
{if tracking_number}- **Tracking:** {tracking_number}
{/if tracking_number}{/if IS_CHECK}

## Accounting Postings
| Account | Amount | Note |
| :--- | :--- | :--- |
| `{liability_account}` | **${amount}** | Payment on {creditor_name} |
| `{payment_source_account}` | -${amount} | Paid from {source_display} |

## Related
- [[R01 - Rentals/Expenses/_Expense Dashboard|Expense Dashboard]]
```

---

### Step 6: Regenerate Ledger and Verify

```bash
python3 /Users/jasoncrews/Documents/Unified/generate_ledger.py > "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger"
```

Verify with hledger:
```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" print date:{YYYY-MM-DD} desc:{keyword}
```

Balance check:
```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" bal -N
```

If hledger reports errors, fix the file and re-verify.

Show the user the hledger `print` output as confirmation.

---

### Step 7: Cleanup

After verification:
```bash
rm -f /tmp/paperless_preview/doc_{DOC_ID}_*
```

Report success with the full file path and ledger verification results.

## Mortgage Payment Note

> **⚠️ Account name warning:** The payment source for a mortgage paid from Baselane is **always** `Assets:Banking:Baselane:checking:operating`. Never append `:mortgage` or any other sub-segment to this account — doing so creates a phantom sub-account that inflates the operating balance without the cash ever leaving it. The word "mortgage" belongs only in `Liabilities:Property:5450:Mortgage` (principal) and `Expenses:Property:5450:Operating:Mortgage:Interest` (interest), never in the asset account path.

For mortgage payments, the monthly payment typically includes **principal** and **interest**. If the payment confirmation shows a principal/interest breakdown:

```yaml
postings:
  - account: "Liabilities:Property:5450:Mortgage"
    amount: {principal_amount}
    note: "Principal payment"
  - account: "Expenses:Property:5450:Operating:Mortgage:Interest"
    amount: {interest_amount}
    note: "Interest expense"
  - account: "{payment_source_account}"
    amount: -{total_payment}
    note: "Paid from {source_display}"
```

If escrow is also broken out (taxes, insurance), add those as separate postings to appropriate expense accounts.

## Error Handling

- **API unreachable:** Try fallback IP `192.168.39.25:8000`. If both fail, suggest checking with `/infra services`.
- **Document not found (404):** Ask user to verify the document ID/URL.
- **Preview unreadable:** Try `/thumb/` endpoint. If still unreadable, ask user to describe the payment.
- **File already exists:** Warn user and ask to overwrite or change description.
- **Unrecognized liability:** Show the Liability Accounts table and ask user to pick or provide a full account path.
