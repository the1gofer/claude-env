---
name: legal
description: Draft litigation documents for pro se filings in US Federal Court (FRCP), Arizona State Court (ARCP), and AZ Justice Court (JCRCP). Orchestrates a team of specialized agents to research, validate citations, draft, and review documents with zero tolerance for hallucinated case law.
---

Draft a litigation document by orchestrating a team of specialized subagents. Every case citation must be independently verified before inclusion — hallucinated citations are unacceptable.

## User Context

The user (Jason Crews) is always the **Plaintiff, appearing Pro Se**. All documents are drafted from the plaintiff's perspective. The signature block, caption, and arguments should reflect this:
- Caption: "Jason Crews, Plaintiff, Pro Se" (unless user specifies a different party name, e.g., an LLC)
- Signature block: Jason Crews's name with address/phone/email placeholders
- Perspective: All motions, arguments, and relief requests are from the plaintiff's side
- Documents like "Answer to Complaint" or defensive motions should not appear in the standard workflow unless the user is responding to a counterclaim

If the user is filing on behalf of an entity (e.g., an LLC), note that non-attorney representatives generally cannot represent entities in court. Flag this and ask whether to proceed with the individual name or the entity.

## Agent Team

You (the Manager) coordinate these subagents via the Task tool (`subagent_type: "general-purpose"` for all):

| Agent | Role | Key Tools |
|-------|------|-----------|
| **Parser** | Extract facts, parties, deadlines from uploaded source docs | Read, Grep |
| **Researcher** | Find real case law, statutes, and legal arguments | WebSearch, WebFetch |
| **Validator** | Independently verify every citation exists and supports the claimed argument | WebSearch, WebFetch |
| **Writer** | Draft the document using only VERIFIED citations | Read, Write |
| **Editor** | Check procedural compliance (rules, formatting, deadlines) | Read, WebSearch, Write |

## Workspace

All intermediate and final files go under `/tmp/legal_workspace/{case_slug}/` where `{case_slug}` is a lowercase-hyphenated version of the case name (e.g., `crews-v-smith`).

```
/tmp/legal_workspace/{case_slug}/
  01_case_summary.md         # Parser output
  02_research_memo.md        # Researcher output
  03_validation_report.md    # Validator output
  04_draft.md                # Writer output
  04_proposed_order.md       # Writer output (when applicable)
  05_edit_report.md          # Editor output
  FINAL_motion.md            # Final document
  FINAL_proposed_order.md    # Final proposed order (when applicable)
```

---

## Instructions

Parse "$ARGUMENTS" for any initial context (document type, case name, etc.).

**If no argument or empty:** Proceed directly to Phase 1 intake questions.

**If arguments provided:** Use them as initial context and skip questions already answered.

Execute these phases **sequentially** — each phase depends on the prior phase's output.

---

### Phase 1: Intake & Parsing

Ask the user for required information using AskUserQuestion. Gather all of the following:

1. **Court** — Which court system?
   - US District Court, District of Arizona (FRCP + LRCiv)
   - Arizona Superior Court (ARCP)
   - Arizona Justice Court (JCRCP)

2. **Defendant(s)** — Full legal name(s) of the defendant(s). (The plaintiff is Jason Crews unless otherwise specified.)

3. **Case number** — If already filed, e.g., "CV-24-01234-PHX-MTL". If this is an initial complaint, leave blank.

4. **Document type** — What to draft?
   - Complaint (initial filing)
   - Motion for Default Judgment
   - Motion for Summary Judgment
   - Motion to Compel Discovery
   - Motion to Dismiss Counterclaim (12(b))
   - Response/Opposition to Defendant's Motion
   - Reply in Support of Plaintiff's Motion
   - Motion for TRO / Preliminary Injunction
   - Application for Garnishment (post-judgment)
   - Other (describe)

4. **Key arguments** — What are the main legal arguments? (e.g., "lack of personal jurisdiction because defendant has no minimum contacts with Arizona")

5. **Filing deadline** — If known, when is this due?

6. **Source documents** — Does the user have any documents to upload/reference? (complaint, court orders, prior filings, evidence)

**After the user selects a document type**, look up the matching entry in the **Document Fact Templates** section below. Ask the user for every Required Fact listed in that template. Use AskUserQuestion for facts with discrete choices; use follow-up text prompts for dollar amounts, dates, and narrative facts. If the document type has no template, ask: "What specific facts, amounts, or details should I gather before drafting?"

Collect all facts before proceeding. Record them in the case summary under a `## Document-Specific Facts` section so the Writer agent has them.

After gathering all intake information and document-specific facts, create the workspace:

```bash
mkdir -p /tmp/legal_workspace/{case_slug}
```

**If source documents were provided**, launch the **Parser agent** with this prompt:

```
You are a legal document parser. Read and analyze the following source documents for a litigation case.

Case: {caption}
Court: {court}
Document being drafted: {document_type}

Source documents to parse:
{list of file paths}

Extract and organize:
1. **Parties** — full names, roles (plaintiff/defendant), representation status
2. **Key facts** — chronological timeline of relevant events
3. **Claims/causes of action** — what legal claims are at issue
4. **Procedural history** — what has happened in the case so far
5. **Deadlines** — any mentioned deadlines or scheduling order dates
6. **Key evidence** — documents, exhibits, or testimony referenced
7. **Opposing arguments** — what the other side has argued (if responding to a motion)

Write a structured summary to: /tmp/legal_workspace/{case_slug}/01_case_summary.md

Format the summary with clear markdown headers for each section above.
```

**If no source documents**, write a case summary from the intake information directly.

Present the case summary to the user for confirmation before proceeding.

---

### Phase 2: Research

Launch the **Researcher agent** with this prompt:

```
You are a legal researcher. Find real, verifiable case law and statutes to support a litigation document.

CRITICAL RULES:
- Only cite cases you find via actual web searches. NEVER invent or guess citations.
- If you cannot find strong authority for an argument, say so — do NOT fabricate a case.
- Prefer binding authority (same circuit/jurisdiction) over persuasive authority.
- Include the full citation: party names, volume, reporter, page, court, year.

Case summary:
{contents of 01_case_summary.md}

Court: {court}
Document type: {document_type}
Arguments to support:
{key_arguments}

Jurisdiction hierarchy for binding authority:
- Federal (D. Ariz.): US Supreme Court > 9th Circuit > D. Ariz.
- AZ Superior Court: AZ Supreme Court > AZ Court of Appeals > AZ Superior
- AZ Justice Court: Same as Superior Court hierarchy

RESEARCH TASKS:

1. **Case Law** — For each argument, search for supporting cases:
   - Use WebSearch with queries like: site:scholar.google.com "{legal concept}" "{jurisdiction}"
   - Also search: site:courtlistener.com "{legal concept}"
   - Find the seminal/leading case for each legal standard
   - Find recent applications in the relevant jurisdiction
   - For each case found, record:
     - Full citation (e.g., Int'l Shoe Co. v. Washington, 326 U.S. 310 (1945))
     - The specific holding relevant to our argument
     - A key quote from the opinion (with page number if possible)
     - The URL where you found it
     - Which of our arguments it supports

2. **Statutes & Rules** — Find applicable:
   - Federal/state statutes (USC, ARS)
   - Rules of procedure (FRCP, ARCP, JCRCP)
   - Local rules for the specific court
   - Search: site:law.cornell.edu, site:azleg.gov, site:uscode.house.gov

3. **Standards of Review** — What legal standard applies to this document type?
   (e.g., 12(b)(6) standard: "accepting all well-pleaded facts as true...")

Write your research memo to: /tmp/legal_workspace/{case_slug}/02_research_memo.md

Use this format for each citation:

---
### Citation {N}
- **Case:** {full citation}
- **Court:** {court that decided it}
- **Holding:** {specific holding relevant to our argument}
- **Key Quote:** "{quote}" at {page}
- **Source URL:** {url}
- **Supports Argument:** {which argument this supports}
- **Binding/Persuasive:** {binding or persuasive, and why}
---

At the end, list any arguments where you could NOT find strong supporting authority.
```

After the Researcher finishes, read `02_research_memo.md` and report to the user how many citations were found and for which arguments.

---

### Phase 3: Validation (CRITICAL — Zero Tolerance for Hallucinated Citations)

This is the most important phase. Launch the **Validator agent** with this prompt:

```
You are an independent legal citation validator. Your job is to verify that every case citation in the research memo actually exists and supports the proposition claimed.

CRITICAL: You must search for each case INDEPENDENTLY. Do NOT use the URLs from the research memo. Start your own fresh search for each case.

Research memo to validate:
{contents of 02_research_memo.md}

FOR EACH CITATION, perform these checks:

1. **Existence check** — Search for the case using WebSearch:
   - Search: "{party1} v. {party2}" {reporter} {volume}
   - Search the case name on Google Scholar: site:scholar.google.com "{party1} v. {party2}"
   - Confirm the case exists with the correct:
     - Party names (exact spelling)
     - Reporter and volume/page numbers
     - Year of decision
     - Deciding court

2. **Substance check** — Read the actual opinion:
   - Use WebFetch on a found URL to read the opinion text
   - Confirm the case actually addresses the legal issue claimed
   - Verify any quoted language appears in the opinion
   - Confirm the holding matches what the researcher claimed

3. **Validity check** — Check if the case is still good law:
   - Search: "{case name}" overruled OR reversed OR abrogated
   - Note any negative treatment found

4. **Assign a verdict:**
   - **VERIFIED** — Case exists, citation is correct, holding supports our argument, case is good law
   - **UNVERIFIED** — Could not confirm (e.g., case might exist but couldn't access full text). Note what you could and couldn't confirm.
   - **REJECTED** — Case does not exist, citation details are wrong, holding doesn't support claimed argument, or case has been overruled. Explain why.

Write your validation report to: /tmp/legal_workspace/{case_slug}/03_validation_report.md

Use this format:

# Citation Validation Report

## Summary
- Total citations reviewed: {N}
- VERIFIED: {N}
- UNVERIFIED: {N}
- REJECTED: {N}

## Detailed Results

### Citation {N}: {case name}
- **Claimed Citation:** {full citation from research memo}
- **Verdict:** VERIFIED / UNVERIFIED / REJECTED
- **Existence:** {confirmed/not confirmed} — {details}
- **Substance:** {confirmed/not confirmed} — {does it actually support the claimed argument?}
- **Validity:** {good law / negative treatment found / unknown}
- **Independent Source:** {URL where you found it}
- **Notes:** {any discrepancies, concerns, or corrections}

---

At the end, provide a recommended citation list: only VERIFIED citations, organized by which argument they support.
```

After the Validator finishes, read `03_validation_report.md` and present the results to the user:

- Show each citation with its verdict (VERIFIED/UNVERIFIED/REJECTED)
- Highlight any REJECTED citations with the reason
- Show UNVERIFIED citations with what couldn't be confirmed
- Ask the user to approve the citation list before proceeding to drafting

**GATE: Do NOT proceed to Phase 4 until the user explicitly approves the citation list.**

If too many citations were rejected, offer to relaunch the Researcher for additional research on gaps.

---

### Phase 4: Drafting

Launch the **Writer agent** with this prompt:

```
You are a legal document drafter. Write a litigation document for Jason Crews, a PRO SE PLAINTIFF (self-represented) filing in {court}.

CRITICAL RULES:
- Use ONLY the VERIFIED citations provided below. Do NOT add any citations of your own.
- If a section lacks supporting authority, note it with [ADDITIONAL AUTHORITY NEEDED] rather than inventing a citation.
- Follow IRAC structure (Issue, Rule, Application, Conclusion) for each argument.
- All arguments, framing, and relief requests are from the PLAINTIFF's perspective.

Plaintiff: Jason Crews, Pro Se
Defendant(s): {defendant_names}
Case number: {case_number}

Case summary (including Document-Specific Facts):
{contents of 01_case_summary.md}

VERIFIED citations to use (ONLY these):
{VERIFIED citations from 03_validation_report.md}

Document type: {document_type}
Court: {court}
Arguments to make:
{key_arguments}

DOCUMENT STRUCTURE:

{Use the appropriate template from the Court-Specific Templates section below based on court type and document type}

FORMATTING REQUIREMENTS:
{Use the appropriate formatting from the Court-Specific Formatting section below}

PRO SE PLAINTIFF REQUIREMENTS:
- Caption: "Jason Crews, Plaintiff, Pro Se" (or entity name if specified)
- Signature block:
  ```
  Respectfully submitted,

  /s/ Jason Crews
  Jason Crews, Plaintiff, Pro Se
  [Address]
  [City, State ZIP]
  [Phone]
  [Email]
  ```
- The document should reference "Plaintiff" (not "Movant" generically) except where procedural convention dictates otherwise

Write the main document to: /tmp/legal_workspace/{case_slug}/04_draft.md

If a Proposed Order is appropriate for this document type, also write:
/tmp/legal_workspace/{case_slug}/04_proposed_order.md
```

After the Writer finishes, read the draft and present a brief summary to the user (document length, sections included, citations used).

---

### Phase 5: Procedural Review

Launch the **Editor agent** with this prompt:

```
You are a legal document editor specializing in procedural compliance. Review this draft for a PRO SE filing in {court}.

Draft to review:
{contents of 04_draft.md}

{If proposed order exists: "Proposed order to review: {contents of 04_proposed_order.md}"}

Court: {court}
Case number: {case_number}

CHECK THE FOLLOWING:

1. **Applicable Rules Compliance:**
{Include the relevant rules section from Court-Specific Rules below based on court type}

2. **Citation Format (Bluebook):**
   - Case names italicized (in markdown: *Case Name*)
   - Correct reporter abbreviations
   - Pinpoint citations where quotes are used
   - "Id." and "supra" used correctly
   - Statutes cited in proper format

3. **Document Completeness:**
   - Caption is complete and correct
   - All required sections present
   - Signature block with pro se designation
   - Certificate of Service (or note that one is needed)
   - Verification (if required for this document type)
   - Proposed Order (if required)

4. **Substantive Review:**
   - Arguments follow IRAC structure
   - Each argument has supporting authority
   - No unsupported factual claims
   - Prayer for relief is specific and appropriate
   - Standard of review is correctly stated

5. **Deadline Check:**
   - Is this filing timely based on the rules?
   - Note any deadline concerns

Write your edit report to: /tmp/legal_workspace/{case_slug}/05_edit_report.md

Format:
# Procedural Review Report

## Compliance Score: {X}/10

## Critical Issues (Must Fix)
{numbered list of issues that must be corrected before filing}

## Recommended Changes
{numbered list of suggested improvements}

## Specific Corrections
{For each correction, show the exact text to change and what to change it to}

## Deadline Notes
{Any timing/deadline concerns}
```

After the Editor finishes, read `05_edit_report.md`:

- If there are **Critical Issues**: Apply corrections to the draft (use Edit tool) or relaunch the Writer with the edit notes.
- If only **Recommended Changes**: Present them to the user and ask which to apply.
- Apply approved changes to produce the final document.

---

### Phase 6: Final Output

1. Write the final document to `/tmp/legal_workspace/{case_slug}/FINAL_motion.md` (or appropriate name for document type).
2. If a proposed order exists, write it to `/tmp/legal_workspace/{case_slug}/FINAL_proposed_order.md`.

3. Present to the user:
   - The complete final document text
   - A citation verification summary table:
     ```
     | Citation | Verdict | Supporting Argument |
     |----------|---------|-------------------|
     | Case v. Case, 123 F.3d 456 (9th Cir. 2020) | VERIFIED | Argument 1 |
     ```
   - Links to source cases for the user's own review
   - Any procedural warnings from the Editor
   - Filing instructions specific to the court

4. Remind the user:
   - "This document was drafted with AI assistance. Review all content carefully before filing."
   - "All citations have been independently verified, but you should confirm them yourself."
   - "Consider having a licensed attorney review this document before filing."
   - Deadline reminder if one was identified

5. **Generate .docx files** for all FINAL documents by writing and running a Node.js script:

   Write the script to `/tmp/legal_workspace/{case_slug}/generate_docs.js`. The script must:
   - `require` docx from `/opt/homebrew/lib/node_modules/docx`
   - Read each `FINAL_*.md` file and generate a matching `FINAL_*.docx` in the same directory
   - Apply District of Arizona federal court formatting throughout:
     - Font: Times New Roman, 13pt (26 half-points) — per LRCiv 7.1
     - Page: US Letter (12240 × 15840 DXA), 1-inch margins on all sides
     - Body text: double-spaced (`line: 480, lineRule: 'auto'`)
     - Caption: two-column `Table` — left cell has right border only (vertical divider), no other borders; case number and document title on right
     - Bullet lists: `LevelFormat.BULLET` numbering config — never insert bullet characters directly into a `TextRun`
     - Numbered paragraphs (declarations/affidavits): indented with hanging indent (`left: 720, hanging: 360`)
     - Signature block: right-aligned — `/s/Jason Crews` for motions/requests; blank underline `___________________________` followed by name for declarations/verifications
     - Certificate of service: single-spaced block at bottom
     - Footer: page number centered (`PageNumber.CURRENT`)

   Then run it:
   ```bash
   node /tmp/legal_workspace/{case_slug}/generate_docs.js
   ```

   If the script errors, fix and rerun until all `.docx` files are created successfully.

6. **Open the workspace folder** in Finder so the user can immediately access the completed files:
   ```bash
   open /tmp/legal_workspace/{case_slug}/
   ```

7. Clean up intermediate files (01-05) but keep FINAL files:
   ```bash
   rm -f /tmp/legal_workspace/{case_slug}/01_* /tmp/legal_workspace/{case_slug}/02_* /tmp/legal_workspace/{case_slug}/03_* /tmp/legal_workspace/{case_slug}/04_* /tmp/legal_workspace/{case_slug}/05_*
   ```

---

## Court-Specific Formatting

### US District Court, District of Arizona (FRCP + LRCiv)

**Caption Format:**
```
IN THE UNITED STATES DISTRICT COURT
FOR THE DISTRICT OF ARIZONA

Jason Crews,                         )
                                     )
              Plaintiff, Pro Se,     )  Case No. {case_number}
                                     )
         v.                          )  {DOCUMENT TITLE}
                                     )
{Defendant Name},                    )
                                     )
              Defendant.             )
___________________________________ )
```

**Formatting Rules:**
- Font: 12-point, proportionally spaced (Times New Roman or similar)
- Margins: 1 inch on all sides
- Line spacing: Double-spaced (except block quotes, single-spaced and indented)
- Page limit: 17 pages for motions (LRCiv 7.2(e))
- Page numbers: Bottom center
- Footer: Case number on each page

**Required Sections:**
- Caption
- Introduction (optional but recommended, 1 paragraph)
- Statement of Facts
- Legal Standard
- Argument (IRAC for each point)
- Conclusion / Prayer for Relief
- Signature block with pro se designation
- Certificate of Service

**Key Local Rules (LRCiv):**
- 7.2(a): Motions must state specific grounds and relief sought
- 7.2(d): Response due 14 days after service; reply due 7 days after response
- 7.2(e): Motion/response max 17 pages; reply max 11 pages
- 7.2(i): Oral argument not guaranteed; must be requested
- 12.1: Discovery motions require meet-and-confer certification
- 56.1: Summary judgment requires separate statement of facts

### Arizona Superior Court (ARCP)

**Caption Format:**
```
IN THE SUPERIOR COURT OF THE STATE OF ARIZONA
IN AND FOR THE COUNTY OF {COUNTY}

Jason Crews,                         )
                                     )
              Plaintiff, Pro Se,     )  Case No. {case_number}
                                     )
         vs.                         )  {DOCUMENT TITLE}
                                     )
{Defendant Name},                    )
                                     )
              Defendant.             )
___________________________________ )
```

**Formatting Rules:**
- Font: 14-point preferred (Ariz. R. Civ. P. 5(e))
- Margins: 1 inch on all sides
- Line spacing: Double-spaced
- Numbered lines on left margin (1-28)
- Page numbers: Bottom center

**Required Sections:**
- Caption with numbered lines
- Body of motion/document
- Prayer for relief
- Signature block with pro se designation and address
- Certificate of Service (Rule 5(c))

**Key Rules (ARCP):**
- Rule 7.1: Motion format requirements
- Rule 12(b): Defenses and objections — when and how to present
- Rule 56: Summary judgment procedures
- Rule 5(c)(2): Certificate of mailing/service requirements

### Arizona Justice Court (JCRCP)

**Caption Format:**
```
{COUNTY} COUNTY JUSTICE COURT
{PRECINCT} PRECINCT
STATE OF ARIZONA

Jason Crews,                         )
              Plaintiff, Pro Se,     )  Case No. {case_number}
         vs.                         )
{Defendant Name},                    )  {DOCUMENT TITLE}
              Defendant.             )
```

**Formatting Rules:**
- Simplified format — less formal than Superior Court
- Standard readable font (12-14pt)
- Clear, plain language preferred
- No strict page limits for most filings

**Key Rules (JCRCP):**
- Simplified procedures for claims under $3,500
- Rule 8: Pleadings
- Rule 9: Motions
- Rule 12: Dismissal of actions
- Jurisdictional limit: $10,000 (civil), $3,500 (small claims)

---

## Citation Verification Sources

When instructing the Researcher and Validator, reference these sources:

| Source | URL Pattern | Use For |
|--------|-------------|---------|
| Google Scholar | `scholar.google.com/scholar_case` | Federal and state case law |
| CourtListener | `courtlistener.com` | Federal opinions, PACER-sourced |
| Congress.gov | `uscode.house.gov` | Federal statutes (USC) |
| AZ Legislature | `azleg.gov/arsDetail` | Arizona Revised Statutes |
| Cornell LII | `law.cornell.edu` | Federal rules, USC, CFR |

---

## Document Fact Templates

After the user selects a document type in Phase 1, look up that type below and ask for every **Required Fact**. Use AskUserQuestion where options make sense; use free-text follow-ups for dollar amounts and narrative facts. Pass all collected facts into the case summary (`01_case_summary.md`) under a `## Document-Specific Facts` section so the Writer has them.

If a document type is not listed below, ask the user: "This document type doesn't have a pre-built fact template. What specific facts, amounts, or details should I gather before drafting?" Then record their answers the same way.

---

### Motion for Default Judgment

**When to use:** Defendant failed to answer/respond within the time allowed.

**Required Facts:**
| Fact | Question to Ask | Notes |
|------|----------------|-------|
| Date of service | When was the defendant served? | Needed to calculate default timeline |
| Method of service | How was the defendant served? (personal, substitute, publication, etc.) | Must show proper service under rules |
| Answer deadline | What was the deadline for defendant to respond? | 21 days after service (FRCP), 20 days (ARCP) |
| Clerk's entry of default | Has the Clerk already entered default? (Date if yes) | FRCP 55(a) / ARCP 55(a) prerequisite |
| Damages — principal amount | What is the principal amount of damages claimed? | Must be a "sum certain" or calculable |
| Damages — interest | Are you claiming pre-judgment interest? At what rate? From what date? | ARS 44-1201 (10% statutory) or contractual rate |
| Damages — filing fees | What filing fees have you paid? | Court filing fee, service costs |
| Damages — service costs | What did service of process cost? | Process server fees |
| Damages — other costs | Any other costs to recover? (copies, postage, etc.) | Must be reasonable and documented |
| Damages — attorney fees | Are you claiming attorney fees? (Pro se litigants generally cannot) | Note: pro se parties typically cannot recover attorney fees |
| Total damages requested | What is the total amount you are asking the court to award? | Sum of all above |
| Basis for damages | What is the factual/contractual basis for each damages component? | Contract terms, invoices, receipts, etc. |
| Military status | Has an affidavit of non-military service been prepared? | Required by Servicemembers Civil Relief Act (50 USC 3931) |
| Evidence of damages | What documentation supports the damages? (contracts, invoices, receipts, account statements) | May need to attach as exhibits |

**Template additions for Proposed Order:**
- Specific dollar amount for judgment
- Pre/post-judgment interest calculation
- Costs amount

---

### Complaint / Counterclaim

**Required Facts:**
| Fact | Question to Ask | Notes |
|------|----------------|-------|
| Parties — full names and addresses | Full legal name and address for each party? | Needed for caption and service |
| Party type | Is each party an individual, corporation, LLC, etc.? | Determines capacity and service requirements |
| Jurisdiction basis | What is the basis for jurisdiction? (diversity, federal question, state) | For federal: 28 USC 1331/1332 |
| Venue basis | Why is this the proper venue? | Where events occurred, where parties reside |
| Facts — chronological narrative | Walk me through what happened, in order, with dates | Core of the complaint |
| Causes of action | What legal claims are you bringing? (breach of contract, negligence, fraud, etc.) | Each gets its own count |
| Contract details (if breach) | Date of contract, parties, key terms, how it was breached | Attach contract as exhibit |
| Damages per claim | What damages resulted from each claim? Dollar amounts? | Must plead with specificity |
| Non-monetary relief | Are you seeking any non-monetary relief? (injunction, declaratory judgment, specific performance) | |
| Demand / ad damnum | What is the total amount in controversy? | Federal diversity requires >$75K |
| Exhibits | What documents will you attach as exhibits? | Contracts, correspondence, photos, etc. |

---

### Answer to Counterclaim

**When to use:** Defendant has filed a counterclaim against you (the Plaintiff) and you need to respond.

**Required Facts:**
| Fact | Question to Ask | Notes |
|------|----------------|-------|
| Counterclaim reference | Do you have the counterclaim to respond to? (file path) | Must respond paragraph by paragraph |
| For each allegation | Admit, deny, or lack knowledge? | Must address every numbered paragraph |
| Affirmative defenses | What defenses do you want to raise? (statute of limitations, failure to mitigate, estoppel, waiver, etc.) | List under FRCP 8(c) / ARCP 8(c) |
| Factual narrative | Your version of events — where does it differ from the counterclaim? | |

---

### Motion to Compel Discovery

**Required Facts:**
| Fact | Question to Ask | Notes |
|------|----------------|-------|
| Discovery type | What discovery is at issue? (interrogatories, document requests, depositions, admissions) | |
| Date served | When was the discovery served? | |
| Response deadline | When was the response due? | 30 days (FRCP 33/34), 30 days (ARCP) |
| What was deficient | Did they not respond at all, or were responses inadequate? Describe. | |
| Specific requests at issue | Which specific request numbers are you asking the court to compel? | |
| Meet and confer | Have you met and conferred with the opposing party? Date and outcome? | Required: FRCP 37(a)(1), LRCiv 7.2(j) |
| Relevance | How is the requested discovery relevant to your claims/defenses? | |
| Expenses/sanctions | Are you requesting attorney fees or sanctions under Rule 37? | |

---

### Motion to Dismiss Counterclaim (12(b) fact supplements)

**When to use:** Defendant has filed a counterclaim and you (Plaintiff) want to move to dismiss it.

**Required Facts (in addition to standard intake):**
| Fact | Question to Ask | Notes |
|------|----------------|-------|
| Counterclaim reference | Do you have the defendant's counterclaim? (file path) | Need to identify specific deficiencies |
| 12(b) subsection | Which 12(b) ground(s)? (1) subject matter jurisdiction, (2) personal jurisdiction, (3) venue, (4) insufficient process, (5) insufficient service, (6) failure to state a claim, (7) failure to join a party | |
| **If 12(b)(1) — Subject Matter Jurisdiction:** | Why does the court lack jurisdiction over the counterclaim? | Permissive vs. compulsory counterclaim? |
| **If 12(b)(6) — Failure to State a Claim:** | Which specific elements of the counterclaim are not adequately pled? | Identify each deficiency in the counterclaim |
| **If 12(b)(7) — Failure to Join:** | Who is the required party and why must they be joined? | FRCP 19 analysis |

---

### Motion for Summary Judgment (fact supplements)

**Required Facts (in addition to standard intake):**
| Fact | Question to Ask | Notes |
|------|----------------|-------|
| Undisputed facts | List each material fact you contend is undisputed (numbered) | Each must cite evidence |
| Supporting evidence | For each fact, what evidence supports it? (deposition testimony, documents, declarations, admissions) | Must be admissible evidence |
| Claims/defenses at issue | Which specific claims or defenses does this motion address? (all or partial?) | Can move on individual counts |
| Opposing evidence gaps | What evidence does the other side lack? | Shows no genuine dispute |

---

### Response/Opposition to Defendant's Motion (fact supplements)

**When to use:** Defendant has filed a motion (to dismiss, for summary judgment, etc.) and you need to oppose it.

**Required Facts (in addition to standard intake):**
| Fact | Question to Ask | Notes |
|------|----------------|-------|
| Motion being opposed | Do you have the defendant's motion? (file path) | Must address each argument |
| What is the defendant asking for? | Describe the relief defendant seeks | Dismissal, summary judgment, etc. |
| Disputed facts | Which facts from the defendant's motion do you dispute? What is your version? | |
| Supporting evidence | What evidence supports your version of disputed facts? | |
| Procedural objections | Any procedural problems with the defendant's motion? (untimely, improper format, etc.) | |

---

### Motion for Temporary Restraining Order / Preliminary Injunction

**Required Facts:**
| Fact | Question to Ask | Notes |
|------|----------------|-------|
| Irreparable harm | What harm will you suffer without the injunction? Why can't money damages fix it? | Must show irreparable harm |
| Likelihood of success | Why are you likely to win on the merits? | Key factor |
| Balance of hardships | How does the harm to you compare to the burden on the other side? | |
| Public interest | Is there a public interest angle? | |
| Specific relief | What exactly do you want the court to order? Be precise. | Must be specific and enforceable |
| Urgency | Why is this urgent? Is there an imminent deadline or event? | TRO = emergency; PI = less urgent |
| Ex parte? | Are you requesting this without notice to the other side? Why? | TRO only; must show why notice is impracticable |
| Bond | Are you prepared to post a bond/security? Proposed amount? | FRCP 65(c) |

---

### Garnishment (Post-Judgment)

**Required Facts:**
| Fact | Question to Ask | Notes |
|------|----------------|-------|
| Judgment amount | What is the total judgment amount? | |
| Judgment date | When was the judgment entered? | |
| Amount still owed | How much remains unsatisfied? | Credits for any partial payments |
| Post-judgment interest | Interest accrued since judgment? At what rate? | ARS 44-1201 |
| Garnishee | Who is the garnishee? (employer, bank name and address) | |
| Type | Wage garnishment or non-earnings (bank account)? | Different procedures |
| Debtor employment info | Debtor's employer name and address (if wage garnishment) | |
| Prior garnishment attempts | Any prior garnishment attempts? | |

---

## Common Document Templates

### Motion to Dismiss (FRCP 12(b) / ARCP 12(b))

```
I. INTRODUCTION
   Brief statement of what relief is sought and primary ground.

II. STATEMENT OF FACTS
   Relevant facts from the complaint/record.

III. LEGAL STANDARD
   Standard for 12(b) motion (e.g., 12(b)(6): failure to state a claim —
   "To survive a motion to dismiss, a complaint must contain sufficient
   factual matter, accepted as true, to state a claim to relief that is
   plausible on its face." Ashcroft v. Iqbal, 556 U.S. 662, 678 (2009))

IV. ARGUMENT
   A. First Ground for Dismissal
      Issue → Rule → Application → Conclusion
   B. Second Ground for Dismissal (if applicable)
      Issue → Rule → Application → Conclusion

V. CONCLUSION
   "For the foregoing reasons, Plaintiff Jason Crews, appearing pro se,
   respectfully requests that this Court grant this Motion to Dismiss
   [with/without prejudice] and for such other relief as the Court deems
   just and proper."
```

### Response/Opposition to Motion

```
I. INTRODUCTION
   Brief statement of why the motion should be denied.

II. COUNTER-STATEMENT OF FACTS
   Facts from respondent's perspective, citing record.

III. LEGAL STANDARD
   Same standard as movant cited, or corrected standard.

IV. ARGUMENT
   A. Response to First Ground
      Why movant's argument fails — distinguish cases, show facts support denial
   B. Response to Second Ground (if applicable)

V. CONCLUSION
   "For the foregoing reasons, Plaintiff Jason Crews, appearing pro se,
   respectfully requests that this Court deny Defendant's Motion and for
   such other relief as the Court deems just and proper."
```

### Motion for Summary Judgment (FRCP 56 / ARCP 56)

```
I. INTRODUCTION

II. STATEMENT OF UNDISPUTED MATERIAL FACTS
   Numbered paragraphs, each citing evidence in the record.
   (Federal: Separate Statement of Facts required per LRCiv 56.1)

III. LEGAL STANDARD
   "Summary judgment is appropriate when 'there is no genuine dispute as
   to any material fact and the movant is entitled to judgment as a matter
   of law.'" Fed. R. Civ. P. 56(a) / Ariz. R. Civ. P. 56(a).

IV. ARGUMENT
   IRAC for each issue, applying undisputed facts to law.

V. CONCLUSION
```

---

## Error Handling

- **No search results for a legal concept:** Try broader search terms, synonymous legal concepts, or related doctrines. If still nothing, note the gap for the user.
- **Validator can't access case text:** Mark as UNVERIFIED with explanation. The user decides whether to include it.
- **Too many REJECTED citations:** Offer to relaunch Researcher with refined search terms. Do not proceed to drafting with insufficient authority.
- **Document exceeds page limit:** Editor should flag this. Writer must condense arguments or split into separate filings.
- **Deadline concern identified:** Immediately alert the user, even before completing the full workflow.
