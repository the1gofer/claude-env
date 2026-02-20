# claude-env

Claude Code environment for the gofer-stack homelab. Skills, agents, and memory files — synced across machines via GitHub.

> **New machine?** See [SETUP.md](SETUP.md) for the two-command bootstrap.

---

## New Machine Setup

### macOS

```bash
cd ~/Documents/GitHub
git clone git@github.com:YOUR_USERNAME/claude-env.git
bash claude-env/setup.sh
```

### Linux

```bash
cd ~
git clone git@github.com:YOUR_USERNAME/claude-env.git
bash claude-env/setup.sh
```

### Verify

```bash
ls -la ~/.claude/skills    # → symlink to claude-env/skills/
ls -la ~/.claude/agents    # → symlink to claude-env/agents/
```

---

## Sync & Update

Pull latest from GitHub and re-run setup on any machine:

```bash
# macOS
cd ~/Documents/GitHub/claude-env && git pull && bash setup.sh

# Linux
cd ~/claude-env && git pull && bash setup.sh
```

Use `--force` to also refresh MEMORY.md:

```bash
bash setup.sh --force
```

---

## Skills

Use these slash commands inside Claude Code:

| Skill      | Usage              | Description                                          |
|------------|--------------------|------------------------------------------------------|
| `/ssh`     | `/ssh proxmox`     | SSH into any homelab host by name (shows user + IP)  |
| `/infra`   | `/infra`           | Generates a health-check script (ping/LXC/services/DNS) |
| `/scripts` | `/scripts`         | Lists and describes all gofer-stack automation scripts |
| `/sync`    | `/sync lxc110`     | Generates the correct sync-to-server.sh command      |

All skills accept a filter argument. Example: `/infra dns`, `/scripts backup`, `/ssh lxc120`.

---

## Agents

| Agent         | Model   | Description                                                   |
|---------------|---------|---------------------------------------------------------------|
| `homelab-ops` | Opus    | Full homelab context — network, SSH, services, troubleshooting |

---

## Memory Files

The `memory/` directory contains structured docs that get written into Claude's memory on setup:

| File            | Contents                                           |
|-----------------|----------------------------------------------------|
| `HOMELAB.md`    | Network topology, SSH users, LXC details, LUKS, NFS |
| `SERVICES.md`   | All service URLs (internal + gofer.cloud domains)  |
| `COMMANDS.md`   | LXC management, Docker, sync, health check, emergency procedures |

---

## Repository Structure

```
claude-env/
├── SETUP.md               ← New machine cheat sheet
├── README.md
├── setup.sh               ← Bootstrap script (run this)
├── .gitignore
├── skills/
│   ├── ssh/SKILL.md       ← /ssh [host]
│   ├── infra/SKILL.md     ← /infra [filter]
│   ├── scripts/SKILL.md   ← /scripts [filter]
│   └── sync/SKILL.md      ← /sync [host]
├── agents/
│   └── homelab-ops.md     ← Homelab operations agent
└── memory/
    ├── HOMELAB.md
    ├── SERVICES.md
    └── COMMANDS.md
```

---

## Adding New Skills

```bash
mkdir skills/my-skill
# Create skills/my-skill/SKILL.md with frontmatter + prompt
git add . && git commit -m "Add my-skill" && git push
# Available immediately on all machines — no setup.sh re-run needed
```

Skill format (`SKILL.md`):
```markdown
---
name: skill-name
description: What this skill does (used for auto-invocation matching)
---

Your skill prompt here. Use $ARGUMENTS for user-provided args.
```

---

## Security

- No passwords, tokens, or SSH private keys are stored in this repo
- SSH uses key auth: `~/.ssh/id_ed25519` (exists on each machine independently)
- Service passwords live in docker-compose `.env` files on the servers
- Memory files reference *where* to find credentials, not the credentials themselves

---

## gofer-stack Reference

The homelab infrastructure repo lives at:
- Mac: `~/Documents/GitHub/gofer-stack/`
- Linux: `~/gofer-stack/`

Key files:
- `11-Quick-Reference.md` — IP addresses, ports, URLs, emergency procedures
- `infra/hosts.yaml` — authoritative SSH users per host
- `hosts/mac/scripts/` — automation scripts
