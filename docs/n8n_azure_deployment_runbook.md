# deployment runbook: n8n on Azure

This is the shortest practical path:

- Azure Ubuntu VM
- Azure Database for PostgreSQL Flexible Server
- Docker Compose
- Caddy for HTTPS
- Public DNS name like n8n.example.com

## 1) Create Azure resources

Create these first:
- Ubuntu VM in Azure
- PostgreSQL Flexible Server
- DNS A record for n8n.example.com pointing to the VM public IP

Open these VM ports in the NSG:
- 22
- 80
- 443

## Useful URLs:

Azure VM quickstart
- https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-portal

Azure PostgreSQL Flexible Server quickstart
- https://learn.microsoft.com/en-us/azure/postgresql/configure-maintain/quickstart-create-server

Azure DNS quickstart
- https://learn.microsoft.com/en-us/azure/dns/dns-getstarted-portal

Azure NSG docs
- https://learn.microsoft.com/en-us/azure/virtual-network/manage-network-security-group

## 2) SSH into the VM
'''
<br>ssh azureuser@YOUR_VM_PUBLIC_IP<br>
sudo apt update && sudo apt upgrade -y<br>
'''

## 3) Install Docker
'''
<br>sudo apt update<br>
sudo apt install -y ca-certificates curl<br>
sudo install -m 0755 -d /etc/apt/keyrings<br>
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc<br>
sudo chmod a+r /etc/apt/keyrings/docker.asc<br>
<br>
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<'EOF'<br>
Types: deb<br>
URIs: https://download.docker.com/linux/ubuntu<br>
Suites: jammy<br>
Components: stable<br>
Architectures: amd64<br>
Signed-By: /etc/apt/keyrings/docker.asc<br>
EOF<br>

sudo apt update<br>
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin<br>

<br>Check it:<br>

sudo systemctl status docker<br>
sudo docker run hello-world<br>
docker compose version<br>
'''

## URL:
Docker Ubuntu install
- https://docs.docker.com/engine/install/ubuntu/

## 4) Create the n8n folder
'''
mkdir -p ~/n8n<br>
cd ~/n8n<br>
'''

## 5) Generate an encryption key
'''
openssl rand -hex 32<br>
Save the output.<br>
'''

## 7) Create the .env file
'''
nano .env<br>
'''

Paste this and replace the placeholders:
'''
<br>N8N_HOST=n8n.example.com<br>
N8N_PROTOCOL=https<br>
WEBHOOK_URL=https://n8n.example.com/<br>
N8N_EDITOR_BASE_URL=https://n8n.example.com/<br>
N8N_PROXY_HOPS=1<br>
<br>
N8N_PORT=5678<br>
N8N_ENCRYPTION_KEY=PASTE_YOUR_GENERATED_KEY<br>
GENERIC_TIMEZONE=Europe/Dublin<br>
TZ=Europe/Dublin<br>
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true<br>
N8N_RUNNERS_ENABLED=true<br>
<br>
DB_TYPE=postgresdb<br>
DB_POSTGRESDB_HOST=YOUR_PG_SERVER.postgres.database.azure.com<br>
DB_POSTGRESDB_PORT=5432<br>
DB_POSTGRESDB_DATABASE=n8n<br>
DB_POSTGRESDB_USER=YOUR_PG_USER<br>
DB_POSTGRESDB_PASSWORD=YOUR_PG_PASSWORD<br>
DB_POSTGRESDB_SCHEMA=public<br>
DB_POSTGRESDB_SSL_ENABLED=true<br>
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false<br>
'''

## Useful URLs:

n8n Docker install
- https://docs.n8n.io/hosting/installation/docker/

n8n database environment variables
- https://docs.n8n.io/hosting/configuration/environment-variables/database/

n8n deployment environment variables
- https://docs.n8n.io/hosting/configuration/environment-variables/deployment/

n8n reverse proxy / webhook URL
- https://docs.n8n.io/hosting/configuration/configuration-examples/webhook-url/

## 7) Create docker-compose.yml
'''
nano docker-compose.yml
'''

Paste this:

'''
services:<br>
  n8n:<br>
    image: docker.n8n.io/n8nio/n8n:latest<br>
    container_name: n8n<br>
    restart: unless-stopped<br>
    env_file:<br>
      - .env<br>
    ports:<br>
      - "127.0.0.1:5678:5678"<br>
    volumes:<br>
      - n8n_data:/home/node/.n8n<br>
<br>
volumes:<br>
  n8n_data:<br>
'''

## 8) Start n8n
'''
docker compose up -d<br>
docker compose logs -f
'''

Check:
'''
docker ps<br>
curl -I http://127.0.0.1:5678
'''

## 9) Install Caddy
'''
sudo apt update<br>
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl<br>
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg<br>
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list<br>
sudo apt update<br>
sudo apt install -y caddy<br>
'''

URL:

Caddy automatic HTTPS
- https://caddyserver.com/docs/automatic-https

10) Configure Caddy
- sudo nano /etc/caddy/Caddyfile

Paste:
'''
n8n.example.com {
    reverse_proxy 127.0.0.1:5678
}
'''

Restart:
'''
sudo systemctl restart caddy<br>
sudo systemctl status caddy<br>
'''

URL:

Caddy reverse proxy quick start
- https://caddyserver.com/docs/quick-starts/reverse-proxy

## 11) Open n8n

Visit:
- https://n8n.example.com

If the page loads, finish the first-run setup in the browser.

## 12) Test a webhook

Create a workflow with a Webhook node, then test it.

Example:
'''
curl -X GET "https://n8n.example.com/webhook-test/hello"
'''

If the webhook URL is wrong, re-check:
'''
WEBHOOK_URL=https://n8n.example.com/<br>
N8N_PROXY_HOPS=1<br>
N8N_PROTOCOL=https<br>
N8N_HOST=n8n.example.com<br>
'''

## 13) Update n8n later
'''
cd ~/n8n<br>
docker compose pull<br>
docker compose down<br>
docker compose up -d<br>
'''

## 14) Back up these items<br>
Back up:

PostgreSQL database
Docker volume for /home/node/.n8n
'''
.env<br>
/etc/caddy/Caddyfile<br>
'''

Full file set
'''
.env<br>
N8N_HOST=n8n.example.com<br>
N8N_PROTOCOL=https<br>
WEBHOOK_URL=https://n8n.example.com/<br>
N8N_EDITOR_BASE_URL=https://n8n.example.com/<br>
N8N_PROXY_HOPS=1<br>

N8N_PORT=5678
N8N_ENCRYPTION_KEY=PASTE_YOUR_GENERATED_KEY
GENERIC_TIMEZONE=Europe/Dublin
TZ=Europe/Dublin
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_RUNNERS_ENABLED=true

DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=YOUR_PG_SERVER.postgres.database.azure.com
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=YOUR_PG_USER
DB_POSTGRESDB_PASSWORD=YOUR_PG_PASSWORD
DB_POSTGRESDB_SCHEMA=public
DB_POSTGRESDB_SSL_ENABLED=true
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false
'''

docker-compose.yml
'''
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "127.0.0.1:5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
'''

/etc/caddy/Caddyfile
'''
n8n.example.com {
    reverse_proxy 127.0.0.1:5678
}
'''

## Useful URLs
n8n docs
- https://docs.n8n.io/

n8n Docker install
- https://docs.n8n.io/hosting/installation/docker/

n8n Azure guide
- https://docs.n8n.io/hosting/installation/server-setups/azure/

n8n database env vars
- https://docs.n8n.io/hosting/configuration/environment-variables/database/

n8n deployment env vars
- https://docs.n8n.io/hosting/configuration/environment-variables/deployment/

n8n webhook URL / reverse proxy
- https://docs.n8n.io/hosting/configuration/configuration-examples/webhook-url/

Docker on Ubuntu
- https://docs.docker.com/engine/install/ubuntu/

Azure VM quickstart
- https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-portal

Azure PostgreSQL quickstart
- https://learn.microsoft.com/en-us/azure/postgresql/configure-maintain/quickstart-create-server

Azure DNS quickstart
- https://learn.microsoft.com/en-us/azure/dns/dns-getstarted-portal

Azure NSG docs
- https://learn.microsoft.com/en-us/azure/virtual-network/manage-network-security-group

Caddy automatic HTTPS
- https://caddyserver.com/docs/automatic-https

Caddy reverse proxy
- https://caddyserver.com/docs/quick-starts/reverse-proxy


## Single Bash Install Script: n8n on Azure VM

This script installs Docker, Docker Compose, Caddy, and configures n8n on an Ubuntu Azure VM using the official docker.n8n.io/n8nio/n8n image. It assumes you already created an Azure Database for PostgreSQL Flexible Server, because Azure requires TLS for PostgreSQL connections and Azure’s quickstart/current connection examples still use sslmode=require style settings. n8n’s Docker and Compose docs also still center the Docker-based install flow.

It also configures Caddy as the reverse proxy. Caddy automatically provisions and renews HTTPS certificates for public hostnames and redirects HTTP to HTTPS by default.

Before you run it

Create these first in Azure:

an Ubuntu VM
an Azure Database for PostgreSQL Flexible Server
a DNS A record like n8n.example.com pointing to the VM public IP
NSG rules allowing 22, 80, and 443

Have these values ready:
'''
DOMAIN like n8n.example.com
PG_HOST like myserver.postgres.database.azure.com
PG_DATABASE
PG_USER
PG_PASSWORD
'''

The script

### Save this as install-n8n-azure.sh:

'''
#!/usr/bin/env bash
set -Eeuo pipefail

########################################
# Required variables
########################################
DOMAIN="${DOMAIN:-n8n.example.com}"
EMAIL="${EMAIL:-admin@example.com}"

PG_HOST="${PG_HOST:-myserver.postgres.database.azure.com}"
PG_PORT="${PG_PORT:-5432}"
PG_DATABASE="${PG_DATABASE:-n8n}"
PG_USER="${PG_USER:-n8nadmin}"
PG_PASSWORD="${PG_PASSWORD:-change-me}"

TIMEZONE="${TIMEZONE:-Europe/Dublin}"
N8N_DIR="${N8N_DIR:-/opt/n8n}"
N8N_VERSION="${N8N_VERSION:-latest}"

########################################
# Helpers
########################################
log() {
  echo
  echo "==> $*"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root: sudo bash $0"
    exit 1
  fi
}

detect_ubuntu_codename() {
  . /etc/os-release
  echo "${VERSION_CODENAME:-jammy}"
}

random_hex() {
  openssl rand -hex 32
}

########################################
# Start
########################################
require_root

if [[ -z "${DOMAIN}" || -z "${PG_HOST}" || -z "${PG_DATABASE}" || -z "${PG_USER}" || -z "${PG_PASSWORD}" ]]; then
  echo "Missing required settings."
  echo "Set DOMAIN, PG_HOST, PG_DATABASE, PG_USER, PG_PASSWORD."
  exit 1
fi

UBUNTU_CODENAME="$(detect_ubuntu_codename)"
N8N_ENCRYPTION_KEY="${N8N_ENCRYPTION_KEY:-$(random_hex)}"

log "Updating apt packages"
apt-get update
apt-get upgrade -y

log "Installing base packages"
apt-get install -y ca-certificates curl gnupg lsb-release debian-keyring debian-archive-keyring apt-transport-https openssl

########################################
# Docker install
########################################
log "Installing Docker repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF

log "Installing Docker Engine and Compose plugin"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

########################################
# Caddy install
########################################
log "Installing Caddy repository"
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list

log "Installing Caddy"
apt-get update
apt-get install -y caddy

########################################
# n8n files
########################################
log "Creating n8n directory at ${N8N_DIR}"
mkdir -p "${N8N_DIR}"
cd "${N8N_DIR}"

log "Writing .env"
cat > "${N8N_DIR}/.env" <<EOF
N8N_HOST=${DOMAIN}
N8N_PROTOCOL=https
WEBHOOK_URL=https://${DOMAIN}/
N8N_EDITOR_BASE_URL=https://${DOMAIN}/
N8N_PROXY_HOPS=1

N8N_PORT=5678
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
GENERIC_TIMEZONE=${TIMEZONE}
TZ=${TIMEZONE}
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_RUNNERS_ENABLED=true

DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=${PG_HOST}
DB_POSTGRESDB_PORT=${PG_PORT}
DB_POSTGRESDB_DATABASE=${PG_DATABASE}
DB_POSTGRESDB_USER=${PG_USER}
DB_POSTGRESDB_PASSWORD=${PG_PASSWORD}
DB_POSTGRESDB_SCHEMA=public
DB_POSTGRESDB_SSL_ENABLED=true
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false
EOF

chmod 600 "${N8N_DIR}/.env"

log "Writing docker-compose.yml"
cat > "${N8N_DIR}/docker-compose.yml" <<EOF
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:${N8N_VERSION}
    container_name: n8n
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "127.0.0.1:5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
EOF

log "Starting n8n"
docker compose -f "${N8N_DIR}/docker-compose.yml" up -d

########################################
# Caddy config
########################################
log "Writing Caddy config"
cat > /etc/caddy/Caddyfile <<EOF
{
    email ${EMAIL}
}

${DOMAIN} {
    reverse_proxy 127.0.0.1:5678
}
EOF

log "Restarting Caddy"
systemctl enable caddy
systemctl restart caddy

########################################
# Done
########################################
PUBLIC_IP="$(curl -fsSL https://api.ipify.org || true)"

cat <<EOF

Installation complete.

n8n directory:
  ${N8N_DIR}

n8n URL:
  https://${DOMAIN}

Local health check:
  curl -I http://127.0.0.1:5678

Useful commands:
  cd ${N8N_DIR}
  docker compose logs -f
  docker compose ps
  systemctl status caddy
  systemctl status docker

Remember:
- Your DNS A record for ${DOMAIN} must point to this VM.
- Azure NSG must allow ports 80 and 443.
- PostgreSQL must accept connections from this VM or VNet.
- The encryption key is stored in:
    ${N8N_DIR}/.env

Detected public IP:
  ${PUBLIC_IP:-unable-to-detect}

EOF
'''

## How to run it
1) Upload the script
'''
scp install-n8n-azure.sh azureuser@YOUR_VM_PUBLIC_IP:~
'''

3) SSH into the VM
'''
ssh azureuser@YOUR_VM_PUBLIC_IP
'''

5) Run it with your values
'''
sudo DOMAIN=n8n.example.com \
EMAIL=you@example.com \
PG_HOST=myserver.postgres.database.azure.com \
PG_DATABASE=n8n \
PG_USER=n8nadmin \
PG_PASSWORD='your-strong-password' \
TIMEZONE=Europe/Dublin \
bash ~/install-n8n-azure.sh
'''

## What the script does

It installs Docker using Docker’s Ubuntu repository and installs the Compose plugin, which matches Docker’s current Ubuntu install flow.

It runs n8n from the official image and persists /home/node/.n8n, which follows n8n’s current Docker guidance. n8n’s Compose docs still use the .env plus docker-compose.yml pattern.

It sets:
- WEBHOOK_URL
- N8N_EDITOR_BASE_URL
- N8N_PROXY_HOPS=1
- PostgreSQL variables
- an explicit N8N_ENCRYPTION_KEY

Those are the important settings documented by n8n for reverse proxies, deployment, and PostgreSQL-backed installs.

It installs Caddy and gives it a simple reverse proxy config. Caddy’s docs state that with a public hostname it will automatically provision HTTPS certificates and maintain them for you.

---

### First checks after install

Run:
'''
cd /opt/n8n
docker compose logs -f
'''

Then check:
'''
curl -I http://127.0.0.1:5678
curl -I https://n8n.example.com
'''

Open in your browser:
'''
https://n8n.example.com
'''

If the page does not load, the most common causes are:

- DNS not pointing at the VM
- NSG missing 80 or 443
- PostgreSQL firewall or networking issue
- Caddy could not obtain the certificate yet because the domain was not reachable

Azure’s PostgreSQL networking docs also note that private-access PostgreSQL requires the client resource to be inside the same virtual network path.

Update later

n8n’s update docs recommend keeping self-hosted installs current and checking release notes for breaking changes.

Use:
'''
cd /opt/n8n
docker compose pull
docker compose down
docker compose up -d
'''

If you want to pin a version, run the installer with:
'''
sudo N8N_VERSION=latest ...
'''

or edit:
'''
image: docker.n8n.io/n8nio/n8n:latest
'''

to a specific version tag.

### Useful URLs
n8n Docker install
- https://docs.n8n.io/hosting/installation/docker/

n8n Docker Compose setup
- https://docs.n8n.io/hosting/installation/server-setups/docker-compose/

n8n hosting docs
- https://docs.n8n.io/hosting/

Azure PostgreSQL quickstart
- https://learn.microsoft.com/en-us/azure/postgresql/configure-maintain/quickstart-create-server

Azure PostgreSQL connectivity / VNet notes
- https://learn.microsoft.com/en-us/azure/postgresql/connectivity/quickstart-create-connect-server-vnet

Docker Ubuntu install
- https://docs.docker.com/engine/install/ubuntu/

Caddy automatic HTTPS
- https://caddyserver.com/docs/automatic-https

Caddy HTTPS quick-start
- https://caddyserver.com/docs/quick-starts/https

---

.


