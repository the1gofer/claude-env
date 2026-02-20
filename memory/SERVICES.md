# Service URLs — gofer-stack

## Management Interfaces

| Service          | Internal URL                         | Notes                        |
|------------------|--------------------------------------|------------------------------|
| Proxmox UI       | https://192.168.1.38:8006            | User: root / pam             |
| NPM Admin        | http://192.168.1.41:81               | Nginx Proxy Manager          |
| Pi-hole Primary  | http://192.168.1.34:8053/admin       | On Pi 4                      |
| Pi-hole Backup   | http://192.168.1.41:8080/admin       | On LXC 120                   |
| Synology DSM     | http://192.168.1.33:5000             | HTTPS: :5001                 |

## Media Stack — LXC 110 (192.168.1.40)

| Service     | Internal URL                    | External URL                            |
|-------------|----------------------------------|------------------------------------------|
| Jellyfin    | http://192.168.1.40:8096         | https://jellyfin.gofer.cloud (external) |
| Jellyseerr  | http://192.168.1.40:5055         | https://jellyseerr.gofer.cloud (external)|
| Radarr      | http://192.168.1.40:7878         | https://radarr.gofer.cloud (LAN only)   |
| Sonarr      | http://192.168.1.40:8989         | https://sonarr.gofer.cloud (LAN only)   |
| Prowlarr    | http://192.168.1.40:9696         | https://prowlarr.gofer.cloud (LAN only) |
| Bazarr      | http://192.168.1.40:6767         | —                                        |
| Lidarr      | http://192.168.1.40:8686         | https://lidarr.gofer.cloud (LAN only)   |
| qBittorrent | http://192.168.1.40:8080         | https://qbit.gofer.cloud (LAN only)     |

Note: qBittorrent traffic routes through Gluetun VPN container.

## Document Stack — LXC 130 (192.168.1.42) — LUKS encrypted

| Service      | Internal URL                    | External URL                             |
|--------------|---------------------------------|------------------------------------------|
| Paperless-ngx| http://192.168.1.42:8000        | https://paperless.gofer.cloud (external) |
| Immich       | http://192.168.1.42:2283        | https://immich.gofer.cloud (external)    |
| Nextcloud    | http://192.168.1.42:443         | https://nextcloud.gofer.cloud (planned)  |

## Utilities — LXC 150 (192.168.1.50)

| Service      | Internal URL                    | External URL                             |
|--------------|---------------------------------|------------------------------------------|
| Homepage     | http://192.168.1.50:3000        | https://home.gofer.cloud                 |
| n8n          | http://192.168.1.50:5678        | https://n8n.gofer.cloud (planned)        |
| Stirling-PDF | http://192.168.1.50:8090        | https://pdf.gofer.cloud (planned)        |
| Homebox      | http://192.168.1.50:3100        | https://inventory.gofer.cloud (planned)  |

## Infrastructure — LXC 120 (192.168.1.41)

| Service    | Port | Notes                        |
|------------|------|------------------------------|
| NPM HTTP   | 80   | Reverse proxy                |
| NPM HTTPS  | 443  | Reverse proxy                |
| NPM Admin  | 81   | Management UI                |
| Pi-hole    | 53   | Backup DNS                   |
| Pi-hole UI | 8080 | Web admin                    |
| Cloudflared| 5053 | DoH upstream                 |

## Credential Locations (no passwords stored in this repo)

| Service        | Where to find credentials                              |
|----------------|--------------------------------------------------------|
| Proxmox root   | Set during Proxmox installation                        |
| NPM            | admin@example.com / changeme (change on first login)   |
| Pi-hole        | WEBPASSWORD in docker-compose on Pi 4 / LXC 120        |
| Paperless-ngx  | PAPERLESS_ADMIN_PASSWORD in docker-compose .env        |
| Immich         | Created during first-run setup wizard                  |
| Synology DSM   | admin user set during NAS setup                        |
| Homepage       | No auth by default                                     |
