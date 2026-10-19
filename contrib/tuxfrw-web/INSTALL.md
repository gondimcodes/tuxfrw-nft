# TuxFrw-Web Installation and Configuration Guide

This document describes the complete procedure for building, installing, configuring, and running the **`tuxfrw-web`** management daemon in production on GNU/Linux servers already running **TuxFrw-NFT**.

*(Versão em português disponível em [INSTALL.pt-br.md](INSTALL.pt-br.md))*

---

## 1. Overview and Architecture

**TuxFrw-Web** is a lightweight, secure daemon written in **Rust** that serves as a management dashboard and web user interface for `TuxFrw-NFT`. Key features include:

- **Native HTTPS (TLS)**: End-to-end encrypted traffic with no mandatory reverse proxy required.
- **Native Dual-Stack (IPv6 + IPv4)**: Binds by default to `[::]:8443`, seamlessly serving IPv4 and IPv6 clients simultaneously.
- **Secure Authentication with Argon2id**: Password hashes are computed and verified using Argon2id and stored in `/etc/tuxfrw-nft/config.toml`.
- **Pre-Save 2-Tier Syntax Validation**: Validates shell syntax (`bash -n`) and performs dry-run validation against the Linux kernel nftables compiler (`nft -c`) before writing changes to disk, preventing syntax typos from breaking the firewall.
- **Zero Production Dependencies**: Compiles into a single standalone static binary with embedded HTML templates and assets.
- **Non-Destructive Operations**: Interfaces cleanly with `/usr/sbin/tuxfrw-nft` and inspects state via `nft -j list ruleset`.

---

## 2. Prerequisites

1. **Server with TuxFrw-NFT Installed**:
   - `/usr/sbin/tuxfrw-nft` executable present with `0700` permissions.
   - `/etc/tuxfrw-nft/` configuration directory configured and present.
   - Linux kernel with `nftables` enabled.
2. **Build Environment**:
   - When building on the server or on a dedicated build system:
     - Rust and Cargo (version 1.75 or higher recommended):
       ```bash
       curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
       source "$HOME/.cargo/env"
       ```
     - Essential build tools and libraries:
       ```bash
       # Debian / Ubuntu:
       sudo apt update && sudo apt install -y build-essential pkg-config libssl-dev

       # RHEL / Rocky Linux / AlmaLinux:
       sudo dnf groupinstall -y "Development Tools" && sudo dnf install -y openssl-devel
       ```

---

## 3. Build Instructions

Run the release build from the source directory:

```bash
cd contrib/tuxfrw-web
cargo build --release
```

The optimized binary is generated at:
`target/release/tuxfrw-web`

---

## 4. System Installation

Using superuser privileges (`root`), copy the executable and set up the `/etc/tuxfrw-nft` directory structure:

```bash
# 1. Install the binary into the system PATH
sudo cp target/release/tuxfrw-web /usr/local/bin/tuxfrw-web
sudo chown root:root /usr/local/bin/tuxfrw-web
sudo chmod 0700 /usr/local/bin/tuxfrw-web

# 2. Create the directory for TLS certificates
sudo mkdir -p /etc/tuxfrw-nft/tls
sudo chmod 0700 /etc/tuxfrw-nft/tls

# 3. Copy the configuration file to /etc/tuxfrw-nft/config.toml
# (if not already present)
if [ ! -f /etc/tuxfrw-nft/config.toml ]; then
    sudo cp config.example.toml /etc/tuxfrw-nft/config.toml
    sudo chown root:root /etc/tuxfrw-nft/config.toml
    sudo chmod 0600 /etc/tuxfrw-nft/config.toml
fi
```

### Permissions Summary

| Path | Mode | Owner | Purpose |
| :--- | :--- | :--- | :--- |
| `/usr/local/bin/tuxfrw-web` | `0700` (`rwx------`) | `root:root` | Daemon executable binary |
| `/etc/tuxfrw-nft/config.toml` | `0600` (`rw-------`) | `root:root` | Server configuration and credentials |
| `/etc/tuxfrw-nft/tls/` | `0700` (`rwx------`) | `root:root` | TLS certificates and private keys |

---

## 5. Detailed Configuration (`/etc/tuxfrw-nft/config.toml`)

Edit the configuration file:
```bash
sudo nano /etc/tuxfrw-nft/config.toml
```

Recommended configuration for production:

```toml
[server]
# Listen on all IPv6 and IPv4 interfaces (Dual-Stack) on port 8443:
listen = "[::]:8443"

# URL base path (keep "/" for root)
base_path = "/"

# Enable HTTPS
tls_enabled = true

# TLS certificate and key paths
cert_path = "/etc/tuxfrw-nft/tls/cert.pem"
key_path = "/etc/tuxfrw-nft/tls/key.pem"

# When true, automatically generates a self-signed ECDSA certificate if missing
auto_generate_self_signed = true

[auth]
# Dashboard administrator username
username = "admin"

# Argon2id password hash
# Default initial password: "admin"
password_hash = "$argon2id$v=19$m=19456,t=2,p=1$c29tZXNhbHQ$59f1rFvjDsmE8Fj2kU+sV3R6/pL2y3rB8Q2wVb1zKxY"

# Session expiration in minutes
session_timeout_minutes = 60

# Session secret key (leave blank to auto-generate randomly on startup)
secret_key = ""

[firewall]
# TuxFrw executable path
tuxfrw_bin = "/usr/sbin/tuxfrw-nft"

# Base configuration directory
config_dir = "/etc/tuxfrw-nft"

# nftables binary path
nft_bin = "/usr/sbin/nft"

# Timeout in seconds for firewall execution
command_timeout_seconds = 15
```

> [!TIP]
> **Generating an Argon2id Password Hash**:
> You can generate a hash for any new password using the built-in CLI helper:
> ```bash
> tuxfrw-web --hash-password "your_new_secret_password"
> ```
> The output hash can be directly copied into the `password_hash` field of `/etc/tuxfrw-nft/config.toml`.

---

## 6. TLS Certificates (HTTPS)

`tuxfrw-web` supports two TLS modes:

### Option A: Automatic Self-Signed Certificate (Default)
When `auto_generate_self_signed = true` and no certificate files exist at `/etc/tuxfrw-nft/tls/`, the daemon **automatically generates** an ECDSA self-signed certificate upon initial startup.
- Web browsers will show a standard self-signed certificate warning ("Your connection is not private"). Proceed past the prompt to access the panel.

### Option B: Trusted CA Certificate (Let's Encrypt / Certbot / Corporate PKI)
If you have a trusted certificate issued for your server domain (e.g. `firewall.example.com`):

```bash
# Example with Certbot:
sudo cp /etc/letsencrypt/live/firewall.example.com/fullchain.pem /etc/tuxfrw-nft/tls/cert.pem
sudo cp /etc/letsencrypt/live/firewall.example.com/privkey.pem /etc/tuxfrw-nft/tls/key.pem

# Apply strict permissions
sudo chown root:root /etc/tuxfrw-nft/tls/*
sudo chmod 0600 /etc/tuxfrw-nft/tls/key.pem
sudo chmod 0644 /etc/tuxfrw-nft/tls/cert.pem
```

---

## 7. Firewall Rules for Inbound Web Traffic (`TuxFrw-NFT`)

> [!IMPORTANT]
> Because TuxFrw-NFT operates with a default drop policy for inbound traffic (`INPUT drop`), TCP port `8443` **must be allowed** for authorized management IP addresses in [`rules/tf_INPUT.mod`](/etc/tuxfrw-nft/rules/tf_INPUT.mod); otherwise, inbound requests will be dropped by the kernel before reaching the web socket.

Edit `/etc/tuxfrw-nft/rules/tf_INPUT.mod`:

### Example 1: Allow port 8443 for LAN / Internal Network Only
```bash
if [ "$INT_IFACE" != "" ]; then
    $NFT "add rule inet filter INPUT iifname $INT_IFACE tcp dport 8443 counter accept"
fi
```

### Example 2: Allow port 8443 for Remote Admin IPs
```bash
if [ "$RMT_ADMIN_IP" != "" ]; then
    $NFT "add rule inet filter INPUT ip saddr $RMT_ADMIN_IP tcp dport 8443 counter accept"
fi
if [ "$RMT_ADMIN_IP6" != "" ]; then
    $NFT "add rule inet filter INPUT ip6 saddr $RMT_ADMIN_IP6 tcp dport 8443 counter accept"
fi
```

### Example 3: Allow port 8443 via VPN Interfaces
Add the following to `/etc/tuxfrw-nft/rules/tf_INPUT.mod`:
```bash
# Allow web management from active VPN tunnels:
if [ "$OpenVPN_IFACE" != "" ]; then
    $NFT "add rule inet filter INPUT iifname $OpenVPN_IFACE tcp dport 8443 counter accept"
fi
if [ "$WG_IFACE" != "" ]; then
    $NFT "add rule inet filter INPUT iifname $WG_IFACE tcp dport 8443 counter accept"
fi
```

Reload the input rules after making changes:
```bash
sudo tuxfrw-nft load INPUT
```

---

## 8. Automatic Startup with Systemd (`tuxfrw-web.service`)

The repository includes a ready-to-use systemd unit in [`tuxfrw-web.service`](tuxfrw-web.service).

### 8.1. Installing the Service Unit

```bash
# Option A: Copy the unit file provided in the repository
sudo cp tuxfrw-web.service /etc/systemd/system/tuxfrw-web.service
sudo chmod 0644 /etc/systemd/system/tuxfrw-web.service

# Option B: Create/edit manually with nano
sudo nano /etc/systemd/system/tuxfrw-web.service
```

### 8.2. Unit File Content (`/etc/systemd/system/tuxfrw-web.service`)

```ini
[Unit]
Description=TuxFrw-NFT Web Management Daemon (HTTPS Dual-Stack)
Documentation=https://github.com/gondimcodes/tuxfrw-nft
After=network-online.target tuxfrw-nft.service
Wants=network-online.target tuxfrw-nft.service

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/tuxfrw-web
Restart=on-failure
RestartSec=5s

# Hardening and operational limits
LimitNOFILE=65535
TimeoutStopSec=10s
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

### 8.3. Directives Technical Details

- **`After=network-online.target tuxfrw-nft.service`**: Guarantees the web daemon only binds after the network and firewall rules are fully initialized in the kernel.
- **`Wants=network-online.target tuxfrw-nft.service`**: Declares soft startup dependency with the core firewall service.
- **`Restart=on-failure` & `RestartSec=5s`**: High availability and resilience: automatically restarts the daemon after 5 seconds if terminated unexpectedly.
- **`LimitNOFILE=65535`**: Raises file descriptor limits to handle high connection volume without socket starvation.
- **`PrivateTmp=true`**: Sandboxes `/tmp` in an isolated kernel namespace.

### 8.4. Service Management Commands

```bash
# 1. Reload systemd to recognize the unit
sudo systemctl daemon-reload

# 2. Enable and start the service immediately (--now)
sudo systemctl enable --now tuxfrw-web

# 3. Check status
sudo systemctl status tuxfrw-web

# 4. Standard management commands
sudo systemctl restart tuxfrw-web   # Restart the daemon
sudo systemctl stop tuxfrw-web      # Stop the daemon
sudo systemctl disable tuxfrw-web   # Remove from auto-start

# 5. Monitor real-time logs
sudo journalctl -u tuxfrw-web -f
```

---

## 9. Verification and First Access

1. **Open your browser**:
   ```text
   https://<SERVER_IP_OR_HOSTNAME>:8443
   ```
   *(For IPv6: `https://[2001:db8::1]:8443`)*

2. **Log In**:
   - **Username**: `admin`
   - **Password**: `admin`

3. **Explore Dashboard Features**:
   - **Dashboard**: View active Netfilter ruleset status and run quick actions (`Start`, `Restart`, `Stop`, `Update Cloudflare`, `PANIC Mode`, and `Reload Module`).
   - **tuxfrw.conf**: Inspect and edit the main firewall configuration file.
   - **Módulos Rules**: Inspect, test (`🧪 Testar Sintaxe`), and safely edit any rules module (`rules/tf_*.mod`) with automatic 2-tier pre-save validation.

---

## 10. Troubleshooting and Diagnostics

### Check real-time logs
```bash
sudo journalctl -u tuxfrw-web -f
```

### Test daemon health endpoint from CLI (IPv4 & IPv6)
```bash
# Test local IPv4
curl -k -I https://127.0.0.1:8443/health

# Test local IPv6
curl -k -I https://[::1]:8443/health
```
Both commands should return an HTTP 200 response:
`HTTP/2 200` or `HTTP/1.1 200 OK`

### Port 8443 Conflict
If port 8443 is already in use by another service:
1. Update `listen = "[::]:9443"` in `/etc/tuxfrw-nft/config.toml`.
2. Update the allow rule in `tf_INPUT.mod` to match the new port.
3. Restart the service: `sudo systemctl restart tuxfrw-web`.

### Browser Connection Timeout / Refused
1. Verify the daemon is active: `sudo systemctl status tuxfrw-web`.
2. Verify the socket is listening: `sudo ss -tulpn | grep 8443`.
3. Check if TuxFrw-NFT is dropping packets: `sudo journalctl -k -f | grep "tuxfrw:"`.
4. Ensure you added the allow rule in `/etc/tuxfrw-nft/rules/tf_INPUT.mod` as described in Section 7.
