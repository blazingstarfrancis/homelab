# 🏠 HomeServer Setup for Raspberry Pi (Headless)

This repository automates the setup of a self-hosted home server on a Raspberry Pi, completely headless (no monitor or keyboard needed).

It installs and configures popular services like Nextcloud, Jellyfin, Plex, Pi-hole, Home Assistant, qBittorrent, and more — all using Docker.

---

## ✅ What This Script Does

- Installs Docker and Docker Compose
- Sets up essential Raspberry Pi directories
- Configures DuckDNS for dynamic DNS
- Mounts USB storage (if detected)
- Creates a `docker-compose.yml` file
- Starts your full home server stack with one command

---

## 📦 Services Included

| Service       | Port | Description                  |
|---------------|------|------------------------------|
| Nextcloud     | 8080 | Self-hosted cloud storage    |
| Jellyfin      | 8096 | Media streaming server       |
| Plex          | Auto | Media server (DLNA)          |
| Sonarr        | 8989 | TV Show manager              |
| Radarr        | 7878 | Movie manager                |
| Jackett       | 9117 | Torrent indexer proxy        |
| qBittorrent   | 8081 | Torrent client               |
| Organizr      | 9980 | Unified web dashboard        |
| Pi-hole       | 80   | Network-wide ad blocker      |
| Home Assistant| 8123 | Smart home hub               |
| Watchtower    | —    | Auto Docker updates          |

---

## ⚙️ Setup Instructions

### 1. Clone the Repo

```bash
git clone https://github.com/blazingstarfrancis/homeserver.git
cd homeserver
