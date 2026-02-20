# Common Operational Commands — gofer-stack

## LXC Container Management (run from Proxmox)

```bash
ssh root@192.168.1.38       # SSH to Proxmox

pct list                    # List all containers and VMs
pct status 110              # Check container 110 status
pct start 110               # Start container
pct stop 110                # Graceful stop
pct shutdown 110            # Graceful shutdown
pct restart 110             # Restart
pct enter 110               # Open shell inside container
pct exec 110 -- docker ps   # Run a command inside container
pct config 110              # Show container configuration
pct df 110                  # Disk usage in container
```

## Docker Management (run inside an LXC)

```bash
docker ps                            # Running containers
docker ps -a                         # All containers (including stopped)
docker compose ps                    # Compose status
docker compose up -d                 # Start / update services
docker compose down                  # Stop all services
docker compose restart               # Restart all
docker compose restart [service]     # Restart one service
docker logs [name] --tail 50         # Recent logs
docker logs -f [name]                # Follow logs live
docker stats                         # Resource usage (CPU, RAM, net)
docker system prune -a               # Remove unused images/containers
```

## Sync Configs from Mac to Servers

Scripts are in `~/Documents/GitHub/gofer-stack/hosts/mac/scripts/`

```bash
SCRIPTS=~/Documents/GitHub/gofer-stack/hosts/mac/scripts

# Preview sync (dry-run — default, safe)
$SCRIPTS/sync-to-server.sh lxc110

# Actually sync files
$SCRIPTS/sync-to-server.sh --no-dry-run lxc110

# Sync AND apply changes (runs docker compose up -d on remote)
$SCRIPTS/sync-to-server.sh --no-dry-run -a lxc110

# Backup before syncing
$SCRIPTS/sync-to-server.sh --no-dry-run -b lxc110

# Sync everything
$SCRIPTS/sync-to-server.sh --no-dry-run -a all
```

Valid targets: `pi4`, `lxc110`, `lxc120`, `lxc130`, `lxc150`, `proxmox` (all LXCs), `all`

## Full Infrastructure Health Check

```bash
# Ping all hosts
for ip in 192.168.1.1 192.168.1.33 192.168.1.34 192.168.1.38 192.168.1.40 192.168.1.41 192.168.1.42 192.168.1.50; do
    ping -c1 -W1 $ip &>/dev/null && echo "UP:   $ip" || echo "DOWN: $ip"
done

# LXC container status
ssh root@192.168.1.38 "pct list"

# Docker status in each LXC
for id in 110 120 130 150; do
    echo "=== LXC $id ==="
    ssh root@192.168.1.38 "pct exec $id -- docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>/dev/null || echo "(not running)"
done

# Key service HTTP checks
for url in http://192.168.1.40:8096 http://192.168.1.41:81 http://192.168.1.42:8000 http://192.168.1.50:3000; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 $url)
    echo "$code  $url"
done

# DNS health
dig @192.168.1.34 google.com +short    # Primary (Pi 4)
dig @192.168.1.41 google.com +short    # Backup (LXC 120)
```

## Proxmox Storage Operations

```bash
# Check storage usage
pvesm status
df -h
lvs && vgs

# Unlock LXC 130 encrypted storage (Tier 3 manual unlock)
cryptsetup luksOpen /dev/nvme0n1p5 encrypted-manual
vgchange -ay pve-encrypted-manual
pvesm status | grep encrypted-manual   # Verify storage available
pct start 130

# Lock LXC 130 encrypted storage
pct stop 130
vgchange -an pve-encrypted-manual
cryptsetup luksClose encrypted-manual

# Backup a container
vzdump 110 --storage nas-backup --mode snapshot --compress zstd

# List backups
ls -lh /mnt/pve/nas-backup/dump/
```

## Emergency Procedures

### Container won't start
```bash
ssh root@192.168.1.38
pct status 110          # Check current state
pct config 110          # Check configuration
tail -f /var/log/pve/tasks/active   # Proxmox task log
pct start 110
pct stop 110 --force    # Force stop if hung
```

### Docker service stuck
```bash
pct enter 110
docker compose down
docker compose up -d
# Nuclear option:
docker compose down && docker system prune -af && docker compose up -d
```

### DNS completely down
```bash
# Temporary fix on client: set DNS to 1.1.1.1

# Restore Pi-hole (Pi 4)
ssh admin@192.168.1.34 "docker restart pihole"

# Or switch clients to backup: 192.168.1.41
```

### Proxmox web UI inaccessible
```bash
ssh root@192.168.1.38
systemctl status pveproxy
systemctl restart pveproxy pvedaemon
```

### Cannot reach a service by domain
```bash
# Test DNS resolution
dig gofer.cloud
nslookup jellyfin.gofer.cloud 192.168.1.34

# Test NPM is running
curl -I http://192.168.1.41:81

# Test service directly (bypass NPM)
curl -I http://192.168.1.40:8096    # Jellyfin direct
```
