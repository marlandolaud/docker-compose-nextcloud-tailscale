# Nextcloud + Tailscale — Self-Hosted Private Cloud

This stack gives you a private Nextcloud instance (think self-hosted Google Drive) that is only accessible through your [Tailscale](https://tailscale.com) network. Nobody on the open internet can reach it.

**What's included:**

| Service | Role |
|---|---|
| [Nextcloud AIO](https://github.com/nextcloud/all-in-one) | Cloud storage, calendar, contacts, photos |
| [Tailscale](https://tailscale.com) | Private mesh VPN — your secure tunnel |
| [Caddy](https://caddyserver.com) | Reverse proxy with automatic HTTPS via Tailscale certs |

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install Docker Desktop](#2-install-docker-desktop)
3. [Set Up Tailscale](#3-set-up-tailscale)
4. [Get a Tailscale OAuth Key](#4-get-a-tailscale-oauth-key)
5. [Clone This Repository](#5-clone-this-repository)
6. [Configure Your Environment](#6-configure-your-environment)
7. [Start the Stack](#7-start-the-stack)
8. [First-Time Nextcloud Setup](#8-first-time-nextcloud-setup)
9. [Renewing TLS Certificates](#9-renewing-tls-certificates)

---

## 1. Prerequisites

Before you begin, make sure you have:

- **Windows 10 (version 2004 or later) or Windows 11** — 64-bit only
- **Virtualisation enabled in your BIOS/UEFI** — most modern PCs have this on by default
- **WSL 2 installed** — Docker Desktop needs this on Windows

### Enable WSL 2 (if not already done)

Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

Restart your PC when prompted. WSL 2 will be set as the default automatically.

---

## 2. Install Docker Desktop

Docker Desktop is the easiest way to run containers on Windows.

![ Docker Desktop](images/docker-logo.png)

**Download:** [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)

Click **"Download for Windows"** and run the installer.

### Installation steps

1. Run the `Docker Desktop Installer.exe` you downloaded.
2. On the **"Configuration"** screen, make sure **"Use WSL 2 instead of Hyper-V"** is checked.
3. Click **Install** and wait for it to finish.
4. Click **Close and restart** when prompted.
5. After your PC restarts, Docker Desktop will launch automatically. Accept the service agreement.

### Verify Docker is working

Open **PowerShell** or **Command Prompt** and run:

```powershell
docker --version
```

You should see something like `Docker version 27.x.x`. If you get an error, make sure Docker Desktop is running (look for the whale icon in your system tray).

---

## 3. Set Up Tailscale

Tailscale creates a secure private network between your devices. Your Nextcloud will only be reachable inside this network.

![ Tailscale](images/tailscale-logo.png)

### Create a Tailscale account

1. Go to [https://tailscale.com](https://tailscale.com) and click **Get started**.
2. Sign up using your Google, Microsoft, or GitHub account (or create a new account).
3. You will be taken to the **Tailscale admin console** at [https://login.tailscale.com/admin](https://login.tailscale.com/admin).

### Find your Tailnet name

Your tailnet name is the unique identifier for your Tailscale network. You'll need it later.

1. In the admin console, click **Settings** (bottom-left).
2. Under **General**, look for **"Tailnet name"** — it will look something like `tail260dae.ts.net`.

> Write this down — you will use it in the format `drive.YOUR-TAILNET-NAME.ts.net`.

### Install Tailscale on your Windows PC (recommended)

While not strictly required to run this stack, installing the Tailscale client on your PC lets you access your Nextcloud from your computer.

**Download:** [https://tailscale.com/download/windows](https://tailscale.com/download/windows)

Run the installer and sign in with the same account you used to create your tailnet.

---

## 4. Get a Tailscale OAuth Key

The Docker container running Tailscale needs a key to join your tailnet automatically. We use an **OAuth client key** with a **tag**, which is the recommended approach for servers.

### Step 1 — Add the tag to your ACL policy

Tailscale uses ACL (Access Control List) tags to define what devices are allowed to do. You need to declare the `tag:nextcloud` tag before you can use it.

1. In the admin console, click **Access Controls** in the left sidebar.
2. You will see a JSON policy file. Find the `"tagOwners"` section (or add one if it doesn't exist) and add your tag:

```json
"tagOwners": {
    "tag:nextcloud": ["autogroup:admin"],
},
```

> If your policy already has a `tagOwners` block, just add the `"tag:nextcloud"` line inside it.

3. Click **Save** at the top right.

Your policy should look something like this when done:

```json
{
    "tagOwners": {
        "tag:nextcloud": ["autogroup:admin"],
    },
    "acls": [
        {"action": "accept", "src": ["*"], "dst": ["*:*"]},
    ],
}
```

![Tailscale ACL editor showing the tagOwners section](images/tailscale-acl.png)

### Step 2 — Create an OAuth client

1. In the admin console, go to **Settings** > **OAuth clients**.
2. Click **Generate OAuth client**.
3. Give it a name like `nextcloud-server`.
4. Under **Scopes**, enable:
   - `Devices` → **Write**
5. Under **Tags**, select `tag:nextcloud`.
6. Click **Generate client**.

![Tailscale OAuth client creation form](images/tailscale-oauth.png)

### Step 3 — Copy your key

After generating, you will see a key that starts with `tskey-client-`. **Copy it now** — Tailscale will only show it once.

> Store this key safely. Treat it like a password. It lets devices join your tailnet automatically.

---

## 5. Clone This Repository

Open **PowerShell** and navigate to where you want to store the project, then clone it:

```powershell
cd C:\Users\YourName\Documents
git clone https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git nextcloud
cd nextcloud
```

> If you don't have Git installed, download it from [https://git-scm.com/download/win](https://git-scm.com/download/win) and restart PowerShell after installing.

---

## 6. Configure Your Environment

All configuration lives in a single `.env` file. You never need to edit `compose.yml` or `renew-certs.sh`.

### Create the `.env` file

In the project folder, copy the example file and fill in your values:

**PowerShell:**
```powershell
copy .env.example .env
notepad .env
```

**Linux/WSL:**
```bash
cp .env.example .env
nano .env
```

> **Important:** The file must be named exactly `.env` — no `.txt` extension. In Windows Explorer you may need to enable "File name extensions" in the View menu.

Fill in all three values:

```env
# Your Tailscale OAuth client key (starts with tskey-client-)
TS_AUTH_KEY=tskey-client-XXXXXXXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# The hostname your Tailscale node will be registered as
# This becomes the subdomain of your Nextcloud URL
TS_HOSTNAME=drive

# Your Nextcloud domain on Tailscale
# Format: {TS_HOSTNAME}.{tailnet-name}.ts.net
NC_DOMAIN=drive.YOUR-TAILNET-NAME.ts.net
```

Save and close the file.

### Summary of all values to set

| Variable | Where to find it | Example |
|---|---|---|
| `TS_AUTH_KEY` | Tailscale admin console > Settings > OAuth clients | `tskey-client-abc123...` |
| `TS_HOSTNAME` | Your choice — becomes the subdomain of your URL | `drive` |
| `NC_DOMAIN` | `{TS_HOSTNAME}.{tailnet-name}.ts.net` | `drive.tail9abc.ts.net` |

> Your tailnet name is visible in the Tailscale admin console under **Settings > General**.

---

## 7. Start the Stack

### First start

Double-click `start.bat` in the project folder.

Or in PowerShell:

```powershell
docker compose up --build --pull always --wait
```

This will:
- Download all container images (takes a few minutes the first time)
- Build the custom Caddy image with the L4 module
- Connect your Tailscale container to your tailnet
- Start Nextcloud AIO

When it finishes, you'll see all services listed as `healthy` or `started`.

![Terminal showing docker compose completing successfully](images/docker-compose-started.png)

### Verify Tailscale joined your tailnet

Check your [Tailscale admin console](https://login.tailscale.com/admin/machines). You should see a new machine named `drive` (or your chosen hostname) appear in the list.

---

## 8. First-Time Nextcloud Setup

### Open the AIO admin panel

Open your browser and go to:

```
http://localhost:8080
```

You will see the **Nextcloud AIO setup page**.

![Nextcloud AIO setup page showing the passphrase](images/nextcloud-aio-setup.png)

> The page will display a one-time passphrase. **Copy it and store it somewhere safe** — you'll need it to log back into the admin panel in the future.

### Configure the domain

1. Log into the AIO admin panel with the passphrase shown.
2. In the **"Domain"** field, enter your full Tailscale domain:

   ```
   drive.YOUR-TAILNET-NAME.ts.net
   ```

3. Click **Save**.

> Domain validation is skipped automatically (`SKIP_DOMAIN_VALIDATION: true` is already set in `compose.yml`) so you don't need your domain to be publicly reachable.

### Issue TLS certificates

Your Nextcloud needs a valid HTTPS certificate from Tailscale. Run:

**On Windows (in PowerShell from the project folder):**
```powershell
# Replace the domain with your NC_DOMAIN value from .env
docker compose exec tailscale tailscale cert --cert-file /tmp/ts.crt --key-file /tmp/ts.key drive.YOUR-TAILNET-NAME.ts.net
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

**On Linux/WSL:**
```bash
./renew-certs.sh
```

> `renew-certs.sh` reads `NC_DOMAIN` from your `.env` file automatically.

### Start Nextcloud containers

Back in the AIO admin panel at `http://localhost:8080`:

1. Select which optional apps you want (e.g. Talk, Collabora Office, ClamAV).
2. Click **"Start containers"**.
3. Wait for all containers to show as **running** (this can take 5–10 minutes on first run as images download).

![Nextcloud AIO showing containers starting up](images/nextcloud-aio-containers.png)

### Access Nextcloud

Once all containers are running, open your browser and navigate to:

```
https://drive.YOUR-TAILNET-NAME.ts.net
```

> You must be connected to your Tailscale network to access this URL. If you're on the same machine running the stack, Tailscale is already running via the container.

You'll be prompted to create your Nextcloud admin account. Set a strong password.

---

## 9. Renewing TLS Certificates

Tailscale certificates expire every **90 days**. To renew them, run from the project folder:

**Windows (PowerShell):**
```powershell
# Replace the domain with your NC_DOMAIN value from .env
docker compose exec tailscale tailscale cert --cert-file /tmp/ts.crt --key-file /tmp/ts.key drive.YOUR-TAILNET-NAME.ts.net
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

**Linux/WSL:**
```bash
./renew-certs.sh
```

> `renew-certs.sh` reads `NC_DOMAIN` from your `.env` file automatically.

Set a reminder to run this every ~80 days, or automate it with Task Scheduler on Windows.

---

## Troubleshooting

**Tailscale container doesn't appear in admin console**
- Double-check your `TS_AUTH_KEY` in `.env` — make sure there are no extra spaces or quotes.
- Make sure the `tag:nextcloud` tag is defined in your ACL policy before generating the key.

**Can't reach `https://drive.YOUR-TAILNET.ts.net`**
- Confirm the `drive` machine is showing as **Connected** in your Tailscale admin console.
- Make sure you're connected to Tailscale on the device you're browsing from.
- Check that the TLS certificate was issued by running the cert renewal commands above.

**`docker compose` command not found**
- Make sure Docker Desktop is running (check the system tray).
- Restart PowerShell after installing Docker Desktop.

**Port 8080 already in use**
- Another application on your PC is using port 8080. Stop it, or change `0.0.0.0:8080:8080` in `compose.yml` to use a different host port (e.g. `0.0.0.0:8081:8080`).

---

## File Reference

```
.
├── compose.yml          # Docker Compose stack definition
├── Caddyfile            # Caddy reverse proxy configuration
├── Caddy.Dockerfile     # Builds Caddy with the L4 module
├── .env.example         # Template — copy to .env and fill in your values
├── .env                 # Your secrets (never commit this!)
├── renew-certs.sh       # Script to renew Tailscale TLS certs (Linux/WSL)
└── start.bat            # Windows one-click start script
```

---

> **Security note:** The `.env` file contains your Tailscale auth key. Never commit it to a public repository. It is already listed in `.gitignore`.
