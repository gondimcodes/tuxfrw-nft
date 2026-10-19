# TuxFrw-Web

> **Web Management Dashboard and Control Daemon for TuxFrw-NFT Firewall**  
> *Built in Rust with Axum, Tokio, Native HTTPS (TLS), Dual-Stack IPv6/IPv4, and Cryptographic CAPTCHA.*

---

## Key Features

- **Memory Safety & High Performance**: Developed 100% in **Rust**, compiling into a single self-contained static executable with zero runtime dependencies (no Node.js, Python, or PHP required on production servers).
- **Native HTTPS (TLS)**: Integrated TLS engine via `rustls` supporting standard PEM certificates or automatic ECDSA self-signed certificate generation on first startup.
- **Native Dual-Stack (IPv6 + IPv4)**: Daemon binds to `[::]:8443` (or customizable port such as `9443`), concurrently serving both IPv6 and IPv4 clients.
- **Secure Authentication via Argon2id & REST API**: Strong password hashing using Argon2id stored in `/etc/tuxfrw-nft/config.toml`, with session cookies hardened via `HttpOnly; Secure; SameSite=Lax`.
- **Cryptographic SVG CAPTCHA**: Dynamic vector challenge with non-ambiguous characters, optical noise lines, neon glow dispersion filter, and stateless HMAC-SHA256 signature (5-minute TTL, anti-replay, and anti-brute-force).
- **Multilingual Support (i18n)**: Instant dynamic language switching between **🇺🇸 English** and **🇧🇷 Português (Brasil)** across all templates and system messages.
- **Quick Operations Panel**:
  - `start`, `stop` (non-destructive), `restart`, `cf-update` (Cloudflare CDN IP ranges);
  - **Panic Mode (Emergency Lockdown)** with confirmation dialog.
- **Dynamic Atomic Module Reloading**:
  - Quick selector for all 22 rules modules (`INPUT`, `SYNPROXY`, `DOCKER`, `FORWARD`, `URPF`, `NETDEV`, etc.), executing `tuxfrw-nft load <MODULE>` with live console feedback.
- **Integrated Web Editor with Two-Tier Syntax Validation**:
  - Direct and secure editing of `/etc/tuxfrw-nft/tuxfrw.conf` and all rule files under `/etc/tuxfrw-nft/rules/*.mod`.
  - Automated pre-save validation using `bash -n` and `nft -c` (kernel dry-run), blocking disk writes upon syntax errors to protect system stability.
- **Real-Time Execution Console**: Live terminal stream with full ANSI color decoding and monospace formatting.

> For complete installation and setup instructions, refer to [**INSTALL.md (English)**](INSTALL.md) or [**INSTALL.pt-br.md (Português)**](INSTALL.pt-br.md).

---

## Project Structure

```text
contrib/tuxfrw-web/
├── Cargo.toml               # Rust dependencies (Axum, Tokio, Rustls, Argon2, HMAC, Askama)
├── config.example.toml      # Reference configuration template for /etc/tuxfrw-nft/config.toml
├── README.md                # English technical documentation
├── README.pt-br.md          # Portuguese technical documentation
├── INSTALL.md               # English installation guide
├── INSTALL.pt-br.md         # Portuguese installation guide
├── tuxfrw-web.service       # Systemd service unit definition
├── src/
│   ├── main.rs              # Daemon entry point, HTTPS and Dual-Stack bindings
│   ├── config.rs            # Configuration loader and atomic TOML writer
│   ├── tls.rs               # TLS certificate loader and automatic generator
│   ├── auth/                # Argon2id hashing, session store, and CaptchaEngine
│   │   ├── mod.rs
│   │   ├── captcha.rs
│   │   ├── password.rs
│   │   └── session.rs
│   ├── firewall/            # CLI command execution and syntax validation service
│   │   ├── mod.rs
│   │   ├── command.rs
│   │   └── config_parser.rs
│   └── routes/              # HTTP handlers, REST API endpoints, and auth middleware
│       ├── mod.rs
│       ├── auth.rs
│       ├── dashboard.rs
│       ├── config_view.rs
│       ├── rules_view.rs
│       └── api.rs
└── templates/               # Precompiled HTML templates via Askama
    ├── base.html
    ├── login.html
    ├── dashboard.html
    ├── config.html
    └── rules.html
```

---

## Build & Installation

### 1. Build the Binary
On the build or staging server:
```bash
cd contrib/tuxfrw-web
cargo build --release
```
The optimized executable binary will be generated at `target/release/tuxfrw-web`.

### 2. Operating System Installation
```bash
# Copy the compiled binary to system executable path
sudo cp target/release/tuxfrw-web /usr/local/bin/tuxfrw-web
sudo chmod 0700 /usr/local/bin/tuxfrw-web

# Install sample configuration template to /etc/tuxfrw-nft/config.toml
sudo cp config.example.toml /etc/tuxfrw-nft/config.toml
sudo chmod 0600 /etc/tuxfrw-nft/config.toml
```

### 3. Systemd Service Configuration (`tuxfrw-web.service`)
Deploy the unit file:

```bash
sudo cp tuxfrw-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tuxfrw-web
```

---

## Initial Access

Open your web browser and navigate to:
`https://<SERVER_IP>:8443` (or configured port, e.g. `9443`)

- **Default Username**: `admin`
- **Default Password**: `admin`

> [!IMPORTANT]
> Change the default password immediately after initial login or generate a new Argon2id hash using `tuxfrw-web --hash-password <NEW_PASSWORD>` to replace the value in `/etc/tuxfrw-nft/config.toml`.
