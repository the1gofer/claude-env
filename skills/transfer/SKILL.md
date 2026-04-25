---
name: transfer
description: Record a member contribution or inter-account transfer for the LLC. Accepts inline arguments like "/transfer $1000 from jason to operating", or an image file path to extract transfer details from a screenshot. Generates a structured Obsidian transaction file with double-entry postings and saves a receipt copy.
---

Record a member contribution or inter-account transfer as a structured Obsidian transaction file.

## Constants

| Key | Value |
|-----|-------|
| Expense Output Dir | `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses` |
| Default LLC Wikilink | `[[Entity - 5450 E McLellan Rd Unit 227, LLC\|5450 E McLellan Rd Unit 227, LLC]]` |
| Default Property Short | `5450` |

## Paperless-NGX Constants

| Key | Value |
|-----|-------|
| API Base | `https://internal-paperless.gofer.cloud` |
| Token | `8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3` |
| Document Type — Receipt | `2` |
| Storage Path — Rental Receipts | `4` |
| Tag — Transfer | `15` |
| Custom Field — Property | `2` |
| Property Value — 5450 | `7tmUdxi30uhfZCKb` |

## Paperless Correspondent Mapping

| Source Alias | Correspondent ID | Name |
|---|---|---|
| `jason` / `wealthfront` | `82` | Wealthfront |
| `shannon` | (omit) | — |
| `operating` / `capex` / `vacancy` / `newdeal` / `security` / `amex` | (omit) | — |

## Account Aliases

### Source Accounts ("from")

| Alias | Account |
|-------|---------|
| `jason` | `Liabilities:Members:Jason:Owed:Transfer` |
| `shannon` | `Liabilities:Members:Shannon:Owed:Transfer` |
| `operating` | `Assets:Banking:Baselane:checking:operating` |
| `capex` | `Assets:Banking:Baselane:checking:capex` |
| `vacancy` | `Assets:Banking:Baselane:checking:VacancyReserve` |
| `newdeal` | `Assets:Banking:Baselane:checking:NewDealReserve` |
| `security` | `Assets:Banking:Baselane:checking:SecurityDeposit` |
| `amex` | `Liabilities:Credit:AmexBusinessPlus` |
| `wealthfront` | `Liabilities:Members:Jason:Owed:Transfer` |

### Destination Accounts ("to")

Same table as Source Accounts. Any alias can be used as source or destination.

### Image-based Account Recognition

When extracting data from an image, map institution/account names to aliases:

| Seen in Image | Alias |
|---------------|-------|
| `Wealthfront` / `Main-4745` | `jason` — Wealthfront is Jason's personal account; transfers from it are member contributions owed to Jason |
| `Baselane` / `Operating Account` / `7713` | `operating` |
| `Baselane` / `CapEx` | `capex` |
| `Baselane` / `Vacancy` | `vacancy` |
| `Baselane` / `Security` | `security` |

## Instructions

### Step 1: Determine Input Mode

Inspect `$ARGUMENTS` **and** whether an image was embedded in the user's message (pasted screenshot):

**Mode A — Image file path:** If arguments contain a file path ending in `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, or `.heic`, treat it as an image input. Use the Read tool to view the image at that path and extract:
- **Date** — from the transfer date shown in the image
- **Amount** — dollar amount of the transfer
- **From account** — source institution/account name → map to alias using Image-based Account Recognition table
- **To account** — destination institution/account name → map to alias

Store the image path as `$SOURCE_IMAGE` for use in Step 4b.

**Mode C — Inline image (pasted in conversation):** If the user pasted a screenshot directly into the chat (no file path in args), extract the transfer data visually from the image in the conversation, then locate the source file on disk.

Screenshots save to `~/Dropbox/Screenshots/`. Find the most recent one from today and copy it to `/tmp/transfer_receipt.png`:

```bash
find "$HOME/Dropbox/Screenshots" -maxdepth 1 -name "$(date +%Y-%m-%d)*" -print0 \
  | xargs -0 ls -t 2>/dev/null \
  | head -1 \
  | xargs -I{} find "$HOME/Dropbox/Screenshots" -maxdepth 1 -name "$(basename '{}')" -print0 \
  | xargs -0 -I{} cp "{}" /tmp/transfer_receipt.png
```

Simpler: use `find` with a date-based name pattern and copy the most recent match:
```bash
LATEST=$(find "$HOME/Dropbox/Screenshots" -maxdepth 1 -name "*$(date +%Y-%m-%d)*" -print0 | xargs -0 ls -t 2>/dev/null | head -1)
find "$HOME/Dropbox/Screenshots" -maxdepth 1 -name "$(basename "$LATEST" 2>/dev/null)" -print0 | xargs -0 -I{} cp "{}" /tmp/transfer_receipt.png
```

If `/tmp/transfer_receipt.png` exists with non-zero size, set `$SOURCE_IMAGE` to `/tmp/transfer_receipt.png` and proceed as Mode A for the Paperless upload step.

If the file cannot be found, generate a text receipt and upload that instead (see Step 4b fallback).

**Mode B — Inline arguments or natural language:** Parse `$ARGUMENTS` flexibly. Supported forms:

- `$1000 from jason to operating` — explicit source and destination
- `jason transferred $1000 to operating` — natural language with both
- `shannon transferred $150` — member and amount only, destination unknown
- `jason sent $500` — member and amount only
- `$500 from operating to capex` — account-to-account, no member

Extract using these rules in order:
1. Find a dollar amount (strip `$` and commas)
2. Find a member name (Jason / Shannon) — if present, they are the source
3. Find a destination alias after "to" if present
4. If source or destination still unknown after parsing, ask via AskUserQuestion

- Normalize all aliases to lowercase
- Resolve aliases to full account paths using the Account Aliases table above

**If arguments are missing or incomplete:** Use AskUserQuestion to gather only what's missing:
1. **Amount** — if not found in text
2. **From** — source (member name or account alias), if not found
3. **To** — destination (account alias), if not found
4. **What expenses does this fund?** — optional, for the note/description (e.g. "mortgage and HOA")

### Step 2: Determine Transaction Details

Based on the source and destination, determine:

**Description** — auto-generate based on the transfer type:
- Member → Bank account: `"Member Contribution to {destination_name} - {Member}"`
- Bank → Bank: `"Internal Transfer - {source_name} to {destination_name}"`
- Bank → Member: `"Distribution to {Member} from {source_name}"`

**Date** — use the date from the image (Mode A) or inline args if provided; otherwise default to today (`date +%Y-%m-%d`). Ask the user if a different date is needed.

**paid_by** — If source is a member, use that member's name. If source is an LLC account, use `"LLC"`.

**Tags:**
- Always: `banking`, `transfer`
- Member contribution: add `member-contribution`
- Internal transfer: add `internal`
- Distribution: add `distribution`

### Step 3: Build Postings

#### Member → LLC account (member contribution):

The member funded the LLC out of personal funds. Record the **full amount** as a liability owed to that member. Do NOT pre-split. The other member's reimbursement or matching contribution is a separate future transaction.

```yaml
postings:
  - account: "{destination_account}"
    amount: {amount}
    note: "{description}"
  - account: "Liabilities:Members:{member}:Owed:Transfer"
    amount: -{amount}
    note: "Funded by {member} ({payment_source}) — {otherMember} reimbursement pending"
```

#### LLC account → LLC account (internal transfer):

No member liability. Just move money between accounts.

```yaml
postings:
  - account: "{destination_account}"
    amount: {amount}
    note: "{description}"
  - account: "{source_account}"
    amount: -{amount}
    note: "Internal transfer from {source_name}"
```

#### LLC account → member (distribution):

```yaml
postings:
  - account: "Liabilities:Members:{member}:Owed:Transfer"
    amount: {amount}
    note: "Distribution to {member}"
  - account: "{source_account}"
    amount: -{amount}
    note: "Distribution from {source_name}"
```

**Never pre-split any transfer.** If both members contribute, record each contribution as a separate transaction.

### Step 4: Find Receipt Filename and Upload to Paperless-NGX

Run this step **before** writing the Obsidian file so the receipt wikilink can be embedded.

**Find the receipt filename in the Obsidian Receipts folder:**

After uploading to Paperless, the file is synced into the Obsidian vault at:
`/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Receipts/2026/`

Search for the most recently added file matching today's date to get the exact filename:
```bash
ls -t "/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Receipts/2026/" \
  | grep "^{YYYY-MM-DD}" | head -5
```

Store the exact filename as `$RECEIPT_FILENAME`. The Obsidian wikilink will be `[[{RECEIPT_FILENAME}]]`.

**Upload to Paperless-NGX** (when image is available — Mode A or Mode C):

Upload via curl. Include `correspondent` only if a mapping exists for the source alias:
```bash
curl -s -X POST "https://internal-paperless.gofer.cloud/api/documents/post_document/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -F "document=@${SOURCE_IMAGE}" \
  -F "title={YYYY-MM-DD} - {Description}" \
  -F "document_type=2" \
  -F "storage_path=4" \
  -F "created={YYYY-MM-DD}" \
  -F "tags=15" \
  -F "correspondent={ID}" \
  -F 'custom_fields={"2":"7tmUdxi30uhfZCKb"}'
```

Wait ~8 seconds for Paperless to sync the file to the Receipts folder, then look up the filename using the ls command above.

If no image is available (Mode B with no screenshot), set `$RECEIPT_FILENAME` to empty and omit the `receipt:` frontmatter field.

### Step 4b: Show Full File for Confirmation

**Before writing anything**, display the complete file content to the user exactly as it will be saved (including the receipt link if `$PAPERLESS_DOC_ID` is set):

```
Here is the note that will be saved. Please confirm or let me know what to change:

---
[full file content using the format from Step 5 below]
---
```

Use AskUserQuestion with options: **Looks good — save it** / **Make changes** / **Cancel**.

If the user wants changes, update the draft and show it again. Only write after explicit confirmation.

### Step 5: Generate the Transaction File

**Filename:** `{YYYY-MM-DD} - {Description}.md`
**Path:** `/Users/jasoncrews/Documents/Unified/R01 - Rentals/1 - 5450 E McLellan Rd Unit 227, LLC/Expenses/{filename}`

Before writing, check if a file with the same name already exists. If so, warn and ask the user.

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
  - account: "{destination_account}"
    amount: {amount}
    note: "{description}"
  - account: "{source_account}"
    amount: -{amount}
    note: "{source_note}"
llc: "{llc_wikilink}"
receipt: "[[{RECEIPT_FILENAME}]]"    ← omit this line entirely if $RECEIPT_FILENAME is empty
---

# {description}

## Transaction Summary
- **Amount:** ${formatted_amount}
- **Date:** {YYYY-MM-DD}
- **From:** {source_display}
- **To:** {destination_display}

## Accounting Postings
| Account | Amount | Note |
| :--- | :--- | :--- |
| `{destination_account}` | **${amount}** | {dest_note} |
| `{source_account}` | -${amount} | {source_note} |

## Related
- [[R01 - Rentals/Expenses/_Expense Dashboard|Expense Dashboard]]
- [Receipt (Paperless #{PAPERLESS_DOC_ID})](https://internal-paperless.gofer.cloud/documents/{PAPERLESS_DOC_ID}/)
```

If `$PAPERLESS_DOC_ID` is empty (no image was available), omit the receipt line entirely.

Write the file using the Write tool.

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

Show the user the hledger `print` output for the new transaction as confirmation.

## Error Handling

- **Unrecognized alias:** Show the alias table and ask the user to pick or provide a full account path.
- **Missing amount:** Ask user.
- **File exists:** Warn and ask to overwrite or change description.
- **Ledger errors:** Inspect YAML for formatting issues and fix.
