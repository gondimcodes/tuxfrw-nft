# TuxFrw-NFT Installation Guide

> This document details the step-by-step procedures for installing, configuring, verifying, and activating **TuxFrw-NFT** on GNU/Linux systems.

For full architecture details and rule explanations, see:
- [English README](README.md)
- [Brazilian Portuguese README](README.pt-br.md)
- [Complete Technical Manual](manual/tuxfrw-manual-5.1-en.md)

---

## Table of Contents
- [1. Prerequisites](#1-prerequisites)
- [2. Installation Procedure](#2-installation-procedure)
- [3. Initial Configuration](#3-initial-configuration)
- [4. Runtime Testing (Preventing Lockouts)](#4-runtime-testing-preventing-lockouts)
- [5. Enabling at Boot (Systemd)](#5-enabling-at-boot-systemd)
- [6. Uninstallation](#6-uninstallation)

---

## 1. Prerequisites

Before installing TuxFrw-NFT, verify that the host meets the following requirements:

| Component | Minimum Requirement | Notes |
| :--- | :--- | :--- |
| **Operating System** | GNU/Linux | Debian, Ubuntu, AlmaLinux, Rocky Linux, RHEL |
| **Linux Kernel** | 4.19 or higher | `nf_tables` subsystem enabled in kernel |
| **nftables Utility** | `nftables` package (nft ≥ 0.9.0) | Required for atomic batch compilation |
| **Shell** | Bash (`/bin/bash`) | Standard system interpreter |
| **Privileges** | `root` or `sudo` | Required to apply netfilter rules |

### Installing the nftables package

- **Debian / Ubuntu**:
  ```bash
  sudo apt update && sudo apt install nftables -y
  ```

- **AlmaLinux / Rocky Linux / RHEL / CentOS**:
  ```bash
  sudo dnf install nftables -y
  ```

---

## 2. Installation Procedure

1. Clone the repository on the target server:
   ```bash
   git clone https://github.com/gondimcodes/tuxfrw-nft.git
   cd tuxfrw-nft
   ```

2. Run the installation script as root:
   ```bash
   sudo ./install.sh
   ```

The installer performs the following automated tasks:
- Validates system requirements (`bash`, `nft`, `install` utility);
- Creates configuration directory `/etc/tuxfrw-nft` with restricted permissions (`0700`);
- Installs rule modules and config files with restricted permissions (`0600`);
- Installs the main CLI script at `/usr/sbin/tuxfrw-nft` (`0700`);
- Installs the systemd unit `/etc/systemd/system/tuxfrw-nft.service` and executes `systemctl daemon-reload`;
- Detects existing installations and prompts for explicit confirmation before overwriting files.

> [!IMPORTANT]
> **Lockout Prevention**: The installer **DOES NOT** enable the service at boot (`systemctl enable`) automatically. This prevents accidental SSH lockout before administrators can review and tailor rules to their environment.

---

## 3. Initial Configuration

Before launching TuxFrw-NFT for the first time:

### 1) Edit `/etc/tuxfrw-nft/tuxfrw.conf`

```bash
sudo nano /etc/tuxfrw-nft/tuxfrw.conf
```

- **Select the operational mode**:
  - `DOCKER_SUPPORT="1"`: Application servers running Docker.
  - `DOCKER_SUPPORT="0"`: Classic Gateway/Router mode with NAT.
- **Configure network interfaces**:
  - Example: `IF_EXT="eth0"`, `IF_INT="eth1"`, `IF_DMZ="eth2"`.
- **Set administrative access**:
  - Define `ADMIN_IPS` and `ADMIN_PORTS` to ensure SSH and management access remain open.
- **Review BOGONS parameter**:
  - Defaults to `BOGONS="0"` (disabled) to avoid dropping private subnets (RFC 1918) and internal DNS resolvers.

### 2) Review rule modules under `/etc/tuxfrw-nft/rules/`

- **Local Host Protection**: `/etc/tuxfrw-nft/rules/tf_INPUT.mod` (SSH, ICMP, DNS, local services).
- **Docker Mode**: `/etc/tuxfrw-nft/rules/tf_DOCKER.mod` (container published port rules).
- **Gateway Mode**: `/etc/tuxfrw-nft/rules/tf_FORWARD.mod`, `tf_NAT-IN.mod`, and `tf_NAT-OUT.mod`.

---

## 4. Runtime Testing (Preventing Lockouts)

> [!TIP]
> Always maintain an active contingency SSH session in a separate terminal window when testing rules for the first time.

1. Start TuxFrw-NFT manually:
   ```bash
   sudo tuxfrw-nft start
   ```

2. Confirm loaded tables and chains:
   ```bash
   sudo tuxfrw-nft status
   ```

3. Inspect live kernel rules:
   ```bash
   sudo nft list ruleset
   ```

4. Verify outbound connectivity, Docker container access (if applicable), and SSH sessions.

---

## 5. Enabling at Boot (Systemd)

Once rules are tested and verified to operate cleanly without lockouts, enable TuxFrw-NFT to launch automatically on system boot:

```bash
sudo systemctl enable tuxfrw-nft
```

Systemd management commands:
```bash
sudo systemctl start tuxfrw-nft
sudo systemctl stop tuxfrw-nft
sudo systemctl restart tuxfrw-nft
sudo systemctl status tuxfrw-nft
```

---

## 6. Uninstallation

To cleanly remove TuxFrw-NFT from the system:

1. Stop the service and flush active TuxFrw rules:
   ```bash
   sudo tuxfrw-nft stop
   ```

2. Disable and delete the systemd unit:
   ```bash
   sudo systemctl disable tuxfrw-nft
   sudo rm -f /etc/systemd/system/tuxfrw-nft.service
   sudo systemctl daemon-reload
   ```

3. Remove the executable and configuration directory:
   ```bash
   sudo rm -f /usr/sbin/tuxfrw-nft
   sudo rm -rf /etc/tuxfrw-nft
   ```
