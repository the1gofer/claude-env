---
name: file
description: File a document (statement, notice, letter, insurance doc, etc.) into Paperless-NGX with correct metadata. No expense note is created — this skill is for archiving documents only. Accepts a local file path or Paperless document ID/URL.
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
| 8 | Statement | Bank statements, mortgage statements, HOA statements, utility statements |
| 2 | Receipt | Payment confirmations, receipts |
| 5 | Letter | Correspondence, notices, legal letters |
| 6 | Invoice | Invoices awaiting payment |

## Storage Paths

| ID | Path | Use For |
|----|------|---------|
| 13 | Business-Statements | Monthly/quarterly statements from any institution |
| 4 | Rental Receipts | Payment receipts and confirmations |

## Known Correspondents

| ID | Name |
|----|------|
| 27 | United Wholesale Mortgage |
| (look up others via API) | |

## Instructions

Parse "$ARGUMENTS" to determine the input:
- **Local file path** — starts with `/` or `~`, or ends in `.pdf`, `.png`, `.jpg`
- **Paperless URL or ID** — contains `/documents/` or is a plain number
- **Natural language** — everything else; extract as much as possible

Then execute these steps:

---

### Step 1: Read the Document

If a local file path was provided, use the Read tool to view it. Extract:
- **Document type** — statement, receipt, letter, invoice, notice?
- **Correspondent/Issuer** — who sent it (bank, servicer, HOA, utility, insurer)?
- **Date** — statement date, issue date, or effective date (prefer statement closing date for statements)
- **Subject/Title** — what is this document about? (e.g., "Mortgage Statement", "HOA Statement", "Insurance Renewal")
- **Account/Reference number** — if visible

If a Paperless ID was provided, fetch metadata via API instead.

---

### Step 2: Resolve Correspondent

Look up the correspondent in Paperless by name:
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/correspondents/?name__icontains={name}" | \
  python3 -c "import sys,json; r=json.load(sys.stdin); [print(x['id'], x['name']) for x in r['results']]"
```

If no match, create the correspondent:
```bash
curl -s -X POST "https://internal-paperless.gofer.cloud/api/correspondents/" \
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
- **Property Field:** 5450 E McLellan Rd Unit 227 ✓
```

Confirm before uploading. If anything looks wrong, ask for correction.

---

### Step 4: Upload to Paperless

```bash
curl -s -X POST "https://internal-paperless.gofer.cloud/api/documents/post_document/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -F "document=@{file_path}" \
  -F "title={title}" \
  -F "document_type={type_id}" \
  -F "storage_path={path_id}" \
  -F "created={YYYY-MM-DD}" \
  -F "correspondent={correspondent_id}"
```

The API returns a task ID (UUID string) on success.

---

### Step 5: Add Property Custom Field

After upload, look up the new document to get its ID:
```bash
curl -s -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  "https://internal-paperless.gofer.cloud/api/documents/?correspondent__id={correspondent_id}&ordering=-added&page_size=3" | \
  python3 -c "import sys,json; r=json.load(sys.stdin); [print(x['id'], x['title'], x['created']) for x in r['results']]"
```

Identify the correct document (match by title and date), then PATCH the property custom field:
```bash
curl -s -X PATCH "https://internal-paperless.gofer.cloud/api/documents/{doc_id}/" \
  -H "Authorization: Token 8b9ee24b0a65826bec81bd36ca2d5bf26b8704d3" \
  -H "Content-Type: application/json" \
  -d '{"custom_fields": [{"field": 2, "value": "7tmUdxi30uhfZCKb"}]}'
```

Confirm `custom_fields` is present in the response.

---

### Step 6: Report

Report success:
```
✅ Filed successfully
- **Document ID:** {doc_id}
- **Title:** {title}
- **Correspondent:** {correspondent_name}
- **Stored at:** {storage_path_display}
- **Property field:** ✓
- **Wikilink:** [[{MM} - {Correspondent} - {Title}.pdf]]
```

The wikilink can be used in Obsidian expense or income notes to reference this document.

---

## Title Conventions

| Document | Title Format |
|----------|-------------|
| Mortgage statement | `Mortgage Statement` |
| Bank/Baselane statement | `Operating Account` |
| HOA statement | `HOA Statement` |
| Insurance policy/renewal | `Insurance Policy` |
| Utility statement | `Account Statement` |
| Legal notice | `{brief description}` |

Keep titles short — the storage path already includes the correspondent name and date prefix.

## Error Handling

- **API unreachable:** Try fallback `http://192.168.39.25:8000`. If both fail, suggest `/infra services`.
- **Correspondent not found:** Create it via POST before uploading.
- **Duplicate detected:** Check if a document with the same title and date already exists before uploading.
