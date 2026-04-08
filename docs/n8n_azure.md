# A Step-by-Step Guide to Installing n8n on Azure, with Examples and URLs

n8n is a workflow automation platform you can self-host on Azure. For most teams, the simplest production-friendly setup on Azure is: Ubuntu VM + Docker Compose + Azure Database for PostgreSQL + a reverse proxy + DNS. n8n’s own docs recommend Docker for most self-hosting needs, and n8n’s Azure guide shows an Azure deployment pattern built around PostgreSQL and Kubernetes for larger setups.

This article gives you a practical path you can actually deploy today. It starts with the easiest stable option for many solo operators and small teams, then shows a shorter Azure Container Apps variant, and finally points to the official AKS/Kubernetes path if you need more scale.

What you will build

By the end, you will have:

an Azure Ubuntu VM
Docker Engine and Docker Compose
n8n running in a container
Azure Database for PostgreSQL Flexible Server
a public URL such as https://n8n.yourdomain.com
TLS/HTTPS in front of n8n
example configuration files you can reuse

This design is popular because it is simple to understand, easy to back up, and easy to upgrade. n8n supports PostgreSQL as a database backend, Docker is the recommended self-hosting route for most users, and Azure provides managed PostgreSQL, DNS, networking, and container hosting options.

Deployment options on Azure

Before installing anything, pick the right Azure hosting shape.

Option 1: Azure VM + Docker Compose

This is the best fit when you want full control, easy debugging, a normal Linux box, and the least moving parts. Azure’s Linux VM quickstart uses Ubuntu Server 22.04 LTS, Docker supports Ubuntu 22.04 and 24.04, and n8n recommends Docker for most self-hosting needs.

Option 2: Azure Container Apps

This is a good fit when you want Azure to handle more of the platform work for you. Azure Container Apps is a serverless container platform for existing images, supports runtime environment variables and secrets, and supports custom domains and certificates when ingress is enabled.

Option 3: AKS / Kubernetes

This is the right fit for bigger teams, higher scale, or when you already run Kubernetes. n8n’s official Azure hosting guide uses n8n + Postgres + Kubernetes + reverse proxy.

For the rest of this guide, I’ll use Option 1 as the main tutorial because it is the most direct path to a working production install.

Part 1: Install n8n on Azure VM with PostgreSQL
Architecture

Here is the target layout:

Internet
  |
  v
DNS: n8n.yourdomain.com
  |
  v
Azure Public IP
  |
  v
Azure Ubuntu VM
  ├─ Caddy reverse proxy (HTTPS)
  └─ Docker Compose
      └─ n8n container
            |
            v
Azure Database for PostgreSQL Flexible Server

n8n listens internally on port 5678 by default. When n8n is behind a reverse proxy, n8n’s docs say to set WEBHOOK_URL manually and set N8N_PROXY_HOPS=1 so webhook registration and forwarded request handling work correctly.

Prerequisites

You need:

an Azure subscription
a domain name you control, such as yourdomain.com
an Azure resource group
a PostgreSQL admin username and password
SSH access to your VM

Azure’s Linux VM quickstart walks through creating an Ubuntu VM, Azure DNS can host your DNS zone and records, and Azure NSGs control inbound and outbound traffic to your VM.

Step 1: Create the Azure Ubuntu VM

Create a Linux VM in the Azure portal. Ubuntu Server 22.04 LTS is a safe choice because Azure documents it directly in the quickstart, and Docker’s current Ubuntu install docs support both 22.04 and 24.04.

Recommended starting size for light workloads:

Standard_B2s for testing or very small use
Standard_D2s_v5 or similar for more headroom

Use a public IP if you want direct internet access to your reverse proxy. If you want tighter security, you can place the VM behind Azure Bastion or a stricter network design later. Azure NSGs control the traffic flow to the VM.

Open these ports in the NSG

At minimum:

22 for SSH
80 for HTTP
443 for HTTPS

Azure NSGs filter traffic using rules on subnets and network interfaces, so this is where you allow web traffic to reach your reverse proxy.

Step 2: Create Azure Database for PostgreSQL Flexible Server

Create a PostgreSQL Flexible Server in Azure. n8n supports PostgreSQL and documents the needed environment variables. Azure’s PostgreSQL quickstart notes that your connection string should include sslmode=require. Azure also states that PostgreSQL connections require TLS.

Create:

a PostgreSQL server
a database named n8n
a user such as n8nadmin
a strong password
Example values
Server name: myn8npgserver
Database: n8n
User: n8nadmin
Host: myn8npgserver.postgres.database.azure.com
Port: 5432
Important note about SSL

For Azure PostgreSQL, include SSL in your setup. The simplest production-minded starting point is:

sslmode=require

Azure’s PostgreSQL quickstart explicitly calls this out, and n8n supports PostgreSQL SSL-related environment variables including DB_POSTGRESDB_SSL_ENABLED and DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED.

Step 3: Point DNS to your VM

Create a DNS record for your subdomain, for example:

n8n.yourdomain.com  ->  <your Azure VM public IP>

If you use Azure DNS, create an A record in your public DNS zone. Azure DNS docs show the standard pattern for creating a zone and an A record that resolves a hostname to an IPv4 address.

Step 4: Connect to the VM

SSH into the VM:

ssh azureuser@<your-vm-public-ip>

Once connected, update packages:

sudo apt update && sudo apt upgrade -y
Step 5: Install Docker Engine and Docker Compose

n8n recommends Docker for most self-hosted installs. Docker’s Ubuntu docs say to install from Docker’s apt repository, then install docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, and docker-compose-plugin.

Install Docker on Ubuntu
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: jammy
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

If your VM is Ubuntu 24.04, change Suites: jammy to Suites: noble.

Verify Docker
sudo systemctl status docker
sudo docker run hello-world
docker compose version

Docker’s docs say the service usually starts automatically after installation, and docker run hello-world is the recommended quick verification step.

Step 6: Create a working folder
mkdir -p ~/n8n
cd ~/n8n
Step 7: Create a strong encryption key

n8n stores encrypted credentials, and its docs strongly support using a custom N8N_ENCRYPTION_KEY. If you do not set one, n8n generates a random key on first launch. That works, but a custom key is safer for a controlled deployment and is important for repeatable recovery and scale-out.

Generate one:

openssl rand -hex 32

Save the output. Example:

a4b9c20f2f7d99f2b2dd91dddb15ce5cfec7f4f6cbe4b0a2847c9123456789ab
Step 8: Create your .env file

Create a file named .env:

nano .env

Paste this and replace the placeholders:

# Public URL
N8N_HOST=n8n.yourdomain.com
N8N_PROTOCOL=https
WEBHOOK_URL=https://n8n.yourdomain.com/
N8N_EDITOR_BASE_URL=https://n8n.yourdomain.com/
N8N_PROXY_HOPS=1

# n8n basics
N8N_PORT=5678
N8N_ENCRYPTION_KEY=replace_with_your_generated_key
GENERIC_TIMEZONE=Europe/Dublin
TZ=Europe/Dublin
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_RUNNERS_ENABLED=true

# Database
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=myn8npgserver.postgres.database.azure.com
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8nadmin
DB_POSTGRESDB_PASSWORD=replace_with_db_password
DB_POSTGRESDB_SCHEMA=public
DB_POSTGRESDB_SSL_ENABLED=true
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false
Why these variables matter

n8n documents these database variables for PostgreSQL:

DB_TYPE=postgresdb
DB_POSTGRESDB_HOST
DB_POSTGRESDB_PORT
DB_POSTGRESDB_DATABASE
DB_POSTGRESDB_USER
DB_POSTGRESDB_PASSWORD
DB_POSTGRESDB_SCHEMA
DB_POSTGRESDB_SSL_ENABLED
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED

n8n also documents these deployment variables:

N8N_ENCRYPTION_KEY
N8N_HOST
N8N_PORT
N8N_PROTOCOL
N8N_EDITOR_BASE_URL

And for reverse proxies, n8n says to set:

WEBHOOK_URL
N8N_PROXY_HOPS=1
About DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false

This setting is often used as a practical starting point when connecting to managed PostgreSQL from containers without wiring a CA bundle into the app container. It is convenient, but stricter TLS verification is better. Azure’s PostgreSQL TLS docs recommend certificate verification modes such as verify-full or verify-ca for stronger validation. If you want the most locked-down setup, wire the CA into the container and enable verification properly.

Step 9: Create docker-compose.yml

Create the file:

nano docker-compose.yml

Paste this:

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
Why this works

n8n’s Docker docs show the official image docker.n8n.io/n8nio/n8n, port 5678, and a persistent volume mounted at /home/node/.n8n. They also note that even when PostgreSQL is used, the .n8n directory still contains important data such as encryption keys and logs, so keeping a persistent volume is still best practice.

Binding 127.0.0.1:5678:5678 means n8n is only reachable locally on the VM. Public access will come through the reverse proxy on ports 80 and 443.

Step 10: Start n8n
docker compose up -d
docker compose logs -f

n8n’s Docker docs show the normal Compose lifecycle: pull, down, and up with docker compose up -d.

Check container status
docker ps

You should see the n8n container running.

Step 11: Install and configure Caddy for HTTPS

You need a reverse proxy because n8n is listening internally on port 5678, while you want a public HTTPS endpoint. Caddy is a nice fit here because it provisions TLS automatically and renews certificates for you when it knows the hostname. Caddy’s docs state that automatic HTTPS is enabled by default for public hostnames and that it also redirects HTTP to HTTPS.

Install Caddy

On Ubuntu:

sudo apt update
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
Create the Caddy config
sudo nano /etc/caddy/Caddyfile

Paste:

n8n.yourdomain.com {
    reverse_proxy 127.0.0.1:5678
}

Caddy’s reverse proxy quick-start shows this pattern, and its automatic HTTPS docs explain that certificates are provisioned and renewed automatically for hostnames.

Restart Caddy
sudo systemctl restart caddy
sudo systemctl status caddy
Step 12: Visit your n8n URL

Open:

https://n8n.yourdomain.com

If DNS is correct, ports 80 and 443 are open, and Caddy can reach port 5678 locally, the n8n setup page should load.

Step 13: First-run check list

After the UI loads, test these things:

Log in and create your initial owner account.
Create a test workflow.
Add a Webhook node.
Copy the test URL and confirm it uses your public domain.
Trigger the webhook from your browser or curl.

This matters because when n8n is behind a reverse proxy, incorrect WEBHOOK_URL or proxy headers are a common cause of broken webhook URLs. n8n documents this exact scenario.

Example webhook test
curl -X GET "https://n8n.yourdomain.com/webhook-test/hello"
Part 2: A full working example

Here is a more complete example you can adapt.

Example .env
N8N_HOST=n8n.example.com
N8N_PROTOCOL=https
WEBHOOK_URL=https://n8n.example.com/
N8N_EDITOR_BASE_URL=https://n8n.example.com/
N8N_PROXY_HOPS=1

N8N_PORT=5678
N8N_ENCRYPTION_KEY=5c8f69ed9fbe10a098f5419a1a7a9e1cd4e7354ffcfb8f8e2f3397ef9a829999
GENERIC_TIMEZONE=Europe/Dublin
TZ=Europe/Dublin
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_RUNNERS_ENABLED=true

DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=prodn8npg.postgres.database.azure.com
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8nadmin
DB_POSTGRESDB_PASSWORD=super-secret-password
DB_POSTGRESDB_SCHEMA=public
DB_POSTGRESDB_SSL_ENABLED=true
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false
Example docker-compose.yml
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
Example Caddyfile
n8n.example.com {
    reverse_proxy 127.0.0.1:5678
}
Part 3: Backups, updates, and maintenance
Back up these things

At minimum, back up:

your PostgreSQL database
the Docker volume for /home/node/.n8n
your .env file
your reverse proxy config

n8n’s docs note that the .n8n folder still contains important data even when PostgreSQL is used, including encryption keys and logs. If you lose the encryption key, stored credentials can become unreadable.

Update n8n

To update:

cd ~/n8n
docker compose pull
docker compose down
docker compose up -d

That matches n8n’s documented Docker Compose update flow.

If you want to pin a specific version instead of latest, change:

image: docker.n8n.io/n8nio/n8n:latest

to something like:

image: docker.n8n.io/n8nio/n8n:1.81.0

n8n’s Docker docs show both latest and version-specific pull patterns.

Security hardening ideas

For production, improve your setup with:

Azure Key Vault for secrets
tighter NSG rules
no public SSH if you can avoid it
stronger PostgreSQL TLS verification
regular updates
off-VM backups
Azure Monitor / logging integration if needed

Azure Container Apps docs explicitly recommend using Key Vault references instead of storing production secrets directly where possible. Azure also provides NSGs for traffic control, and Azure PostgreSQL documents TLS verification guidance.

Part 4: Install n8n on Azure Container Apps

If you do not want to manage a VM, Azure Container Apps is the cleaner managed-container option.

When to choose Container Apps

Use Azure Container Apps when you want:

less VM management
container-based deployment
Azure-managed ingress
secrets support
custom domains and certs through Azure

Azure says Container Apps is a serverless platform for containerized apps, supports environment variables and secrets, and supports custom domains and certificates when ingress is enabled.

Basic flow for Container Apps
Create Azure Database for PostgreSQL Flexible Server.
Create an Azure Container App from the official n8n image.
Set n8n environment variables.
Store sensitive values as Container Apps secrets or Key Vault references.
Enable ingress.
Add a custom domain and certificate.
Verify webhooks.

Azure’s docs show each piece of this flow separately: deploy an existing container image, define secrets, set environment variables, and bind custom domains with certificates.

Example image

Use:

docker.n8n.io/n8nio/n8n:latest

That is the official image referenced in n8n’s Docker install docs.

Example environment variables for Container Apps

Set these in the Container App configuration:

N8N_HOST=n8n.example.com
N8N_PROTOCOL=https
N8N_PORT=5678
WEBHOOK_URL=https://n8n.example.com/
N8N_EDITOR_BASE_URL=https://n8n.example.com/
N8N_PROXY_HOPS=1
N8N_ENCRYPTION_KEY=<secret>
GENERIC_TIMEZONE=Europe/Dublin
TZ=Europe/Dublin
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_RUNNERS_ENABLED=true

DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=prodn8npg.postgres.database.azure.com
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8nadmin
DB_POSTGRESDB_PASSWORD=<secret>
DB_POSTGRESDB_SCHEMA=public
DB_POSTGRESDB_SSL_ENABLED=true
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false

Azure Container Apps supports runtime environment variables, and its docs say these can be entered directly or referenced from secrets.

Store secrets properly

For production, do not hardcode passwords in plain text where you can avoid it. Azure Container Apps docs recommend using Key Vault references for production secrets.

Custom domain on Container Apps

To serve n8n.example.com on Azure Container Apps:

enable ingress
add the custom domain
attach a certificate or use a free managed certificate where supported

Azure’s docs state that every custom domain must be associated with a TLS/SSL certificate and that ingress must be enabled.

Part 5: The official AKS / Kubernetes route

If you are building for larger scale or already live in Kubernetes, follow n8n’s official Azure hosting guide:

n8n on Azure using Postgres
Kubernetes
reverse proxy

That guide is the official n8n Azure path and is the right direction if you want worker scaling, GitOps-style deployments, or broader cluster-level operations. n8n’s scaling docs also say that queue mode provides the best scalability.

If you scale out later, keep the same N8N_ENCRYPTION_KEY across all instances. n8n’s docs explicitly note this for multi-instance setups.

Part 6: Troubleshooting
Problem: The page does not load

Check:

VM public IP exists
NSG allows 80 and 443
DNS A record points to the correct public IP
Caddy is running
n8n container is running

Azure DNS docs cover A records, and Azure NSGs control the traffic path.

Useful commands
sudo systemctl status caddy
docker ps
docker compose logs -f
curl -I http://127.0.0.1:5678
curl -I https://n8n.yourdomain.com
Problem: Webhook URLs are wrong

Usually this means your proxy-related settings are incomplete. Set:

WEBHOOK_URL=https://n8n.yourdomain.com/
N8N_PROXY_HOPS=1
N8N_PROTOCOL=https
N8N_HOST=n8n.yourdomain.com

n8n’s reverse-proxy docs call out WEBHOOK_URL and N8N_PROXY_HOPS=1 specifically.

Problem: PostgreSQL connection fails

Check:

hostname
database name
username
password
firewall/network rules
SSL settings

Azure’s PostgreSQL quickstart says to ensure sslmode=require is included, and n8n documents the SSL-related PostgreSQL environment variables.

Problem: Credentials disappear or cannot be decrypted

That often points to an encryption key problem. Keep your N8N_ENCRYPTION_KEY safe and consistent across restarts and migrations. n8n documents this variable as the key used to encrypt credentials in the database.

Part 7: Recommended production settings

A good practical baseline is:

Azure VM or Container Apps
Azure PostgreSQL Flexible Server
HTTPS on a real domain
persistent .n8n storage
custom N8N_ENCRYPTION_KEY
regular Compose-based updates
backups for DB and .n8n
secrets moved to Azure Key Vault over time

This lines up with n8n’s Docker-based self-hosting guidance, its PostgreSQL and reverse-proxy configuration docs, and Azure’s platform guidance for secrets, DNS, and TLS-enabled hosting.

Reference URLs
n8n docs home
https://docs.n8n.io/

n8n self-hosting overview
https://docs.n8n.io/hosting/

n8n Docker installation
https://docs.n8n.io/hosting/installation/docker/

n8n Docker Compose setup docs
https://docs.n8n.io/hosting/installation/server-setups/docker-compose/

n8n Azure hosting guide
https://docs.n8n.io/hosting/installation/server-setups/azure/

n8n database environment variables
https://docs.n8n.io/hosting/configuration/environment-variables/database/

n8n deployment environment variables
https://docs.n8n.io/hosting/configuration/environment-variables/deployment/

n8n reverse proxy webhook configuration
https://docs.n8n.io/hosting/configuration/configuration-examples/webhook-url/

n8n queue mode
https://docs.n8n.io/hosting/scaling/queue-mode/

n8n scaling overview
https://docs.n8n.io/hosting/scaling/overview/

n8n encryption key example
https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/

Docker Engine on Ubuntu
https://docs.docker.com/engine/install/ubuntu/

Docker Compose plugin on Linux
https://docs.docker.com/compose/install/linux/

Azure Linux VM quickstart
https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-portal

Azure NSG management
https://learn.microsoft.com/en-us/azure/virtual-network/manage-network-security-group

Azure DNS zone and A record quickstart
https://learn.microsoft.com/en-us/azure/dns/dns-getstarted-portal

Azure PostgreSQL Flexible Server quickstart
https://learn.microsoft.com/en-us/azure/postgresql/configure-maintain/quickstart-create-server

Azure PostgreSQL TLS guidance
https://learn.microsoft.com/en-us/azure/postgresql/security/security-tls
https://learn.microsoft.com/en-us/azure/postgresql/security/security-tls-how-to-connect

Azure Container Apps overview
https://learn.microsoft.com/en-us/azure/container-apps/

Deploy existing image to Azure Container Apps
https://learn.microsoft.com/en-us/azure/container-apps/get-started-existing-container-image

Azure Container Apps secrets
https://learn.microsoft.com/en-us/azure/container-apps/manage-secrets

Azure Container Apps environment variables
https://learn.microsoft.com/en-us/azure/container-apps/environment-variables

Azure Container Apps custom domains and certificates
https://learn.microsoft.com/en-us/azure/container-apps/custom-domains-certificates
https://learn.microsoft.com/en-us/azure/container-apps/custom-domains-managed-certificates

Caddy automatic HTTPS
https://caddyserver.com/docs/automatic-https

Caddy reverse proxy quick-start
https://caddyserver.com/docs/quick-starts/reverse-proxy
Final notes

If you want the simplest dependable Azure deployment, start with Azure VM + Docker Compose + Azure PostgreSQL + Caddy. If you want less server management, use Azure Container Apps. If you need real scale and worker-based expansion, move to the official Azure Kubernetes guide and n8n queue mode
