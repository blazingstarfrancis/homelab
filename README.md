# 🏠 Home Server Setup for Raspberry Pi (Headless)

This repository automates the setup of a self-hosted home server on a Raspberry Pi, completely headless (no monitor or keyboard needed).

It installs and configures popular services like Nextcloud, Jellyfin, Pi-hole, Home Assistant, qBittorrent, Sonarr, Radarr, Jackett, Organizr, and Watchtower — all using Docker.

---

## ✅ What This Script Does

- Installs Docker and Docker Compose
- Sets up essential server directories in your home directory (`$HOME`)
- Configures DuckDNS for dynamic DNS (optional, prompted at runtime)
- Mounts USB storage (if detected)
- Uses the `docker-compose.yml` file in this repository to start your full home server stack
- Dynamically creates a `.env` file with your user/group IDs and timezone for Docker Compose portability

---

## 📦 Services Included

| Service       | Port | Description                  |
|---------------|------|------------------------------|
| Nextcloud     | 8080 | Self-hosted cloud storage    |
| Jellyfin      | 8096 | Media streaming server       |
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
git clone <your-repo-url>
cd <your-repo-directory>
```

### 2. (Optional) Edit the Compose and .env Files

- If you want to customize services or change data/config paths, edit the `docker-compose.yml` file in the repository directory **before running the script**.
- The script will create a `.env` file with your user/group IDs and timezone if it doesn't exist. You can edit this file to change `SERVER_ROOT`, `PUID`, `PGID`, or `TZ` as needed.

**Sample .env file:**
```
SERVER_ROOT=$HOME
PUID=1000
PGID=1000
TZ=Asia/Kolkata
```

### 3. Run the Install Script

```bash
chmod +x install_homelab.sh
./install_homelab.sh
```

- The script will prompt you for your DuckDNS domain and token if you want to use DuckDNS. You can skip this step if you don't need dynamic DNS.
- All data and configuration files will be stored in your home directory (e.g., `$HOME/config`, `$HOME/downloads`, etc.), unless you change the paths in the compose file or `.env`.
- The script will use the `docker-compose.yml` file in the repository directory to start all services automatically.

---

## 🔒 Sensitive Data & Security

- **DuckDNS Configuration:**
  - The script will prompt you for your DuckDNS domain and token at runtime. If you skip, DuckDNS will not be set up, but you can add credentials later in `$HOME/config/duckdns/duck.env`.
  - **Never commit your real secrets or tokens to this repository.**
- No other secrets or sensitive data are stored in this repository or the install script.
- Always keep your `.env` files and configuration files containing secrets out of version control.

---

## 📝 Notes

- **Docker Compose v2:** If you have only the new `docker compose` plugin (not the old `docker-compose`), the script will still work. If you encounter issues, install Docker Compose v2 or update your Docker installation.
- **USB Storage:** The script will attempt to mount the first detected USB drive to `/mnt/usb` and use it for downloads if available.
- **Customizing Services:** To add or modify services, edit the `docker-compose.yml` and `.env` in the repository directory before running the script.
- **Media Folders:** The script ensures all required media and download folders exist for Sonarr/Radarr/qBittorrent.

---

## 🚫 .gitignore

Make sure your `.gitignore` includes:
```
.env
config/duckdns/duck.env
downloads/
media/
config/
data/
```

---

## 📸 Screenshots & Badges (Recommended)

- Add screenshots of the UI (Jellyfin, Sonarr, etc.) for a more attractive GitHub page.
- Add badges for Bash, Docker, etc. (see [shields.io](https://shields.io/)).

---

## 📄 License

Add your license here if you want others to use or contribute to your project.
