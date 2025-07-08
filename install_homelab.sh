#!/usr/bin/env bash

set -e

# === Update System ===
echo "===== Updating system ====="
sudo apt update && sudo apt upgrade -y

# === Install Required Packages ===
echo "===== Installing required packages ====="
sudo apt install -y \
  curl \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common

# === Install Docker ===
echo "===== Installing Docker ====="
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh
sudo usermod -aG docker $USER

# === Install Docker Compose ===
echo "===== Installing Docker Compose ====="
sudo apt install -y docker-compose

# === Create Homelab Directories ===
echo "===== Creating homelab directories ====="
mkdir -p ~/homelab/{config,media,downloads,data}
sudo mkdir -p /mnt/usb /mnt/usb/downloads

# === Setup DuckDNS ===
echo "===== Setting up DuckDNS ====="
mkdir -p ~/homelab/config/duckdns
# Create env file if it doesn't exist
DUCKDNS_ENV=~/homelab/config/duckdns/duck.env
if [ ! -f "$DUCKDNS_ENV" ]; then
  cat <<EOENV > "$DUCKDNS_ENV"
# DuckDNS configuration
DUCKDNS_DOMAIN="yourdomain"
DUCKDNS_TOKEN="yourtoken"
EOENV
  echo "Created sample DuckDNS env file at $DUCKDNS_ENV. Please edit it with your real values."
fi
# Source env file
. "$DUCKDNS_ENV"
cat <<EOF > ~/homelab/config/duckdns/duck.sh
# Source env file
EOF
chmod 700 ~/homelab/config/duckdns/duck.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/homelab/config/duckdns/duck.sh >/dev/null 2>&1") | crontab -

# === Check for USB Storage ===
echo "===== Checking for USB storage ====="
USB_MOUNTED=0
for DEV in /dev/sd[a-z]1; do
  if [ -b "$DEV" ]; then
    echo "Found USB device: $DEV"
    sudo mount "$DEV" /mnt/usb || true
    USB_MOUNTED=1
    break
  fi
done

if [ "$USB_MOUNTED" -eq 1 ]; then
  echo "Using /mnt/usb/downloads for downloads"
  DOWNLOADS_DIR="/mnt/usb/downloads"
else
  echo "No USB device found. Using ~/homelab/downloads for downloads"
  DOWNLOADS_DIR=~/homelab/downloads
fi

# === Generate docker-compose.yml ===
echo "===== Creating Docker Compose file ====="
cat <<EOF > ~/homelab/docker-compose.yml
version: "3.8"
services:

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --interval 86400

  nextcloud:
    image: linuxserver/nextcloud
    container_name: nextcloud
    restart: unless-stopped
    ports:
      - 8080:80
    volumes:
      - /home/homelab/config/nextcloud:/config
      - ${DOWNLOADS_DIR}:/data

  jellyfin:
    image: jellyfin/jellyfin
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"
      - "8920:8920"
    environment:
      - TZ=Asia/Kolkata
    volumes:
      - /home/homelab/config/jellyfin:/config
      - /home/homelab/media:/media
      - ${DOWNLOADS_DIR}/qbittorrent:/downloads/qbittorrent

  pihole:
    image: pihole/pihole
    container_name: pihole
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80"
      - "443:443"
    environment:
      - TZ=Etc/UTC
    volumes:
      - /home/homelab/config/pihole/etc-pihole:/etc/pihole
      - /home/homelab/config/pihole/etc-dnsmasq.d:/etc/dnsmasq.d

  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    network_mode: host
    privileged: true
    volumes:
      - /home/homelab/config/homeassistant:/config

  sonarr:
    image: linuxserver/sonarr
    container_name: sonarr
    restart: unless-stopped
    ports:
      - 8989:8989
    volumes:
      - /home/homelab/config/sonarr:/config
      - ${DOWNLOADS_DIR}/qbittorrent:/downloads
      - /home/homelab/media:/tv

  radarr:
    image: linuxserver/radarr
    container_name: radarr
    restart: unless-stopped
    ports:
      - 7878:7878
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - /home/homelab/config/radarr:/config
      - ${DOWNLOADS_DIR}/qbittorrent:/downloads
      - /home/homelab/media:/movies

  jackett:
    image: linuxserver/jackett
    container_name: jackett
    restart: unless-stopped
    ports:
      - 9117:9117
    volumes:
      - /home/homelab/config/jackett:/config
      - ${DOWNLOADS_DIR}:/downloads

  organizr:
    image: organizr/organizr
    container_name: organizr
    restart: unless-stopped
    ports:
      - 9980:80
    volumes:
      - /home/homelab/config/organizr:/config

  qbittorrent:
    image: linuxserver/qbittorrent
    container_name: qbittorrent
    restart: unless-stopped
    ports:
      - 8081:8081
      - 6881:6881
      - 6881:6881/udp
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - WEBUI_PORT=8081
    volumes:
      - /home/homelab/config/qbittorrent:/config
      - ${DOWNLOADS_DIR}/qbittorrent:/downloads
EOF

# === Start Docker Stack ===
echo "===== Starting Docker stack ====="
cd ~/homelab
sudo docker-compose up -d

# === Completion Message ===
echo "===== All done! ====="
echo "Access services on your Raspberry Pi IP or at https://homelabmedia.duckdns.org"
