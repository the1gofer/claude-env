---
name: tcpa
description: Process new TCPA call recordings. Trigger when user says "process tcpa recordings", "process new recordings", "run tcpa pipeline", "file tcpa recordings", or asks to transcribe/review/file new recordings in the TCPA folder.
---

# TCPA Recording Pipeline Skill

Automate the full pipeline: run the process script, review and correct all decisions, confirm with the user, then file.

## Constants

| Key | Value |
|-----|-------|
| Script | `python3 /Users/jasoncrews/Documents/Unified/T01\ -\ TCPA/tcpa.py` |
| Inbox | `/Users/jasoncrews/Documents/Unified/T01 - TCPA/Inbox/` |
| Staging | `/tmp/tcpa_pipeline/pending_review/` |
| Decisions | `/tmp/tcpa_pipeline/decisions.json` |
| Review | `/tmp/tcpa_pipeline/review.json` |

## Instructions

Execute these steps in order:

---

### Step 1: Run the Process Pipeline

Run via Bash with a 10-minute timeout:

```bash
python3 /Users/jasoncrews/Documents/Unified/T01\ -\ TCPA/tcpa.py process
```

Show the user the full output. Note how many recordings were found and transcribed.

If there are 0 new audio files in the Inbox, stop here and tell the user there's nothing new to process.

---

### Step 2: Read All Staged Transcripts

For each `.txt` file in `/tmp/tcpa_pipeline/pending_review/`, read its contents. Also read `/tmp/tcpa_pipeline/decisions.json` to see the auto-generated decisions.

---

### Step 3: Review and Correct decisions.json

Analyze every transcript carefully. For each recording, determine:

**Decision (keep or discard):**
- `keep` — contains substantive telemarketing content, a real pitch, or useful evidence
- `discard` — empty, ringing only, unintelligible, or is a **RoboKiller bot trap response** (the caller is answering RoboKiller's trivia/game questions — NOT a real telemarketing message to us)

**Campaign (for keeps):**
Use the correct campaign label based on what was actually pitched:
- `ACA Health Insurance` — Marketplace/ACA/Obamacare/health insurance subsidies (NOT Medicare)
- `Medicare` — specifically pitching Medicare Advantage or supplement plans
- `Final Expense` — life insurance for burial/final expenses
- `Home Security` — home security systems (NOT "Home Improvement")
- `Home Improvement` — solar, windows, roofing, HVAC, etc.
- `Auto Warranty` — extended car warranty
- `Auto Insurance` — car insurance
- `Auto Accident Claim` — accident/injury claim solicitation
- `Debt Hardship` — debt relief, credit card hardship
- `Tax Debt` — IRS tax debt relief
- `Precious Metals` — gold/silver investment
- `Other` — real call but doesn't fit above (benefit cards, gym memberships, surveys, etc.)

**Common auto-categorization errors to fix:**
- ACA/Marketplace calls are often mislabeled as `Medicare` — check if they say "Marketplace", "ACA", "Obamacare", or "government subsidies for health insurance"
- Home security calls ("free smart home system", "security system") are often mislabeled as `Home Improvement`
- RoboKiller trap responses (caller answering trivia, games, math problems) are often mislabeled as `Final Expense` or other campaigns — these should be `discard`

**Note field:** Add a brief note for any `keep` describing who was identified (name, organization, callback number if given).

Write the corrected decisions to `/tmp/tcpa_pipeline/decisions.json` using the Write tool.

---

### Step 4: Present Summary for Confirmation

Show the user a summary table before filing:

```
## Today's Recordings — Review Summary

### KEEP (N recordings)
| Recording | Time | Who | Campaign | Note |
|-----------|------|-----|----------|------|
| R-XXXXX   | HH:MM | Name / Org | Campaign | ... |

### DISCARD (N recordings)
| Recording | Time | Reason |
|-----------|------|--------|
| R-XXXXX   | HH:MM | RoboKiller trap / unintelligible / ringing only |
```

Then ask the user:

> "Does this look correct? I'll file the keeps and delete the discards."

Use AskUserQuestion with options: "Looks good, file them" / "I need to make changes first".

If the user wants changes, ask them to describe the corrections and update decisions.json accordingly before proceeding.

---

### Step 5: File the Recordings

Once the user confirms, run:

```bash
python3 /Users/jasoncrews/Documents/Unified/T01\ -\ TCPA/tcpa.py file
```

Show the full output to the user.

---

### Step 6: Confirm Results

After filing, verify the recordings landed in the right place:

```bash
find "/Users/jasoncrews/Documents/Unified/T01 - TCPA/Recordings" -name "*.mp3" -newer /tmp/tcpa_pipeline/decisions.json | sort
find "/Users/jasoncrews/Documents/Unified/T01 - TCPA/Transcripts" -name "*.md" -newer /tmp/tcpa_pipeline/decisions.json | sort
```

Report to the user how many recordings and transcripts were filed and where.

---

## Error Handling

- **Script not found:** Path is `python3 /Users/jasoncrews/Documents/Unified/T01 - TCPA/tcpa.py`
- **No new files:** Tell the user the Inbox has no new audio files to process
- **Whisper timeout:** The transcription step can take several minutes for long recordings — use a 10-minute timeout on the process command
- **decisions.json missing:** Run the process step first before trying to file

### Full Disk Access (FDA) Permission Error

**Before running Step 1**, verify FDA is granted by checking if the call history DB is readable:

```bash
python3 -c "
import sqlite3, os
db = os.path.expanduser('~/Library/Application Support/CallHistoryDB/CallHistory.storedata')
try:
    conn = sqlite3.connect(db)
    conn.execute('SELECT count(*) FROM ZCALLRECORD')
    print('FDA OK')
except Exception as e:
    print(f'FDA ERROR: {e}')
"
```

If the output is **`FDA ERROR`** (permission denied, unable to open, or 0 rows), **stop immediately** and tell the user:

> ⚠️ **Full Disk Access required.** Terminal does not have permission to read the iPhone call history database. Without this, all call notes will have a blank `caller_ID` field.
>
> **To fix:** System Settings → Privacy & Security → Full Disk Access → enable Terminal (or your terminal app). Then re-run in a new terminal window.

Do **not** proceed with the pipeline — do not create empty stub CSVs, do not continue to transcription. The user must grant FDA and start a new session.
