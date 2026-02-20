---
name: sync
description: Sync docker-compose configs from the gofer-stack Mac repo to homelab servers using sync-to-server.sh. Generates the correct command for any target (pi4, lxc110, lxc120, lxc130, lxc150, proxmox, all).
---

Generate the correct `sync-to-server.sh` command for syncing gofer-stack configs to servers.

## Script Location
- **Mac:** `~/Documents/GitHub/gofer-stack/hosts/mac/scripts/sync-to-server.sh`
- **Linux:** `~/gofer-stack/hosts/mac/scripts/sync-to-server.sh`

## Valid Targets

| Target  | Description                                            |
|---------|--------------------------------------------------------|
| pi4     | Raspberry Pi 4 (192.168.1.34)                         |
| lxc110  | LXC 110 — Media (192.168.1.40)                        |
| lxc120  | LXC 120 — Infrastructure (192.168.1.41)               |
| lxc130  | LXC 130 — Documents (192.168.1.42) — LUKS encrypted   |
| lxc150  | LXC 150 — Utilities (192.168.1.50)                    |
| proxmox | All Proxmox LXCs (110, 120, 130, 150)                 |
| all     | All servers (Pi 4 + all LXCs)                         |

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

**Special warning for lxc130:** LXC 130 uses LUKS-encrypted storage. Before syncing, verify the container is running:
```bash
ssh root@192.168.1.38 "pct status 130"
```
If it shows stopped, the encrypted storage needs manual unlock first — use `/ssh proxmox` and the LUKS unlock procedure before syncing.

**If target isn't recognized:** List the valid targets from the table above.
