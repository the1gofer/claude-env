---
name: persistent
description: Start a new Claude Code session on LXC 126 (Proxmox homelab) with a given prompt, enable Remote Control, and return the URL so the user can interact with it from claude.ai or mobile. Trigger when user says "in a persistent session...", "start a persistent session and...", "run this persistently...", "launch a homelab session to...", etc.
---

The user wants to start a persistent Claude Code session on the homelab with a specific task.

## Infrastructure

| Detail           | Value                              |
|------------------|------------------------------------|
| LXC 126 IP       | `192.168.39.26`                    |
| SSH user         | `root`                             |
| Docker container | `claude-persistent`                |
| Tmux session     | `claude` (always named this)       |
| Target format    | `claude:<window-name>`             |

## Your job — execute this fully, do not just show commands

Parse "$ARGUMENTS" as the task/prompt the user wants to run in the persistent session.

**Step 1 — Derive a slug** (2-3 word kebab-case, e.g. `sonarr-import`, `lead-tracker`).

**Step 2 — Ensure the tmux session is alive.**

Run this via Bash:
```bash
ssh root@192.168.39.26 "docker exec claude-persistent tmux has-session -t claude 2>/dev/null || docker exec -u claude -d claude-persistent tmux new-session -d -s claude -x 220 -y 50"
```

**Step 3 — Kill any existing window with the same slug** (avoid duplicate targeting errors):
```bash
ssh root@192.168.39.26 "docker exec claude-persistent tmux kill-window -t 'claude:<slug>' 2>/dev/null; true"
```

**Step 4 — Create the new window and start claude with remote control:**
```bash
ssh root@192.168.39.26 "docker exec claude-persistent tmux new-window -n <slug> -t claude && docker exec claude-persistent tmux send-keys -t 'claude:<slug>' 'claude --remote-control' Enter"
```

**Step 5 — Wait for the remote control URL to appear** (claude takes ~5-10s to start):
```bash
sleep 12 && ssh root@192.168.39.26 "docker exec claude-persistent tmux capture-pane -t 'claude:<slug>' -p -S -50"
```

Parse the output for the remote control URL (looks like `https://claude.ai/...` or similar). Extract and display it prominently to the user.

**Step 6 — Send the prompt into the session:**

Escape the prompt for shell safety, then send it as keystrokes:
```bash
ssh root@192.168.39.26 "docker exec claude-persistent tmux send-keys -t 'claude:<slug>' '<escaped-prompt>' Enter"
```

Use `printf %q` or careful quoting to safely pass the prompt text. If the prompt contains single quotes, escape them properly.

**Step 7 — Report back to the user:**

Tell the user:
- The remote control URL (copy-pasteable)
- The slug/window name
- That the prompt has been sent and the session is running
- How to reconnect if needed:
  ```bash
  ssh -t root@192.168.39.26 "docker exec -it claude-persistent tmux attach-session"
  ```
  Then `Ctrl+b w` → select `<slug>`

---

## Handling `list` / `attach` / `sessions`

If "$ARGUMENTS" is one of those words, run and display:
```bash
ssh root@192.168.39.26 "docker exec claude-persistent tmux list-windows -t claude"
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `no server running on /tmp/tmux-1000/default` | Run: `ssh root@192.168.39.26 "docker exec -u claude -d claude-persistent tmux new-session -d -s claude -x 220 -y 50"` |
| URL not found in pane output | Wait longer: capture again with `sleep 5 && tmux capture-pane ...` |
| `can't find pane/window` | Kill dupes by index, then retry step 4 |
| Container not running | Check: `ssh root@192.168.39.26 "docker ps --filter name=claude-persistent"` |

---

## Notes

- Always execute — never just show commands
- The tmux session inside the container is always named `claude`
- Multiple tasks can run in parallel as separate named windows
- SSH uses key auth via `~/.ssh/id_ed25519`
