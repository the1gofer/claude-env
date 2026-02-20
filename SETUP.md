# New Machine Setup

One-page cheat sheet. Clone the repo and run the bootstrap — done.

---

## Mac (first time)

```bash
cd ~/Documents/GitHub
git clone git@github.com:the1gofer/claude-env.git
bash claude-env/setup.sh
```

## Linux (first time)

```bash
cd ~
git clone git@github.com:the1gofer/claude-env.git
bash claude-env/setup.sh
```

---

## Verify it worked

```bash
ls -la ~/.claude/skills    # Should show symlink → .../claude-env/skills
ls -la ~/.claude/agents    # Should show symlink → .../claude-env/agents
```

Then open Claude Code and try:
```
/ssh
/infra
/scripts
/sync
```

---

## Update from GitHub

```bash
# Mac
cd ~/Documents/GitHub/claude-env && git pull && bash setup.sh

# Linux
cd ~/claude-env && git pull && bash setup.sh
```

Use `bash setup.sh --force` to also refresh the MEMORY.md files.

---

## Add a new skill

```bash
mkdir skills/my-skill
# write skills/my-skill/SKILL.md
git add . && git commit -m "Add my-skill" && git push
# No re-run of setup.sh needed — symlink picks it up immediately
```

---

## What setup.sh does

1. Creates `~/.claude/skills/` → symlink to this repo's `skills/`
2. Creates `~/.claude/agents/` → symlink to this repo's `agents/`
3. Writes `~/.claude/MEMORY.md` (global Claude memory)
4. Writes project-specific MEMORY.md for the gofer-stack working directory

---

## Skills reference

| Skill      | Usage              | Description                              |
|------------|--------------------|------------------------------------------|
| `/ssh`     | `/ssh proxmox`     | SSH into any homelab host by name        |
| `/infra`   | `/infra`           | Full infrastructure health check script  |
| `/scripts` | `/scripts sync`    | List/find gofer-stack automation scripts |
| `/sync`    | `/sync lxc110`     | Sync configs from Mac repo to servers    |

## Agent reference

| Agent         | Description                                        |
|---------------|----------------------------------------------------|
| `homelab-ops` | Full homelab context — use for ops and troubleshooting |
