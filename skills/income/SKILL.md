---
name: income
description: Record rental income, rent payments, late fees, or security deposits for the LLC "5450 E McLellan Rd Unit 227, LLC". Use this skill whenever the user mentions rent received, tenant payment, security deposit, income recorded, or any money coming INTO the LLC — even if they don't say "income" explicitly. Accepts a local image/PDF file path, a Paperless document URL/ID, or natural language like "rent received $1500 from tenant April".
---

Record rental income into a structured Obsidian income file for the LLC with double-entry accounting postings.

## Constants

| Key | Value |
|-----|-------|
| Paperless API Base | `https://internal-paperless.gofer.cloud/api` |
| Paperless API Fallback | `http://192.168.39.25:8000/api` |
| Auth Header | `Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3` |
| Income Output Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Income` |
| Default LLC Wikilink | `[[Entity - 5450 E McLellan Rd Unit 227, LLC\|5450 E McLellan Rd Unit 227, LLC]]` |
| Default Property Wikilink | `[[Property - 5450 E McLellan Rd 227, Mesa AZ 85205\|5450 E McLellan Rd 227]]` |
| Temp Dir | `/tmp/paperless_preview` |

## Income Accounts

| Type | Account | Notes |
|------|---------|-------|
| Rent | `Income:Property:5450:Rent` | Monthly rent from tenant |
| Late Fee | `Income:Property:5450:LateFees` | Late payment fee charged to tenant |
| Earnest Money | `Income:Property:5450:Other` | Non-refundable — income at receipt. If tenant later takes possession, reclassify: debit `Income:Property:5450:Other`, credit `Liabilities:Deposits:Security` |
| Security Deposit | `Liabilities:Deposits:Security` | Liability — NOT income until applied. Only use this for deposits that may be refunded. |
| Pet Deposit | `Liabilities:Deposits:Pet` | Liability — NOT income until applied |
| Cleaning Deposit | `Liabilities:Deposits:Cleaning` | Liability — NOT income until applied |
| Other | `Income:Property:5450:Other` | Sales, reimbursements, misc |

**Income accounts are always negative** in hledger (credit/income convention). The offsetting debit depends on how funds were received.

## Offset Accounts (How Funds Were Received)

| Method | Account | Amount (debit) |
|--------|---------|----------------|
| Baselane deposit | `Assets:Banking:Baselane:checking:operating` | +amount |
| Cash | `Assets:Cash` | +amount |
| Applied to member liability | `Liabilities:Members:{Member}:Owed:{category}` | +amount |

## Deposit Special Case

Deposits (Security, Pet, Cleaning) are **liabilities**, not income — the LLC holds them on behalf of the tenant and may be required to return them.

| Deposit Type | Account |
|---|---|
| Security | `Liabilities:Deposits:Security` |
| Pet | `Liabilities:Deposits:Pet` |
| Cleaning | `Liabilities:Deposits:Cleaning` |

**When received:**
```
Assets:Banking:Baselane:checking:operating   +amount
Liabilities:Deposits:{Type}                 -amount
```

**When applied** (e.g., to cover unpaid rent or damage at move-out):
```
Liabilities:Deposits:{Type}                 +amount
Income:Property:5450:Rent                   -amount  (or appropriate income/expense account)
```

**When refunded** (tenant moves out, deposit returned):
```
Liabilities:Deposits:{Type}                 +amount
Assets:Banking:Baselane:checking:operating  -amount
```

Always clarify whether the user is recording receipt, application, or refund of a deposit.

---

## Instructions

Parse "$ARGUMENTS" to determine the input mode:

**Mode A — Image or PDF file path:** Argument starts with `/` or `~`, or ends in `.png`, `.jpg`, `.jpeg`, `.pdf`, `.heic`, `.webp`. Read the file directly, then upload to Paperless in Step 6b.

**Mode B — Paperless URL or ID:** Argument contains `/documents/` or is a plain number. Fetch via API in Steps 1–2.

**Mode C — Natural language:** Everything else. Extract as much as possible before asking questions. Examples:
- `"rent received $1,500 from tenant April"` → type: Rent, amount, period
- `"$500 security deposit received from tenant"` → type: Security Deposit
- `"late fee $75 paid by tenant"` → type: Late Fee
- `"$25 cash from fixture sale"` → type: Other

Skip Step 3 questions already answered from natural language.

**If no argument:** Ask the user to describe the income, provide a file path, or paste a Paperless URL.

---

### Step 1: Fetch Document Metadata (Mode B only)

```bash
mkdir -p /tmp/paperless_preview
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/documents/{DOC_ID}/" \
  -o /tmp/paperless_preview/doc_{DOC_ID}_meta.json
```

If the primary URL fails, retry with `http://192.168.39.25:8000/api/documents/{DOC_ID}/`.

Extract: `title`, `correspondent`, `created_date`, `tags`, `original_file_name`.

---

### Step 2: Download and Read the Document (Mode B only)

```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -o /tmp/paperless_preview/doc_{DOC_ID}_preview.png \
  "https://internal-paperless.gofer.cloud/api/documents/{DOC_ID}/preview/"
file /tmp/paperless_preview/doc_{DOC_ID}_preview.png
```

Rename to `.pdf` if needed. If preview fails, try `/thumb/`. Use Read tool to view. Extract date, amount, payer, description.

---

### Step 2b: Read Local File (Mode A only)

Use the Read tool to view the file directly. Extract:
- Date of payment
- Tenant/payer name
- Amount
- Payment type (rent, deposit, fee)
- Lease period if visible
- Confirmation or reference number

Set `SOURCE_IMAGE` to the file path for use in Step 6b.

---

### Step 3: Present Extracted Data and Ask for Missing Fields

Show what was extracted, then use AskUserQuestion to gather/confirm:

1. **Income type** — Rent / Late Fee / Security Deposit / Other
2. **Description** — short title (suggest based on type and tenant, e.g., "Rent Payment - April 2026")
3. **Tenant name** — required for Rent, Late Fee, Security Deposit
4. **Lease period** — month/year for rent (e.g., "April 2026")
5. **Amount received**
6. **How received** — Baselane deposit / Cash / Other
7. **Date received** — confirm or override extracted date
8. **Status** — Has the payment cleared? If yes, set `status: cleared` and `date_cleared: {date}` (same as date received unless otherwise stated). If not yet settled, set `status: pending` and omit `date_cleared`. **Both fields must be set together** — `status: cleared` without `date_cleared` will NOT produce a `*` marker in hledger.

For security deposits, clarify whether this is **receiving** the deposit or **applying** it.

---

### Step 4: Build Accounting Postings

#### Standard income (Rent, Late Fee, Other):

```yaml
postings:
  - account: "{income_account}"
    amount: -{total}
    note: "{description}"
  - account: "{offset_account}"
    amount: {total}
    note: "Received via {method}"
```

#### Security deposit received:

```yaml
postings:
  - account: "Assets:Banking:Baselane:checking:operating"
    amount: {total}
    note: "Security deposit received from {tenant}"
  - account: "Liabilities:Deposits:Security"
    amount: -{total}
    note: "Security deposit held for {tenant}"
```

#### Security deposit applied:

```yaml
postings:
  - account: "Liabilities:Deposits:Security"
    amount: {total}
    note: "Security deposit applied"
  - account: "{income_or_expense_account}"
    amount: -{total}
    note: "{reason for application}"
```

#### Tags:
- Always: `rental`
- Rent: add `rent`
- Security deposit: add `deposit`
- Other income: add `income`
- Received via Baselane: add `baselane-deposit`

**`baselane:`** — set `true` if received via Baselane, `false` if cash or other.

---

### Step 5: Show Full File for Confirmation

**Before writing anything**, display the complete file content:

```
Here is the note that will be saved. Please confirm or let me know what to change:

---
[full file content]
---
```

Use AskUserQuestion with options: **Looks good — save it** / **Make changes** / **Cancel**.

Only proceed once the user confirms.

---

### Step 6: Write the Income File

**Filename:** `{YYYY-MM-DD} - {Description}.md`
**Path:** `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Income/{filename}`

Check if the file already exists before writing. If so, warn the user.

**Receipt wikilink:** For Mode B, build from Paperless metadata: `{created_date} - {correspondent_name} - {title}.pdf`. For Mode A, build after upload in Step 6b. For natural language with no document, omit or set `receipt: "N/A"`.

**File format:**

```
---
type: transaction
date: {YYYY-MM-DD}
description: "{description}"
payee: "{tenant_or_payer}"
total_amount: {amount}
status: {pending|cleared}
date_cleared: {YYYY-MM-DD if cleared, omit if pending}
tags: [{tag_list}]
postings:
{postings_yaml}
receipt: "[[{receipt_filename}]]"
baselane: {true_or_false}
llc: "{llc_wikilink}"
---

# {description}

## Transaction Summary
- **Type:** {income_type}
- **Payee:** {tenant_or_payer}
- **Amount:** ${formatted_amount}
- **Date:** {YYYY-MM-DD}
{if rent}- **Lease Period:** {lease_period}
{/if rent}- **Received Via:** {method}
{if receipt}- **Receipt:** [[{receipt_filename}]]
{/if receipt}

## Accounting Postings
| Account | Amount | Note |
| :--- | :--- | :--- |
{posting_table_rows}

## Property Details
- **Property:** {property_wikilink}
- **Category:** {income_type}

## Related
- [[R01 - Rentals/Expenses/_Expense Dashboard|Expense Dashboard]]
```

---

### Step 6b: Upload to Paperless (Mode A only)

If `SOURCE_IMAGE` was provided, upload after writing the income file.

**Look up correspondent** (tenant name):
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/correspondents/?name__iexact={tenant_name}" | \
  python3 -c "import sys,json; r=json.load(sys.stdin); print(r['results'][0]['id'] if r['results'] else 'none')"
```

If not found, create:
```bash
curl -s -X POST "https://internal-paperless.gofer.cloud/api/correspondents/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -H "Content-Type: application/json" \
  -d '{"name": "{tenant_name}"}'
```

**Upload:**
```bash
curl -s -X POST "https://internal-paperless.gofer.cloud/api/documents/post_document/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -F "document=@{SOURCE_IMAGE}" \
  -F "title={YYYY-MM-DD} - {Description}" \
  -F "document_type=2" \
  -F "storage_path=4" \
  -F "created={YYYY-MM-DD}" \
  -F "correspondent={CORRESPONDENT_ID}"
```

**Add property custom field** — find the new document ID, then PATCH:
```bash
# Find the newly uploaded doc
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/documents/?correspondent__id={CORRESPONDENT_ID}&ordering=-added&page_size=3" | \
  python3 -c "import sys,json; r=json.load(sys.stdin); [print(x['id'], x['title']) for x in r['results']]"

# Patch property field
curl -s -X PATCH "https://internal-paperless.gofer.cloud/api/documents/{DOC_ID}/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -H "Content-Type: application/json" \
  -d '{"custom_fields": [{"field": 2, "value": "7tmUdxi30uhfZCKb"}]}'
```

**Update the income note** with the receipt wikilink: `[[{YYYY-MM-DD} - {Tenant} - {Description}.pdf]]`

---

### Step 7: Regenerate Ledger and Verify

```bash
python3 /Users/jasoncrews/Documents/Unified/generate_ledger.py > "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger"
```

Verify:
```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" print date:{YYYY-MM-DD} desc:{keyword}
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" bal -N
```

Show the `print` output to confirm the transaction was recorded correctly.

---

### Step 8: Cleanup

```bash
rm -f /tmp/paperless_preview/doc_{DOC_ID}_*
```

Report success with the full file path and hledger confirmation.

---

## Error Handling

- **API unreachable:** Try fallback `192.168.39.25:8000`. If both fail, suggest `/infra services`.
- **Tenant not in Paperless:** Create correspondent via POST before uploading.
- **Security deposit ambiguity:** Always clarify whether the user is recording receipt vs. application of the deposit.
- **File already exists:** Warn and ask to overwrite or adjust description.
- **Amount unclear:** Never assume — always confirm the exact amount before writing.
