#!/usr/bin/env bash

set -euo pipefail

# Detect PUID/PGID and set SERVER_ROOT
if [ -f .env ]; then
  # Source .env for SERVER_ROOT, PUID, PGID, TZ
  set -a
  . ./.env
  set +a
else
  PUID=$(id -u)
  PGID=$(id -g)
  SERVER_ROOT="$HOME"
  TZ="Asia/Kolkata"
  echo "SERVER_ROOT=$SERVER_ROOT" > .env
  echo "PUID=$PUID" >> .env
  echo "PGID=$PGID" >> .env
  echo "TZ=$TZ" >> .env
fi

# Check for root or sudo
if [[ $EUID -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "This script requires root privileges or sudo installed." >&2
    exit 1
  fi
fi

# Check for required commands
for cmd in curl docker docker-compose crontab; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "Required command '$cmd' not found. Please install it first." >&2
    exit 1
  fi
done

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
sudo usermod -aG docker "$USER"

# === Install Docker Compose ===
echo "===== Installing Docker Compose ====="
sudo apt install -y docker-compose

# === Create Server Directories ===
echo "===== Creating server directories ====="
mkdir -p "$SERVER_ROOT/config" "$SERVER_ROOT/media" "$SERVER_ROOT/downloads" "$SERVER_ROOT/data"
sudo mkdir -p /mnt/usb /mnt/usb/downloads

# === Setup DuckDNS ===
echo "===== Setting up DuckDNS ====="
mkdir -p "$HOME/config/duckdns"
DUCKDNS_ENV="$HOME/config/duckdns/duck.env"

# Function to prompt for DuckDNS credentials
prompt_duckdns() {
  echo "To use DuckDNS, you need a free account. Register at: https://www.duckdns.org/"
  read -p "Enter your DuckDNS domain (or leave blank to skip): " DUCKDNS_DOMAIN
  if [ -z "$DUCKDNS_DOMAIN" ]; then
    echo "Skipping DuckDNS setup. You can add your credentials later in $DUCKDNS_ENV."
    return 1
  fi
  read -p "Enter your DuckDNS token: " DUCKDNS_TOKEN
  if [ -z "$DUCKDNS_TOKEN" ]; then
    echo "No token entered. Skipping DuckDNS setup."
    return 1
  fi
  cat <<EOENV > "$DUCKDNS_ENV"
# DuckDNS configuration
DUCKDNS_DOMAIN="$DUCKDNS_DOMAIN"
DUCKDNS_TOKEN="$DUCKDNS_TOKEN"
EOENV
  chmod 600 "$DUCKDNS_ENV"
  echo "Created DuckDNS env file at $DUCKDNS_ENV."
  return 0
}

if [ ! -f "$DUCKDNS_ENV" ]; then
  prompt_duckdns || DUCKDNS_SKIP=1
else
  . "$DUCKDNS_ENV"
  if [[ "$DUCKDNS_DOMAIN" == "yourdomain" || "$DUCKDNS_TOKEN" == "yourtoken" ]]; then
    prompt_duckdns || DUCKDNS_SKIP=1
  fi
fi

if [ "${DUCKDNS_SKIP:-0}" -eq 1 ]; then
  echo "DuckDNS will not be set up. You can configure it later by editing $DUCKDNS_ENV."
else
  # Create/update DuckDNS update script
  cat <<'EOF' > "$HOME/config/duckdns/duck.sh"
#!/usr/bin/env bash
set -euo pipefail
. "$HOME/config/duckdns/duck.env"
if [[ "$DUCKDNS_DOMAIN" == "yourdomain" || "$DUCKDNS_TOKEN" == "yourtoken" ]]; then
  echo "[ERROR] Please update $HOME/config/duckdns/duck.env with your real DuckDNS domain and token." >&2
  exit 1
fi
RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=")
echo "DuckDNS update response: $RESPONSE"
EOF
  chmod 700 "$HOME/config/duckdns/duck.sh"
  (crontab -l 2>/dev/null; echo "*/5 * * * * $HOME/config/duckdns/duck.sh >/dev/null 2>&1") | crontab -
  # Test DuckDNS setup immediately
  RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=")
  if [ "$RESPONSE" = "OK" ] || [ "$RESPONSE" = "OK\n" ]; then
    echo "DuckDNS setup: OK"
  else
    echo "DuckDNS setup: ERROR (response: $RESPONSE)"
  fi
fi

# === Check for Docker Compose v1 or v2 ===
if command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE_CMD="sudo docker-compose"
elif docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE_CMD="sudo docker compose"
else
  echo "Docker Compose is not installed or not found in PATH. Please install Docker Compose v2 or v1." >&2
  exit 1
fi

# === Check for USB Storage ===
echo "===== Checking for USB storage ====="
USB_MOUNTED=0
for DEV in /dev/sd[a-z]1; do
  if [ -b "$DEV" ]; then
    echo "Found USB device: $DEV"
    if sudo mount "$DEV" /mnt/usb; then
      USB_MOUNTED=1
      break
    else
      echo "Warning: Failed to mount $DEV to /mnt/usb."
    fi
  fi
done

if [ "$USB_MOUNTED" -eq 1 ]; then
  echo "Using /mnt/usb/downloads for downloads"
  DOWNLOADS_DIR="/mnt/usb/downloads"
else
  echo "No USB device found or mount failed. Using $HOME/downloads for downloads."
  DOWNLOADS_DIR="$HOME/downloads"
fi

# === Warn about Pi-hole port usage ===
if sudo lsof -i :80 -sTCP:LISTEN | grep -v "COMMAND" | grep -v "pihole" >/dev/null 2>&1; then
  echo "Warning: Port 80 is already in use. Pi-hole may not start correctly."
fi
if sudo lsof -i :443 -sTCP:LISTEN | grep -v "COMMAND" | grep -v "pihole" >/dev/null 2>&1; then
  echo "Warning: Port 443 is already in use. Pi-hole may not start correctly."
fi

# === Start Docker Stack ===
echo "===== Starting Docker stack ====="
REPO_COMPOSE_FILE="$(pwd)/docker-compose.yml"
if [ ! -f "$REPO_COMPOSE_FILE" ]; then
  echo "docker-compose.yml not found in the repository directory. Please make sure it exists before running this script." >&2
  exit 1
fi
$DOCKER_COMPOSE_CMD -f "$REPO_COMPOSE_FILE" up -d

# === Completion Message ===
echo "===== All done! ====="
echo "Access services on your server IP or at https://yourdomain.duckdns.org"
echo "If this is your first time installing Docker, please log out and log back in (or reboot) to use Docker without sudo."

# Ensure all required media and download folders exist
mkdir -p "$SERVER_ROOT/downloads/qbittorrent/radarr"
mkdir -p "$SERVER_ROOT/downloads/qbittorrent/tv-sonarr"
mkdir -p "$SERVER_ROOT/media/movies"
mkdir -p "$SERVER_ROOT/media/tv"
