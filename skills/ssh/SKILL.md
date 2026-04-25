---
name: ssh
description: SSH into any gofer-stack homelab host by name. Knows the correct user, IP, and method for proxmox, pi4, pi5, nas, and LXC containers (lxc110, lxc122, lxc124, lxc125, lxc126, lxc127, lxc128).
---

Help the user connect to a gofer-stack homelab host via SSH.

## Host Map

| Name    | IP             | SSH User    | Type     | Notes                                         |
|---------|----------------|-------------|----------|-----------------------------------------------|
| proxmox | 192.168.39.100 | root        | Physical | Proxmox VE hypervisor                         |
| pi4     | 192.168.39.3   | admin       | Physical | Raspberry Pi 4 — DNS/Services                 |
| pi5     | 192.168.39.4   | RasPbxAdmin | Physical | Raspberry Pi 5 — 3CX SBC                      |
| nas     | 192.168.39.2   | nasadmin    | Physical | Synology NAS (16TB)                           |
| lxc110  | 192.168.39.10  | root        | LXC      | Infrastructure: NPM, Portainer                |
| lxc122  | 192.168.39.22  | root        | LXC      | Media: Jellyfin                               |
| lxc124  | 192.168.39.24  | root        | LXC      | FlareSolverr (Prowlarr helper)                |
| lxc125  | 192.168.39.25  | root        | LXC      | Documents: Paperless-ngx                      |
| lxc126  | 192.168.39.26  | root        | LXC      | Utilities: Homepage, Stirling-PDF             |
| lxc127  | 192.168.39.27  | root        | LXC      | Audiobookshelf                                |
| lxc128  | 192.168.39.28  | root        | LXC      | ARR Stack: Sonarr, Radarr, Prowlarr, qBit    |

## Instructions

Parse "$ARGUMENTS" (the host name the user provided).

**If no argument or "list":** Display the full host map table above.

**If argument matches a physical host (proxmox, pi4, pi5, nas):**
Show the SSH command two ways:
1. Using the `~/.ssh/config` alias (if it exists): `ssh <hostname>`
2. Explicit: `ssh <user>@<ip>`

Example for proxmox:
```bash
ssh proxmox
# or explicitly:
ssh root@192.168.39.100
```

**If argument matches an LXC container (lxc110, lxc122, lxc124, lxc125, lxc126, lxc127, lxc128):**
Show two access methods:

Method 1 — Direct SSH to container:
```bash
ssh root@<lxc-ip>
```

Method 2 — Enter via Proxmox host:
```bash
ssh root@192.168.39.100
pct enter <container-id>
```

Also show how to check if the container is running first:
```bash
ssh root@192.168.39.100 "pct status <id>"
```

**If argument is lxc125:** Add this note:
> LXC 125 runs Paperless-ngx with document storage on NAS mounts.

**Authentication note:** All hosts use SSH key auth with `~/.ssh/id_ed25519`.
If connection is refused, verify keys have been deployed: run the `setup-ssh-keys-on-servers.sh` script from the gofer-stack repo.

**If the host name isn't recognized:** List the valid host names from the table and ask which the user meant.
# test
