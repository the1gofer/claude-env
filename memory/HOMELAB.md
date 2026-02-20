# Homelab Infrastructure — gofer-stack

## Network: 192.168.1.0/24 | Gateway: 192.168.1.1 (Nighthawk Router)

## Physical Hosts

| Host     | IP            | SSH User    | Role                              |
|----------|---------------|-------------|-----------------------------------|
| proxmox  | 192.168.1.38  | root        | Proxmox VE hypervisor             |
| pi4      | 192.168.1.34  | admin       | Raspberry Pi 4 — primary DNS, edge services |
| pi5      | 192.168.1.69  | RasPbxAdmin | Raspberry Pi 5 — future PBX/telephony |
| nas      | 192.168.1.33  | nasadmin    | Synology NAS — storage & backups  |

## LXC Containers (all running on Proxmox 192.168.1.38)

| ID  | Name           | IP            | Purpose                                               |
|-----|----------------|---------------|-------------------------------------------------------|
| 110 | media          | 192.168.1.40  | Jellyfin, Sonarr, Radarr, Prowlarr, Bazarr, qBittorrent+Gluetun VPN |
| 120 | infrastructure | 192.168.1.41  | Nginx Proxy Manager, Pi-hole (backup DNS), Cloudflared |
| 130 | documents      | 192.168.1.42  | Paperless-ngx, Immich — **LUKS encrypted storage**    |
| 150 | utilities      | 192.168.1.50  | Homepage dashboard, n8n, Stirling-PDF, Homebox        |

## SSH Access
- All hosts use SSH key authentication: `~/.ssh/id_ed25519`
- `~/.ssh/config` aliases on Mac: `proxmox`, `pi4`, `pi5`, `nas`
- Physical hosts: `ssh <alias>` or `ssh <user>@<ip>`
- LXC containers (two methods):
  - Direct: `ssh root@<lxc-ip>`
  - Via Proxmox: `ssh root@192.168.1.38` then `pct enter <id>`

## gofer-stack Repository
- **Mac:** `~/Documents/GitHub/gofer-stack/`
- **Linux:** `~/gofer-stack/`
- Automation scripts: `hosts/mac/scripts/`
- Infrastructure metadata: `infra/hosts.yaml` (authoritative for SSH users)
- Full quick reference: `11-Quick-Reference.md`

## LXC Boot Order (startup dependencies)
1. **LXC 120** (infrastructure) — must start first; provides NPM reverse proxy and backup DNS
2. **LXC 110** (media) — depends on NPM being up
3. **LXC 150** (utilities) — depends on NPM being up
4. **LXC 130** (documents) — requires **manual LUKS unlock** before starting

## LXC 130 — LUKS Encrypted Storage
LXC 130 uses LUKS encryption on a Proxmox NVMe partition. Steps to start:
```bash
ssh root@192.168.1.38
cryptsetup luksOpen /dev/nvme0n1p5 encrypted-manual
# Enter LUKS passphrase when prompted
vgchange -ay pve-encrypted-manual
pvesm status | grep encrypted-manual   # Confirm storage is available
pct start 130
```
To lock again:
```bash
pct stop 130
vgchange -an pve-encrypted-manual
cryptsetup luksClose encrypted-manual
```

## NFS Mounts (from Synology NAS 192.168.1.33)
- **LXC 110:** `/mnt/nas/media` ← `192.168.1.33:/volume1/data/media`
- **LXC 110:** `/mnt/nas/downloads` ← `192.168.1.33:/volume1/data/downloads`
- **LXC 130:** `/mnt/nas/documents` ← `192.168.1.33:/volume1/data/documents`
- **LXC 130:** `/mnt/nas/photos` ← `192.168.1.33:/volume1/data/photos`

## DNS Architecture
- **Primary DNS:** Pi 4 at `192.168.1.34:53` → Cloudflared `:5053` → `1.1.1.1`
- **Backup DNS:** LXC 120 at `192.168.1.41:53`
- **DNS VIP (planned):** `192.168.1.53` (floating via Keepalived)
- Test: `dig @192.168.1.34 google.com +short`

## Docker Compose File Locations (on each LXC)
- **LXC 110:** `/srv/docker/media/docker-compose.yml`
- **LXC 120:** `/srv/docker/npm/`, `/srv/docker/pihole/`, `/srv/docker/cloudflared/`
- **LXC 130:** `/srv/docker/paperless/`, `/srv/docker/immich/`
- **LXC 150:** `/srv/docker/homepage/`, `/srv/docker/n8n/`

## Proxmox Storage Tiers
- **Tier 1:** Auto-start, no encryption (LXC 110, 120, 150)
- **Tier 2:** Encrypted, auto-unlock at boot (Windows VM 160)
- **Tier 3:** Encrypted, manual unlock required (LXC 130)

## Cloudflare / External Access
- Domain: `gofer.cloud` via Cloudflare Tunnel
- Externally accessible: `jellyfin`, `jellyseerr`, `paperless`, `immich` at `*.gofer.cloud`
- Internal only: Sonarr, Radarr, Prowlarr, qBittorrent, NPM admin
