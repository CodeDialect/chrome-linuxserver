#!/bin/bash

set -e

# === Colors ===
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

# BANNER
echo -e "${GREEN}"
cat << 'EOF'
 ______              _         _                                             
|  ___ \            | |       | |                   _                        
| |   | |  ___    _ | |  ____ | | _   _   _  ____  | |_   ____   ____  _____ 
| |   | | / _ \  / || | / _  )| || \ | | | ||  _ \ |  _) / _  ) / ___)(___  )
| |   | || |_| |( (_| |( (/ / | | | || |_| || | | || |__( (/ / | |     / __/ 
|_|   |_| \___/  \____| \____)|_| |_| \____||_| |_| \___)\____)|_|    (_____)
EOF
echo -e "${NC}"

# === Step 1: Install dependencies ===
echo -e "${GREEN}[1/12] Installing required dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y curl wget ufw ca-certificates gnupg lsb-release

# === Step 2: Ask for credentials ===
echo -e "${GREEN}[2/12] Enter Chromium Login Credentials...${NC}"
read -p "Username: " CUSTOM_USER
read -s -p "Password: " PASSWORD
echo ""

# === Step 3: Docker Installation ===
if ! command -v docker &> /dev/null; then
  echo -e "${GREEN}[3/12] Installing Docker via CodeDialect script...${NC}"
  curl -sL https://raw.githubusercontent.com/CodeDialect/aztec-squencer/main/docker.sh | bash
else
  echo -e "${YELLOW}[3/12] Docker already installed. Skipping Docker setup.${NC}"
fi

# === Step 4: Docker Compose Installation ===
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  echo -e "${GREEN}[4/12] Installing Docker Compose...${NC}"
  curl -L "https://github.com/docker/compose/releases/download/v2.24.7/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
else
  echo -e "${YELLOW}[4/12] Docker Compose already installed.${NC}"
fi

# === Step 5: Create chromium directory ===
mkdir -p $HOME/chromium/config

# === Step 6: Generate docker-compose.yml ===
echo -e "${GREEN}[5/12] Generating docker-compose.yml...${NC}"

cat <<EOF > docker-compose.yml
version: "3.9"

services:
  chromium:
    image: lscr.io/linuxserver/chromium:8d3cb5f1-ls129
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=${CUSTOM_USER}
      - PASSWORD=${PASSWORD}
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Kolkata
    volumes:
      - ${HOME}/chromium/config:/config
    ports:
      - 4100:3000
      - 4101:3001
    shm_size: "1gb"
    restart: unless-stopped
EOF

# === Step 7: Start the container ===
echo -e "${GREEN}[6/12] Launching Chromium container...${NC}"
sudo docker compose up -d

# === Step 8: UFW Setup ===
echo -e "${GREEN}[7/12] Setting up UFW firewall...${NC}"
if ! command -v ufw &> /dev/null; then
  echo -e "${YELLOW}UFW not found, installing it...${NC}"
  sudo apt-get install -y ufw
fi

sudo ufw allow 22/tcp    # SSH
sudo ufw allow 4100/tcp  # Chromium Web UI
sudo ufw allow 4101/tcp  # VNC
sudo ufw --force enable

echo -e "${GREEN}[8/12] UFW enabled and necessary ports allowed (22, 4100, 4101).${NC}"

# === Step 9: Get Public IP ===
VPS_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

# === Done ===
echo -e "\n${GREEN}✅ Chromium Docker is running!${NC}"
echo -e "${GREEN}🌐 Access it at: http://${VPS_IP}:4100${NC}"
echo -e "${YELLOW}🔐 Login with the username and password you set above.${NC}"
echo -e "${YELLOW}📡 SSH is also enabled and open on port 22.${NC}"
