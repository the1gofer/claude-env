---
name: ssh
description: SSH into any gofer-stack homelab host by name. Knows the correct user, IP, and method for proxmox, pi4, pi5, nas, and LXC containers (lxc110, lxc120, lxc130, lxc150).
---

Help the user connect to a gofer-stack homelab host via SSH.

## Host Map

| Name    | IP            | SSH User    | Type     | Notes                                         |
|---------|---------------|-------------|----------|-----------------------------------------------|
| proxmox | 192.168.1.38  | root        | Physical | Proxmox VE hypervisor                         |
| pi4     | 192.168.1.34  | admin       | Physical | Raspberry Pi 4 — primary DNS                  |
| pi5     | 192.168.1.69  | RasPbxAdmin | Physical | Raspberry Pi 5 — future PBX                   |
| nas     | 192.168.1.33  | nasadmin    | Physical | Synology NAS                                  |
| lxc110  | 192.168.1.40  | root        | LXC      | Media: Jellyfin, Sonarr, Radarr, qBittorrent  |
| lxc120  | 192.168.1.41  | root        | LXC      | Infrastructure: NPM, Pi-hole, Cloudflared     |
| lxc130  | 192.168.1.42  | root        | LXC      | Documents: Paperless, Immich (LUKS encrypted) |
| lxc150  | 192.168.1.50  | root        | LXC      | Utilities: Homepage, n8n, Stirling-PDF        |

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
ssh root@192.168.1.38
```

**If argument matches an LXC container (lxc110, lxc120, lxc130, lxc150):**
Show two access methods:

Method 1 — Direct SSH to container:
```bash
ssh root@<lxc-ip>
```

Method 2 — Enter via Proxmox host:
```bash
ssh root@192.168.1.38
pct enter <container-id>
```

Also show how to check if the container is running first:
```bash
ssh root@192.168.1.38 "pct status <id>"
```

**If argument is lxc130:** Add this warning:
> LXC 130 stores LUKS-encrypted data. If the container is stopped, the encrypted storage must be manually unlocked first. Run `/ssh proxmox` and then use the LUKS unlock procedure.

**Authentication note:** All hosts use SSH key auth with `~/.ssh/id_ed25519`.
If connection is refused, verify keys have been deployed: run the `setup-ssh-keys-on-servers.sh` script from the gofer-stack repo.

**If the host name isn't recognized:** List the valid host names from the table and ask which the user meant.
