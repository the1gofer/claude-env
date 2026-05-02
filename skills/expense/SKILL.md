---
name: expense
description: Process a receipt from Paperless-ngx into an Obsidian rental expense file. Accepts a Paperless document URL, reads the receipt, extracts transaction data, and generates a formatted expense entry with double-entry accounting postings.
---

Process a Paperless-ngx receipt into a structured Obsidian expense file for rental property accounting.

## Constants

| Key | Value |
|-----|-------|
| Paperless API Base | `https://internal-paperless.gofer.cloud/api` |
| Paperless API Fallback | `http://192.168.39.25:8000/api` |
| Auth Header | `Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3` |
| Expense Output Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses` |
| Default Property Wikilink | `[[Property - 5450 E McLellan Rd 227, Mesa AZ 85205\|5450 E McLellan Rd 227]]` |
| Default LLC Wikilink | `[[Entity - 5450 E McLellan Rd Unit 227, LLC\|5450 E McLellan Rd Unit 227, LLC]]` |
| Default Property Short | `5450` |
| Members | Jason, Shannon |
| De Minimis Threshold | $2,500 |
| Temp Dir | `/tmp/paperless_preview` |

## Instructions

Parse "$ARGUMENTS" to determine the input mode. Try each mode in order:

**Mode A — Image file path:** If the argument contains a file path (starts with `/` or `~`, or ends in `.png`, `.jpg`, `.jpeg`, `.pdf`, `.heic`, `.webp`), treat it as a local receipt image. Skip Steps 1–2 and go to Step 2b, then upload in Step 6b.

**Mode B — Paperless URL or ID:** If the argument contains `/documents/` or is a plain number, extract the document ID and follow Steps 1–2 normally.

**Mode C — Natural language or inline text:** Everything else. Parse conversational input to extract as much as possible before asking questions. Examples of supported forms:

- `"Jason paid $4.12 at Salad and Go"` → vendor, amount, payer
- `"record a meal, Home Depot supplies $47, Shannon paid"` → vendor, amount, payer, category hint
- `"$150 supplies from Home Depot, paid from Baselane"` → amount, vendor, category, payment flow
- `"mortgage payment $1,800 from Baselane"` → amount, description, payment flow
- `"Salad and Go $4.12 Jason personal card"` → vendor, amount, payer, payment source

Extract from natural language:
- **Vendor/payee** — proper noun, store name, or description
- **Amount** — any dollar figure
- **Who paid** — member name if mentioned ("Jason paid", "Shannon bought")
- **Payment flow** — "from Baselane", "via Baselane", "personal", "out of pocket", "his card", "her card"
- **Category hint** — "meal", "supplies", "HOA", "insurance", etc.
- **Date** — if mentioned; otherwise default to today

Skip any Step 3 questions that are already answered from the natural language. Only ask what's still missing.

**If no argument or empty:** Ask the user to describe the transaction, paste a Paperless URL, or provide a receipt file path.

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

Read the JSON response and extract:
- `title` — document title
- `correspondent` — vendor/payee name (may be a numeric ID; resolve via `/api/correspondents/{id}/`)
- `created_date` — document date
- `tags` — array of tag IDs
- `custom_fields` — any custom fields (check for property assignments)
- `original_file_name` — original uploaded filename (for receipt wikilink)

If tags are present, resolve names:
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/tags/?page_size=100"
```

Look for tags indicating:
- **Property** (e.g., "5450", "McLellan") — determines which property entity to use
- **Category hints** (e.g., "capital", "operating", "renovation")

---

### Step 2: Download and Read the Receipt

Download the document preview:
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -o /tmp/paperless_preview/doc_{DOC_ID}_preview.png \
  "https://internal-paperless.gofer.cloud/api/documents/{DOC_ID}/preview/"
```

Check if the file is actually a PDF (Paperless may return PDF for preview):
```bash
file /tmp/paperless_preview/doc_{DOC_ID}_preview.png
```

If it's a PDF, rename to `.pdf`. If the preview fails, try the thumbnail:
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -o /tmp/paperless_preview/doc_{DOC_ID}_thumb.png \
  "https://internal-paperless.gofer.cloud/api/documents/{DOC_ID}/thumb/"
```

Use the Read tool to view the downloaded image/PDF. Extract from the receipt:
- **Date** of the transaction
- **Vendor/Payee** name
- **Total amount** paid
- **Line items** (individual items, quantities, prices)
- **Payment method** visible on receipt (card ending, cash, etc.)
- **Check number** — if the document is a physical check (look for check number in corner, "NOT NEGOTIABLE", "DUP-", or "DUPLICATE" indicators), set `IS_CHECK = true` and record the check number

Cross-reference with Paperless metadata:
- If `correspondent` is set, prefer it as the standardized vendor name
- If receipt date differs from Paperless `created_date`, prefer the receipt date

---

### Step 2b: Read Local Image (Mode A / Mode C)

If a local file path was provided instead of a Paperless URL, use the Read tool to view the image directly. Extract:
- **Date** of the transaction
- **Vendor/Payee** name
- **Total amount**
- **Line items** (if visible)
- **Payment method / account** (if visible)

Set `SOURCE_IMAGE` to the provided file path for use in Step 5b.

---

### Step 3: Present Extracted Data and Ask for Missing Fields

Show the user what was extracted:

```
## Receipt Data (Extracted)
- Date: YYYY-MM-DD
- Vendor: Name
- Total: $XX.XX
- Items: item list
- Receipt file: original_file_name

## Paperless Metadata
- Correspondent: (if set)
- Tags: tag1, tag2
- Property: (from tags/custom fields, or "5450" default)
```

Then ask the user for accounting fields using AskUserQuestion. Always ask:

1. **Description** — short title for the expense file (suggest based on receipt content)
2. **Category** — Operating or Capital?
3. **Project** — PreRentalRenno, General, Maintenance, etc.
4. **Subcategory** — see Account Path Reference below
5. **Payment flow** — This is the most critical question and determines how debt is tracked:
   - **Paid directly to vendor** (personal card, cash, check) — member paid out of pocket, debt recorded here
   - **Paid via Baselane** (LLC account) — LLC already funded via a transfer; debt lives on the transfer, NOT here
6. **Who paid** — Jason or Shannon. Ask if not clear from receipt. Only relevant when payment flow is direct.
7. **Payment source** — Personal card, Wells Card, Wealthfront, Cash, etc. Only relevant when payment flow is direct.

6b. **Cleared date** — do NOT ask for this. Leave `date_cleared:` absent from the frontmatter when creating new expenses. The user will provide a bank statement later to backfill cleared dates in bulk. When `date_cleared` is present, `generate_ledger.py` emits `{date}={date_cleared} *` hledger syntax automatically.

**If `IS_CHECK = true`**, also ask in the same AskUserQuestion call:

7. **Mailing date** — date the check was mailed (suggest today's date)
8. **Tracking number** — USPS or other carrier tracking number (optional, leave blank if not available)
9. **Postage** — stamp + envelope cost for mailing the check. Default is $1.13 ($0.78 stamp + $0.35 envelope). Confirm amount or adjust if different. This will generate a separate postage expense note paid personally by the member who mailed it.

If Category is Capital, also determine:
7. **Depreciation life** — see Depreciation Reference below
8. **De minimis** — default true if total under $2,500

---

### Step 3a: Business Justification (Meals only)

If the subcategory is **Meals**, look up mileage log entries for the transaction date before writing the file:

```bash
grep -rl "date: {YYYY-MM-DD}" "/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Mileage/"
```

If mileage files are found, read each one and extract:
- `purpose` — reason for the trip (e.g., Maintenance, Vendor Meeting, Property Inspection)
- `miles` — total miles driven
- `start_location` / `end_location` — route taken

Propose a business justification based on the trips found:
- Single trip: `"Working meal during {purpose} trip to 5450 E McLellan Rd ({miles} mi round trip). Business purpose: {purpose}."`
- Multiple trips: `"Working meal during {purpose1} and {purpose2} trips to 5450 E McLellan Rd. Business purpose: {combined description}."`

If no mileage entries are found, use the description/project context to propose a justification and note that no mileage log entry exists.

Present the proposed justification to the user in the Step 3 AskUserQuestion (add it as an additional field to confirm). Include it as `- **Business Justification:** {text}` in the Transaction Summary section of the expense note (after the `- **Date:**` line).

---

### Step 4: Build Accounting Postings

#### Expense account path:

For Operating:
```
Expenses:Property:{PROP_ID}:Operating:{Subcategory}
```

For Capital:
```
Expenses:Property:{PROP_ID}:CapitalImprovements:{Project}:{Subcategory}
```

#### Payment postings — paid directly to vendor (personal funds):

The member paid out of pocket. The LLC records the **full amount** as a liability owed to that member. Do NOT pre-split. The other member's reimbursement will be a separate future transaction.

```yaml
postings:
  - account: "{expense_account}"
    amount: {total}
    note: "{description}"
  - account: "Liabilities:Members:{paidBy}:Owed:{Subcategory}"
    amount: -{total}
    note: "Full payment advanced by {paidBy} ({payment_source}) — {otherMember} reimbursement pending"
```

#### Payment postings — paid via Baselane (LLC account):

The LLC was already funded via a member transfer. Debt lives on the transfer, not here. Just record the expense and the cash outflow — no liability posting.

```yaml
postings:
  - account: "{expense_account}"
    amount: {total}
    note: "{description}"
  - account: "Assets:Banking:Baselane:checking:operating"
    amount: -{total}
    note: "Paid from LLC checking"
```

**If payment source includes "Amex" or "Business Plus":**
Use `Liabilities:Credit:AmexBusinessPlus` instead of `Assets:Banking:Baselane:checking:operating`.

**Important:** Never record a member liability posting when the payment went through Baselane. The debt was already captured when the member funded the LLC via a transfer. Recording it again here would be a duplicate.

#### Tags:
- Always: `rental`
- Operating: add `operating`
- Capital: add `capital`
- Direct personal payment: add `llc-liability`
- Paid via Baselane: add `llc-expense`

#### Refunds (negative amounts):
Reverse all posting signs. Confirm with user that this is a return/refund.

---

### Step 5: Show Full File for Confirmation

**Before writing anything**, display the complete file content to the user exactly as it will be saved:

```
Here is the note that will be saved. Please confirm or let me know what to change:

---
[full file content]
---
```

Use AskUserQuestion with options: **Looks good — save it** / **Make changes** / **Cancel**.

If the user wants changes, update the draft and show it again before writing.

Only proceed to write the file once the user explicitly confirms.

---

### Step 6: Write the Expense File

**Filename:** `{YYYY-MM-DD} - {Description}.md`
**Path:** `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses/{filename}`

Before writing, check if a file with the same name already exists. If so, warn and ask the user.

**Receipt wikilink — build and verify:**

1. Construct the candidate filename: `{created_date} - {correspondent_name} - {title}.pdf`
   - The separator between every segment is ` - ` (space-dash-space) — never a plain space
   - Correct: `2026-04-15 - USPS - 2026-04-15 - USPS Change-of-Address Fee - Jason.pdf`
   - Broken: `2026-04-15 USPS 2026-04-15 - USPS Change-of-Address Fee - Jason.pdf`

2. **Verify the file exists** in the vault before using it:
   ```bash
   ls "/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Receipts/{YYYY}/" | grep -F "{candidate_filename}"
   ```
   If not found, search more broadly:
   ```bash
   find "/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Receipts" -name "*{partial_title}*"
   ```
   Use the **actual filename returned** by the search — not the constructed candidate. Set `receipt: ""` if the file cannot be found (do not invent a link).

3. Format the wikilink: `[[{actual_filename}]]` (no path needed — Obsidian resolves by filename across the vault)

**Paperless URLs in expense notes:** Only the `tracking_paperless:` frontmatter field and the `**Tracking:**` body line should reference Paperless URLs. The `receipt:` field must always be an Obsidian wikilink or empty — never `http://...`.

**Important:** HOA payment coupons and bills used as receipts for check payments must be filed in Paperless under **Receipts path (ID 4)**, not Bills (14), so they sync to the Obsidian Receipts folder and the wikilink resolves. Update the Paperless storage path via PATCH if needed.

## Naming Conventions

### HOA Payment Notes

Monthly AMRV HOA: `{YYYY-MM-DD} - Alta Mesa Resort Village HOA - {YYYY-MM}.md`
- `{YYYY-MM-DD}` = transaction date (when check was mailed or online payment made)
- `{YYYY-MM}` = billing period covered (e.g., `2026-05` for May 2026 assessment)
- Internal `description:` and H1 heading must match: `"Alta Mesa Resort Village HOA - {YYYY-MM}"`

Quarterly Alta Mesa HOA: `{YYYY-MM-DD} - Alta Mesa HOA - {period}.md`
- `{period}` = quarter(s) covered (e.g., `2026-Q1-Q2` for Q1+Q2 paid together)

### Postage Notes (Mailed Check Payments)

`{YYYY-MM-DD} - Postage - {HOA Name} Payment - {period}.md`
- `{YYYY-MM-DD}` = date the check was mailed
- `{HOA Name}` = same HOA name used in the main payment note
- `{period}` = billing period the mailed check covers (same as the main HOA payment note)
- Internal `description:` and H1 must match the filename stem: `"Postage - {HOA Name} Payment - {period}"`

**File format:**

```
---
type: transaction
date: {YYYY-MM-DD}
{if cleared_date}date_cleared: {cleared_date}
{/if}description: "{description}"
payee: "{vendor}"
total_amount: {amount}
paid_by: {paidBy}
tags: [{tag_list}]
postings:
{postings_yaml}
receipt: "[[{created_date} - {correspondent_name} - {title}.pdf]]"
{depreciation_life_line_if_capital}
baselane: {true_or_false}
llc: "{llc_wikilink}"
{if IS_CHECK}check_number: "{check_number}"
tracking: "{tracking_number_or_blank}"
tracking_paperless: "{paperless_url_or_blank}"
{/if IS_CHECK}---

# {description}

## Transaction Summary
- **Payee:** {vendor}
- **Total Amount:** ${formatted_amount}
- **Paid By:** {paidBy}
- **Date:** {YYYY-MM-DD}
{if cleared_date}- **Cleared:** {cleared_date}
{/if cleared_date}- **Project:** {project_display}
- **Receipt:** [[{created_date} - {correspondent_name} - {title}.pdf]]
{if IS_CHECK}- **Check #:** {check_number}
- **Mailed:** {mailing_date}
{if tracking_number}- **Tracking:** [{tracking_number}]({paperless_tracking_url})
{/if tracking_number}{if no tracking_number}- **Tracking:** *(to be added — file USPS tracking in Paperless and add URL here)*
{/if no tracking_number}{/if IS_CHECK}

## Accounting Postings
| Account | Amount | Note |
| :--- | :--- | :--- |
{posting_table_rows}

## Property Details
- **Property:** {property_wikilink}
- **Category:** {Operating Expense | Capital Improvement} ({subcategory})
{depreciation_line_if_capital}

## Related
- [[R01 - Rentals/Expenses/_Expense Dashboard|Expense Dashboard]]
- [[R01 - Rentals/Expenses/_Capital Expenses Report|Capital Expenses Report]]
```

**For capital expenses, add before `baselane:`:**
```yaml
depreciation_life: {5|15|27.5}
de_minimis: {true|false}
```

---

### Step 6a: Write Postage Expense Note (Mailed checks only)

**Only execute this step if `IS_CHECK = true`.**

After writing the main expense file, automatically create a companion postage expense note. Do not ask — this is always required for mailed check payments.

**Postage amount:** $1.13 by default ($0.78 stamp + $0.35 envelope). Use confirmed amount from Step 3 if different.

**Who paid:** The member who mailed the check (same as `paid_by` for the main note, or whichever member handled the mailing — ask if unclear).

**Filename:** `{YYYY-MM-DD} - Postage - {Payee} Payment - {period}.md`
- `{period}` = billing period the mailed check covers (e.g., `2026-05` for monthly HOA, `2026-Q1-Q2` for quarterly)

```
---
type: transaction
date: {YYYY-MM-DD}
description: "Postage - {Payee} Payment - {period}"
total_amount: {postage_amount}
paid_by: {paidBy}
tags:
  - office
  - member-contribution
postings:
  - account: Expenses:Property:5450:Operating:Office
    amount: {postage_amount}
    note: Stamp ($0.78) + envelope ($0.35) for {Payee} payment (check #{check_number})
  - account: Liabilities:Members:{paidBy}:Owed:Supplies
    amount: -{postage_amount}
    note: {paidBy} paid personally
receipt: ""
llc: "[[07 - Entity - 5450 E McLellan Rd Unit 227, LLC|5450 E McLellan Rd Unit 227, LLC]]"
baselane: false
---

# Postage - {Payee} Payment - {period}

## Transaction Summary
- **Description:** Stamp + envelope for {Payee} payment (check #{check_number})
- **Amount:** ${postage_amount} ($0.78 stamp + $0.35 envelope)
- **Date:** {YYYY-MM-DD}
- **Paid By:** {paidBy} (personal funds, non-cash reimbursement)

## Accounting Postings
| Account | Amount | Note |
| :--- | :--- | :--- |
| `Expenses:Property:5450:Operating:Office` | **${postage_amount}** | Stamp + envelope for {Payee} payment |
| `Liabilities:Members:{paidBy}:Owed:Supplies` | -${postage_amount} | {paidBy} paid personally |

## Related
- [[{main_expense_filename_without_extension}]]
- [[R01 - Rentals/Expenses/_Expense Dashboard|Expense Dashboard]]
```

**After filing the USPS tracking document** in Paperless, update the `receipt:` field in this postage note with the wikilink to the tracking PDF: `[[{tracking_doc_filename}.pdf]]`. The Paperless URL goes in the main HOA payment note's `tracking_paperless:` field only.

---

### Step 6b: Upload to Paperless-NGX (Mode A / image input only)

If a `SOURCE_IMAGE` was provided (local file path), upload it to Paperless-NGX after the expense file is written.

**Resolve the actual file path** (handles macOS Unicode/NFD normalization in Dropbox filenames):
```bash
ACTUAL_FILE=$(find "$(dirname '$SOURCE_IMAGE')" -maxdepth 1 -name "$(basename '$SOURCE_IMAGE' | cut -c1-25)*" -print0 2>/dev/null | xargs -0 echo | head -1 | tr -d '\n')
```

**Look up the correspondent ID** for the payee. Query the correspondents API:
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/correspondents/?name__iexact={vendor}" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['results'][0]['id'] if r['results'] else 'none')"
```

**Upload the document:**
```bash
curl -s -X POST "https://internal-paperless.gofer.cloud/api/documents/post_document/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -F "document=@${ACTUAL_FILE}" \
  -F "title={YYYY-MM-DD} - {Description}" \
  -F "document_type=2" \
  -F "storage_path=4" \
  -F "created={YYYY-MM-DD}" \
  -F "tags=15" \
  -F "correspondent={CORRESPONDENT_ID}" \
  -F 'custom_fields=[{"field": 2, "value": "7tmUdxi30uhfZCKb"}]'
```

Omit `correspondent` if no match was found. The API returns a `task_id` — confirm success.

**Then update the expense note** to replace the `receipt: N/A` placeholder with the proper wikilink:
- Receipt filename pattern: `{YYYY-MM-DD} - {Vendor} - {Description}.pdf`
- Update both the `receipt:` frontmatter field and the `**Receipt:**` line in Transaction Summary.

---

### Step 6c: Update Recurring Journal for Utility Bills

**Only execute this step if the subcategory is `Utilities:Electric` (SRP bill).**

After writing the expense file, update `/Users/jasoncrews/Documents/Unified/R01 - Rentals/recurring.journal` to insert a one-time exact entry for this month and advance the generic estimate to the following month.

**Logic:**
1. Read the current `recurring.journal`.
2. Determine `BILL_MONTH` = the due date month from the bill (e.g., `2026-05-01`).
3. Determine `NEXT_MONTH` = first day of the month after `BILL_MONTH` (e.g., `2026-06-01`).
4. Find the existing generic SRP Electric rule — it will have `rule-id:srp-electric-monthly`.
5. **Before** that rule, insert a new one-time entry:
   ```
   ; SRP Electric exact amount — {Month YYYY} bill (filed {file_date})
   ~ monthly from {BILL_MONTH} to {NEXT_MONTH}  ; rule-id:srp-electric-{YYYY-MM} SRP Electric - {Month YYYY}
       Expenses:Property:5450:Operating:Utilities:Electric    ${exact_amount}
       Assets:Banking:Baselane:checking:operating
   ```
6. Update the generic rule's `from` date to `{NEXT_MONTH}`:
   ```
   ~ monthly from {NEXT_MONTH}  ; rule-id:srp-electric-monthly SRP Electric (estimated)
   ```
7. Write the updated file and confirm the change to the user.

**Example result** after filing the May 2026 bill ($60.38):
```
~ monthly from 2026-05-01 to 2026-06-01  ; rule-id:srp-electric-2026-05 SRP Electric - May 2026
    Expenses:Property:5450:Operating:Utilities:Electric    $60.38
    Assets:Banking:Baselane:checking:operating

~ monthly from 2026-06-01  ; rule-id:srp-electric-monthly SRP Electric (estimated)
    Expenses:Property:5450:Operating:Utilities:Electric    $60.00
    Assets:Banking:Baselane:checking:operating
```

Use the exact amount from the bill as the estimate for the following month (best available approximation until the next bill is filed).

---

### Step 7: Regenerate Ledger and Verify

After writing the expense file, regenerate the hledger ledger and verify:

```bash
python3 /Users/jasoncrews/Documents/Unified/generate_ledger.py > "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger"
```

Then run hledger to verify the new transaction was processed correctly:

```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" print date:{YYYY-MM-DD} desc:{description_keyword}
```

Also run a balance check to confirm no errors in the full ledger:

```bash
hledger -f "/Users/jasoncrews/Documents/Unified/R01 - Rentals/expenses.hledger" bal -N
```

If hledger reports parse errors, inspect the generated expense file for YAML/posting issues and fix before proceeding.

Show the user the hledger `print` output for the new transaction as confirmation.

---

### Step 8: Cleanup

After verification:
```bash
rm -f /tmp/paperless_preview/doc_{DOC_ID}_*
```

Report success with the full file path and ledger verification results.

---

## Account Path Reference

| Category | Project | Subcategory | Full Path |
|----------|---------|-------------|-----------|
| Operating | — | Meals | `Expenses:Property:5450:Operating:Meals` |
| Operating | — | Supplies | `Expenses:Property:5450:Operating:Supplies` |
| Operating | — | Utilities:Electric | `Expenses:Property:5450:Operating:Utilities:Electric` |
| Operating | — | Utilities:Water | `Expenses:Property:5450:Operating:Utilities:Water` |
| Operating | — | HOA | `Expenses:Property:5450:Operating:HOA` |
| Operating | — | Insurance | `Expenses:Property:5450:Operating:Insurance` |
| Operating | — | Legal:EntityFormation | `Expenses:Property:5450:Operating:Legal:EntityFormation` |
| Operating | — | Mortgage:Interest | `Expenses:Property:5450:Operating:Mortgage:Interest` |
| Capital | PreRentalRenno | Appliances | `Expenses:Property:5450:CapitalImprovements:PreRentalRenno:Appliances` |
| Capital | PreRentalRenno | Flooring | `Expenses:Property:5450:CapitalImprovements:PreRentalRenno:Flooring` |
| Capital | PreRentalRenno | Kitchen | `Expenses:Property:5450:CapitalImprovements:PreRentalRenno:Kitchen` |
| Capital | PreRentalRenno | Fixtures | `Expenses:Property:5450:CapitalImprovements:PreRentalRenno:Fixtures` |
| Capital | PreRentalRenno | Lighting | `Expenses:Property:5450:CapitalImprovements:PreRentalRenno:Lighting` |
| Capital | PreRentalRenno | Plumbing | `Expenses:Property:5450:CapitalImprovements:PreRentalRenno:Plumbing` |
| Capital | PreRentalRenno | Building | `Expenses:Property:5450:CapitalImprovements:PreRentalRenno:Building` |

**Liability account subcategory** matches the expense subcategory leaf. Examples:
- Expense: `Expenses:Property:5450:Operating:Meals` → Liability: `Liabilities:Members:Jason:Owed:Meals`
- Expense: `Expenses:Property:5450:Operating:Supplies` → Liability: `Liabilities:Members:Jason:Owed:Supplies`

## Depreciation Reference

| Asset Type | Life | Examples |
|------------|------|----------|
| Appliances | 5 years | Stove, fridge, dishwasher, microwave |
| Flooring | 5 years | Carpet, vinyl, tile |
| Fixtures | 5 years | Light fixtures, faucets, door hardware |
| Landscaping | 15 years | Trees, irrigation, hardscape |
| Building/Improvements | 27.5 years | Countertops, cabinets, structural |

De minimis safe harbor: Items under $2,500 can be expensed immediately (`de_minimis: true`).

## Error Handling

- **API unreachable:** Try fallback IP `192.168.39.25:8000`. If both fail, suggest checking with `/infra services`.
- **Document not found (404):** Ask user to verify the document ID/URL.
- **Preview unreadable:** Try `/thumb/` endpoint. If still unreadable, ask user to describe the receipt.
- **File already exists:** Warn user and ask to overwrite or change description.
- **Negative amount:** Confirm it's a refund/return, then reverse all posting signs.
- **Who paid unclear:** Always ask — never assume. Incorrect payer assignment means the liability is recorded to the wrong person.
