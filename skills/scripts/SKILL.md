---
name: scripts
description: List and discover gofer-stack automation scripts from hosts/mac/scripts/. Shows descriptions, usage, and example commands. Accepts a filter to narrow by name or category.
---

Help the user find and use gofer-stack automation scripts.

## Script Locations
- **Mac:** `~/Documents/GitHub/gofer-stack/hosts/mac/scripts/`
- **Linux:** `~/gofer-stack/hosts/mac/scripts/`

## Script Catalog

| Script                        | Type   | Description |
|-------------------------------|--------|-------------|
| `sync-to-server.sh`           | bash   | Sync docker-compose configs from Mac repo to servers. Targets: pi4, lxc110, lxc120, lxc130, lxc150, proxmox, all. Dry-run by default (safe). |
| `backup-server-files.sh`      | bash   | Backup important server config files to NAS at `nasadmin@192.168.1.33:/volume1/backups/`. |
| `cleanup-server-files.sh`     | bash   | Remove unwanted files (docs, temp files) from servers. |
| `setup-git-on-servers.sh`     | bash   | Initialize git repos on servers with sparse checkout configured for their role. |
| `setup-ssh-keys-on-servers.sh`| bash   | Copy SSH public key from Mac to all servers for key-based authentication. |
| `fix-git-repos.sh`            | bash   | Re-initialize broken git repos with correct sparse checkout settings. |
| `manage-pihole.sh`            | bash   | Manage Pi-hole containers: start, stop, restart, status, list DNS records. |
| `rebuild-pi4-env.sh`          | bash   | Rebuild the Pi 4 Docker environment from scratch. |
| `validate-folder-structure.sh`| bash   | Validate that the gofer-stack repo folder structure is correct and consistent. |
| `script-template.sh`          | bash   | Template for creating new standardized scripts (copy this to start new scripts). |
| `diagnose-domain.py`          | python | Diagnose domain resolution: DNS, NPM proxy config, SSL certificates end-to-end. |
| `list-npm-proxies.py`         | python | List all Nginx Proxy Manager proxy host configurations via API. |
| `verify-ssl-e2e.py`           | python | Verify SSL/TLS end-to-end for a domain: cert validity, chain, redirect behavior. |

## Common Flags (all bash scripts)
- `-d` / `--dry-run` — preview mode (default — safe, won't make changes)
- `--no-dry-run` / `--execute` — actually execute the operation
- `-v` / `--verbose` — detailed per-file output
- `-b` / `--backup` — backup to NAS before modifying
- `-a` / `--apply` — apply changes after sync (docker compose up -d)
- `-h` / `--help` — show full usage for that script

## Python Script Setup
Python scripts require a virtual environment:
```bash
cd ~/Documents/GitHub/gofer-stack/hosts/mac/scripts
source venv/bin/activate
python diagnose-domain.py <domain>
```

## Instructions

Parse "$ARGUMENTS":

**If empty or "list":** Display the full Script Catalog table above plus the script directory path.

**If matches a script name (partial OK):** Show detailed usage for that script:
- Full path command
- Purpose
- Key flags and examples
- Dry-run reminder if it's a write operation

**If matches a category keyword:**
- "sync" → show sync-to-server.sh details
- "backup" → show backup-server-files.sh
- "pihole" → show manage-pihole.sh
- "git" → show setup-git-on-servers.sh and fix-git-repos.sh
- "ssh" / "keys" → show setup-ssh-keys-on-servers.sh
- "diagnose" / "dns" / "domain" → show diagnose-domain.py
- "ssl" → show verify-ssl-e2e.py
- "npm" / "proxy" → show list-npm-proxies.py
- "python" → list only the Python scripts with venv setup instructions

**Always include the full path in example commands.**

**Dry-run reminder:** For any script that modifies files or runs docker commands, always mention that dry-run is the default and show both the preview and execution forms:
```bash
# Preview (safe, default)
~/Documents/GitHub/gofer-stack/hosts/mac/scripts/<script> [target]

# Execute for real
~/Documents/GitHub/gofer-stack/hosts/mac/scripts/<script> --no-dry-run [target]
```
