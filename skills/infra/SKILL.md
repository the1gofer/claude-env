---
name: infra
description: Check full gofer-stack infrastructure status. Generates a ready-to-run bash script to ping all hosts, check LXC container status, verify service health via curl, and test DNS. Accepts filters: ping, lxc, services, dns.
---

Generate a bash health-check script for the gofer-stack homelab infrastructure.

## Infrastructure Reference

### Physical Hosts
| Host    | IP            |
|---------|---------------|
| Router  | 192.168.1.1   |
| NAS     | 192.168.1.33  |
| Pi 4    | 192.168.1.34  |
| Pi 5    | 192.168.1.69  |
| Proxmox | 192.168.1.38  |

### LXC Containers
| ID  | IP            | Purpose          |
|-----|---------------|------------------|
| 110 | 192.168.1.40  | Media            |
| 120 | 192.168.1.41  | Infrastructure   |
| 130 | 192.168.1.42  | Documents (LUKS) |
| 150 | 192.168.1.50  | Utilities        |

### Service Endpoints
| Service        | URL                           |
|----------------|-------------------------------|
| Jellyfin       | http://192.168.1.40:8096      |
| NPM Admin      | http://192.168.1.41:81        |
| Pi-hole (Pi4)  | http://192.168.1.34:8053      |
| Paperless      | http://192.168.1.42:8000      |
| Homepage       | http://192.168.1.50:3000      |

## Instructions

Parse "$ARGUMENTS" to determine which sections to include:

- Empty or "all" → include all four sections below
- "ping" → only ping checks
- "lxc" or "containers" → only LXC/Docker checks
- "services" → only HTTP service checks
- "dns" → only DNS checks

Output a ready-to-run bash script with colored output using ANSI codes. Use this color scheme:
- GREEN for UP/OK/200
- RED for DOWN/FAIL/error
- YELLOW for warnings or unexpected HTTP codes
- CYAN for section headers

### Section 1: Ping Checks
Ping each host IP (1 packet, 1 second timeout) and print UP or DOWN:
```bash
echo -e "\n\e[36m=== PING CHECK ===\e[0m"
for entry in "Router:192.168.1.1" "NAS:192.168.1.33" "Pi4:192.168.1.34" "Pi5:192.168.1.69" "Proxmox:192.168.1.38" "LXC110:192.168.1.40" "LXC120:192.168.1.41" "LXC130:192.168.1.42" "LXC150:192.168.1.50"; do
    name="${entry%%:*}"
    ip="${entry##*:}"
    if ping -c1 -W1 "$ip" &>/dev/null; then
        echo -e "  \e[32m✓ UP\e[0m   $name ($ip)"
    else
        echo -e "  \e[31m✗ DOWN\e[0m $name ($ip)"
    fi
done
```

### Section 2: LXC Container Status
SSH to Proxmox and check container states, then show Docker status for each running LXC:
```bash
echo -e "\n\e[36m=== LXC CONTAINER STATUS ===\e[0m"
ssh root@192.168.1.38 "pct list"

echo -e "\n\e[36m=== DOCKER STATUS PER LXC ===\e[0m"
for id in 110 120 150; do
    echo -e "\n  \e[36mLXC $id:\e[0m"
    ssh root@192.168.1.38 "pct exec $id -- docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>/dev/null || echo "  (container not running)"
done
# LXC 130 may be stopped (LUKS encrypted, manual start required)
echo -e "\n  \e[36mLXC 130 (encrypted):\e[0m"
ssh root@192.168.1.38 "pct status 130" 2>/dev/null
ssh root@192.168.1.38 "pct exec 130 -- docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>/dev/null || echo "  (stopped — LUKS unlock required)"
```

### Section 3: Service HTTP Checks
Curl each service endpoint and show HTTP response code:
```bash
echo -e "\n\e[36m=== SERVICE HTTP STATUS ===\e[0m"
declare -A SERVICES=(
    ["Jellyfin"]="http://192.168.1.40:8096"
    ["NPM-Admin"]="http://192.168.1.41:81"
    ["Pi-hole"]="http://192.168.1.34:8053"
    ["Paperless"]="http://192.168.1.42:8000"
    ["Homepage"]="http://192.168.1.50:3000"
)
for name in "${!SERVICES[@]}"; do
    url="${SERVICES[$name]}"
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$url" 2>/dev/null)
    if [[ "$code" =~ ^(200|301|302|304)$ ]]; then
        echo -e "  \e[32m✓ $code\e[0m  $name ($url)"
    elif [[ "$code" == "000" ]]; then
        echo -e "  \e[31m✗ UNREACHABLE\e[0m  $name ($url)"
    else
        echo -e "  \e[33m⚠ $code\e[0m  $name ($url)"
    fi
done
```

### Section 4: DNS Health Check
```bash
echo -e "\n\e[36m=== DNS CHECK ===\e[0m"
echo -n "  Primary DNS (Pi4 192.168.1.34): "
result=$(dig @192.168.1.34 google.com +short 2>/dev/null | head -1)
[[ -n "$result" ]] && echo -e "\e[32m✓ resolves ($result)\e[0m" || echo -e "\e[31m✗ FAILED\e[0m"

echo -n "  Backup DNS (LXC120 192.168.1.41): "
result=$(dig @192.168.1.41 google.com +short 2>/dev/null | head -1)
[[ -n "$result" ]] && echo -e "\e[32m✓ resolves ($result)\e[0m" || echo -e "\e[31m✗ FAILED\e[0m"

echo -n "  Internal domain (jellyfin.gofer.cloud): "
result=$(dig jellyfin.gofer.cloud +short 2>/dev/null | head -1)
[[ -n "$result" ]] && echo -e "\e[32m✓ resolves ($result)\e[0m" || echo -e "\e[33m⚠ not resolving (check local DNS)\e[0m"
```

After outputting the script, add a brief note:
> Copy and paste the script above into your terminal to run it. LXC 130 may show as stopped — this is expected if encrypted storage hasn't been manually unlocked.
