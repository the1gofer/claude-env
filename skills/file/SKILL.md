---
name: file
description: File a document (statement, notice, letter, insurance doc, etc.) into Paperless-NGX with correct metadata. Accepts a local file path or Paperless document ID/URL. If the document is a Receipt (type 2), automatically continues into the expense skill to create the Obsidian transaction note.
---

File a document into Paperless-NGX with correct metadata for the LLC rental property.

## Constants

| Key | Value |
|-----|-------|
| Paperless API Base | `https://internal-paperless.gofer.cloud/api` |
| Paperless API Fallback | `http://192.168.39.25:8000/api` |
| Auth Header | `Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3` |
| Property Custom Field | `field: 2, value: "7tmUdxi30uhfZCKb"` |

## Document Types

| ID | Name | Use For |
|----|------|---------|
| 1 | Agreement | Leases, contracts, operating agreements |
| 2 | Receipt | Payment confirmations, receipts |
| 5 | Notice | IRS notices, legal notices, government correspondence |
| 6 | Invoices | Invoices awaiting payment |
| 8 | Statement | Bank statements, mortgage statements, HOA statements, utility statements |
| 11 | Bills | Utility bills, service bills |
| 12 | Dec Page | Insurance declaration pages |
| 13 | Binders | Insurance binders |
| 14 | Policies | Full insurance policy packets |
| 16 | Report | Inspection reports, financial reports |
| 19 | Tracking | USPS tracking records, shipping confirmations |

## Storage Paths

| ID | Path | Use For |
|----|------|---------|
| 4 | Business/Rentals/Property/Receipts/{year}/ | Payment receipts, tracking records for mailed payments |
| 6 | Business/Rentals/Property/Invoices/{year}/ | Vendor invoices |
| 8 | Business/Rentals/Property/Maintenance/{year}/ | Maintenance records |
| 10 | Business/Rentals/Property/Insurance/Quotes/{year}/ | Insurance quotes |
| 11 | Business/Rentals/Property/Insurance/Binders/{year}/ | Insurance binders |
| 12 | Business/Rentals/Property/Insurance/Policies/{year}/ | Insurance policies, dec pages, endorsements |
| 13 | Business/Rentals/Property/Statements/{year}/ | Monthly/quarterly statements (HOA, mortgage, bank) |
| 14 | Business/Rentals/Property/Bills/{year}/ | Utility and service bills |
| 18 | Personal/Receipts/{year}/ | Personal receipts (medical, personal purchases) |
| 20 | Personal/Taxes/{year}/ | IRS notices, tax documents |

## Known Correspondents

| ID | Name |
|----|------|
| 20 | Alta Mesa Resort Village HOA |
| 21 | IRS |
| 27 | United Wholesale Mortgage |
| 39 | Foremost |
| 50 | USPS |
| 99 | Alta Mesa |
| 101 | One Medical |
| (look up others via API) | |

## USPS Tracking Records — HOA Payments

When filing USPS tracking printouts for mailed HOA payments:
- **Document type:** Tracking (ID 19)
- **Storage path:** Receipts (ID 4)
- **Property field:** Yes (McLellan property)
- **Correspondent:** Match to the HOA the payment was sent to
- **Date:** Use the USPS postmark date
- **Title format:** `USPS Tracking - {HOA Name} {Month} Payment` or `USPS Tracking - {HOA Name} Quarterly Payment`
- **After filing:** Add the Paperless document URL (`http://192.168.39.25:8000/documents/{id}/`) to the `receipt:` field in the corresponding Obsidian postage expense note

### HOA Mailing Address Notes (McLellan property)
- **Alta Mesa Resort Village HOA** (monthly ~$380): correct zip **85082** — previous zip 80825 was wrong (misdelivered March 2026)
- **Alta Mesa HOA** (quarterly fee): correct zip **85026** — previous zip 85206 may have been wrong

## Personal vs LLC Documents

- LLC rental property documents: use Business/Rentals paths, add property custom field
- Personal documents (medical receipts, personal tax notices): use Personal/ paths, NO property custom field

## Instructions

Parse "$ARGUMENTS" to determine the input:
- **Local file path** — starts with `/` or `~`, or ends in `.pdf`, `.png`, `.jpg`
- **Paperless URL or ID** — contains `/documents/` or is a plain number
- **Natural language** — everything else; extract as much as possible

Then execute these steps:

---

### Step 1: Read the Document

If a local file path was provided, use the Read tool to view it. Extract:
- **Document type** — statement, receipt, letter, invoice, notice, tracking record?
- **Correspondent/Issuer** — who sent it (bank, servicer, HOA, utility, insurer, USPS)?
- **Date** — statement date, issue date, or effective date (prefer statement closing date for statements; postmark date for USPS tracking)
- **Subject/Title** — what is this document about?
- **Account/Reference number** — if visible
- **Personal or LLC** — does this belong to the rental property or to Jason personally?

If a Paperless ID was provided, fetch metadata via API instead.

---

### Step 2: Resolve Correspondent

Look up the correspondent in Paperless by name:
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "http://192.168.39.25:8000/api/correspondents/?name__icontains={name}" | \
  python3 -c "import sys,json; r=json.load(sys.stdin); [print(x['id'], x['name']) for x in r['results']]"
```

If no match, create the correspondent:
```bash
curl -s -X POST "http://192.168.39.25:8000/api/correspondents/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -H "Content-Type: application/json" \
  -d '{"name": "{correspondent_name}"}'
```

---

### Step 3: Confirm Metadata

Show the user what will be filed:

```
## Filing Summary
- **File:** {filename}
- **Correspondent:** {correspondent_name}
- **Document Type:** {type_name} (ID {type_id})
- **Storage Path:** {path_name} (ID {path_id})
- **Title:** {title}
- **Date:** {YYYY-MM-DD}
- **Property Field:** 5450 E McLellan Rd Unit 227 ✓  (or: N/A — personal document)
```

Confirm before uploading. If anything looks wrong, ask for correction.

---

### Step 4: Upload to Paperless

```bash
curl -s -X POST "http://192.168.39.25:8000/api/documents/post_document/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -F "document=@{file_path}" \
  -F "title={title}" \
  -F "document_type={type_id}" \
  -F "storage_path={path_id}" \
  -F "created={YYYY-MM-DD}" \
  -F "correspondent={correspondent_id}"
```

The API returns a task ID (UUID string) on success. Wait ~4 seconds then look up the document.

---

### Step 5: Add Property Custom Field (LLC documents only)

After upload, look up the new document to get its ID:
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "http://192.168.39.25:8000/api/documents/?correspondent__id={correspondent_id}&ordering=-added&page_size=3" | \
  python3 -c "import sys,json; r=json.load(sys.stdin); [print(x['id'], x['title'], x['created']) for x in r['results']]"
```

Identify the correct document (match by title and date), then PATCH the property custom field:
```bash
curl -s -X PATCH "http://192.168.39.25:8000/api/documents/{doc_id}/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -H "Content-Type: application/json" \
  -d '{"custom_fields": [{"field": 2, "value": "7tmUdxi30uhfZCKb"}]}'
```

Skip this step for personal documents.

---

### Step 6: Report

Report success:
```
✅ Filed successfully
- **Document ID:** {doc_id}
- **Title:** {title}
- **Correspondent:** {correspondent_name}
- **Stored at:** {storage_path_display}
- **Property field:** ✓ (or N/A)
- **Paperless URL:** http://192.168.39.25:8000/documents/{doc_id}/
- **Wikilink:** [[{MM} - {Correspondent} - {Title}.pdf]]
```

---

### Step 7: Auto-trigger Expense Skill (Receipts only)

**If the document type is Receipt (ID 2)**, immediately continue into the `expense` skill without asking. Pass the Paperless document URL as the argument:

```
Paperless URL: http://192.168.39.25:8000/documents/{doc_id}/
```

Do not pause or prompt the user — the filing report above is sufficient context. The expense skill will read the document metadata, present extracted data, and ask only the accounting questions it needs (who paid, payment flow, etc.).

**Skip this step** for all other document types (statements, invoices, bills, tracking records, notices, etc.).

---

## Title Conventions

| Document | Title Format |
|----------|-------------|
| Mortgage statement | `Mortgage Statement` |
| Bank/Baselane statement | `Operating Account` |
| HOA statement | `HOA Statement` |
| Insurance dec page | `Insurance Declaration - {Amended/Endorsement} {YYYY-MM-DD}` |
| Insurance policy/renewal | `Insurance Policy` |
| Utility statement | `Account Statement` |
| Legal/IRS notice | `{Notice ID} - {brief description}` |
| USPS tracking (HOA payment) | `USPS Tracking - {HOA Name} {Month/Quarterly} Payment` |
| Medical receipt | `Office Visit Receipt` or `{Service} Receipt` |

Keep titles short — the storage path already includes the correspondent name and date prefix.

## Error Handling

- **API unreachable:** Try fallback `http://192.168.39.25:8000`. If both fail, suggest `/infra services`.
- **Correspondent not found:** Create it via POST before uploading.
- **Duplicate detected:** Check if a document with the same title and date already exists before uploading.
