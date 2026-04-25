---
name: sync
description: Sync docker-compose configs from the gofer-stack Mac repo to homelab servers using sync-to-server.sh. Generates the correct command for any target (pi4, lxc110, lxc122, lxc125, lxc126, lxc127, lxc128, proxmox, all).
---

Generate the correct `sync-to-server.sh` command for syncing gofer-stack configs to servers.

## Script Location
- **Mac:** `~/Documents/GitHub/gofer-stack/hosts/mac/scripts/sync-to-server.sh`
- **Linux:** `~/gofer-stack/hosts/mac/scripts/sync-to-server.sh`

**Note:** This script may not exist yet. If the user runs it and gets "file not found", the script needs to be created first.

## Valid Targets

| Target  | Description                                                |
|---------|------------------------------------------------------------|
| pi4     | Raspberry Pi 4 (192.168.39.3)                             |
| lxc110  | LXC 110 — Infrastructure: NPM, Portainer (192.168.39.10) |
| lxc122  | LXC 122 — Media: Jellyfin (192.168.39.22)                |
| lxc124  | LXC 124 — FlareSolverr (192.168.39.24)                   |
| lxc125  | LXC 125 — Documents: Paperless-ngx (192.168.39.25)       |
| lxc126  | LXC 126 — Utilities: Homepage, Stirling-PDF (192.168.39.26) |
| lxc127  | LXC 127 — Audiobookshelf (192.168.39.27)                 |
| lxc128  | LXC 128 — ARR Stack: Sonarr, Radarr, etc. (192.168.39.28) |
| proxmox | All Proxmox LXCs                                          |
| all     | All servers (Pi 4 + all LXCs)                             |

## Flags
- `--no-dry-run` / `--execute` — actually sync files (dry-run is the default)
- `-a` / `--apply` — after syncing, run `docker compose up -d` on the remote server
- `-b` / `--backup` — backup server files to NAS before modifying

## Sync Workflow
1. Edit config files in the Mac's local repo (`~/Documents/GitHub/gofer-stack/`)
2. Optionally commit and push (for version history)
3. Run sync-to-server.sh to push files to target server(s)
4. Optionally use `-a` to auto-apply (docker compose up -d)

## Instructions

Parse "$ARGUMENTS":

**If empty:** Explain the sync workflow and show the target table. Ask which host to sync.

**If matches a valid target:**

Show the three-step command sequence:

```bash
SCRIPTS=~/Documents/GitHub/gofer-stack/hosts/mac/scripts

# Step 1: Preview (dry-run — default, safe)
$SCRIPTS/sync-to-server.sh <target>

# Step 2: Sync files for real
$SCRIPTS/sync-to-server.sh --no-dry-run <target>

# Step 3: Sync AND apply (docker compose up -d on remote)
$SCRIPTS/sync-to-server.sh --no-dry-run -a <target>
```

Always start with Step 1 first for safety. Only proceed to Step 2/3 after confirming the preview looks correct.

**If "$ARGUMENTS" contains "apply" or "-a":** Include `-a` in the recommended command and note it will run `docker compose up -d` after syncing.

**If "$ARGUMENTS" contains "backup" or "-b":** Include `-b` flag and note it will backup current server files to NAS before modifying.

**If target isn't recognized:** List the valid targets from the table above.
