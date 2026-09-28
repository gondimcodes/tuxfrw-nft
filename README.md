# TuxFrw-NFT

> **The ultimate Linux firewall automation and management tool using Netfilter/nftables.**  
> *Version 5.0*

[![License: GPLv2](https://img.shields.io/badge/License-GPLv2-blue.svg)](LICENSE)
[![Netfilter](https://img.shields.io/badge/Netfilter-nftables-orange.svg)](https://wiki.nftables.org/)
[![Dual-Stack](https://img.shields.io/badge/Dual--Stack-IPv4%20%2F%20IPv6-brightgreen.svg)](#)
[![Docker](https://img.shields.io/badge/Docker-Native%20Compatible-2496ED.svg)](#native-docker-compatibility-mode-docker_support1)

---

## Languages / Idiomas
- 🇺🇸 [English (README.md)](README.md) | [Installation Guide (INSTALL.md)](INSTALL.md)
- 🇧🇷 [Português do Brasil (README.pt-br.md)](README.pt-br.md) | [Guia de Instalação (INSTALL.pt-br.md)](INSTALL.pt-br.md)

---

## Table of Contents
- [Overview](#overview)
- [Key Features](#key-features)
- [Directory Structure](#directory-structure)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [CLI Usage](#cli-usage)
- [Operational Modes](#operational-modes)
  - [Native Docker Mode (`DOCKER_SUPPORT="1"`)](#native-docker-compatibility-mode-docker_support1)
  - [Classic Gateway Mode (`DOCKER_SUPPORT="0"`)](#classic-gateway-mode-docker_support0)
- [Technical Documentation](#technical-documentation)
- [Authorship & Historical Credits](#authorship--historical-credits)
- [License](#license)

---

## Overview

**TuxFrw-NFT** is a comprehensive firewall automation and security tool for GNU/Linux based entirely on the modern **Netfilter/nftables** subsystem.

The tool compiles rule definitions into an atomic ruleset batch file (`/etc/tuxfrw-nft/tuxfrw.nft`), which is loaded directly into the Linux kernel via `/usr/sbin/nft -f`. Its modular architecture allows system administrators and network engineers to configure declarative, deterministic, and easily auditable network policies without dealing with repetitive low-level syntax.

---

## Key Features

- **Atomic Compilation**: Rules are compiled in batch and committed to the kernel in a single atomic transaction, preventing intermediate states or packet loss during updates.
- **Native Dual-Stack**: Unified handling of IPv4 and IPv6 traffic via the `inet` family, eliminating the historical split between `iptables` and `ip6tables`.
- **Native Docker Compatibility (`DOCKER_SUPPORT="1"`)**:
  - Full host hardening in the `INPUT` hook;
  - Granular container access control on the `FORWARD` hook using `rules/tf_DOCKER.mod` running at higher priority (`priority -5`);
  - Non-destructive lifecycle: avoids `flush ruleset`, keeping Docker virtual bridges (`docker0`, `br-*`), daemon chains, and internal NAT intact;
  - Unrestricted outbound container traffic and fine-grained access policies for published container services (`-p`).
- **Ingress Pre-Filtering (`netdev`)**:
  - Drops invalid TCP flags (Xmas, NULL, SYN/FIN) directly on physical network cards, saving CPU cycles;
  - Anti-spoofing and optional Bogon filtering decoupled from private RFC 1918 subnets.
- **Stateful Packet Inspection**: Rigorous connection tracking (`ct state established, related`) with explicit dropping of invalid states.
- **Classic Gateway / Router Mode (`DOCKER_SUPPORT="0"`)**:
  - Full directional matrix: `EXT`, `INT`, `DMZ`, and VPN tunnels (`OpenVPN`, `PPTP`);
  - Native nftables NAT: DNAT/Port Forwarding (`tf_NAT-IN.mod`) and SNAT/Masquerade (`tf_NAT-OUT.mod`).
- **Dynamic Atomic Reloading**: Reload individual modules on the fly without bouncing the entire firewall (e.g., `tuxfrw-nft load DOCKER`).
- **Native Systemd Integration**: Dedicated `tuxfrw-nft.service` unit configured to run before network initialization targets.

---

## Directory Structure

### Repository Tree (Source Code)

```text
tuxfrw-nft/
├── tuxfrw-nft                    # Main CLI management launcher script
├── tuxfrw.conf                   # Central configuration file and network parameters
├── tuxfrw-nft.service            # Systemd service unit for service supervision
├── install.sh                    # Installation script with validation and upgrade checks
├── tf_BASE.mod                   # Firewall core (tables, atomic compilation, safe cleanup)
├── tf_KERNEL.mod                 # Kernel module loading and sysctl IP forwarding controls
├── rules/                        # Specialized Netfilter/nftables rule modules
│   ├── tf_INPUT.mod              # Host protection and inbound policies (hook input)
│   ├── tf_OUTPUT.mod             # Host outbound policies and exceptions (hook output)
│   ├── tf_DOCKER.mod             # Container firewall policies (FORWARD priority -5)
│   ├── tf_NETDEV.mod             # Ingress pre-filtering on physical NICs (netdev)
│   ├── tf_FORWARD.mod            # Routing and forwarding matrix (Gateway Mode)
│   ├── tf_MANGLE.mod             # Packet mangling and TCP MSS clamping
│   ├── tf_NAT-IN.mod             # Port Forwarding / DNAT in PREROUTING
│   ├── tf_NAT-OUT.mod            # Masquerade / SNAT in POSTROUTING
│   ├── tf_INT-EXT.mod            # Internal network (INT) to Internet (EXT) traffic
│   ├── tf_EXT-INT.mod            # Internet (EXT) to internal network (INT) traffic
│   ├── tf_INT-DMZ.mod            # Internal network (INT) to DMZ traffic
│   ├── tf_DMZ-INT.mod            # DMZ to internal network (INT) traffic
│   ├── tf_EXT-DMZ.mod            # Internet (EXT) access to DMZ servers
│   ├── tf_DMZ-EXT.mod            # DMZ servers to Internet (EXT) traffic
│   ├── tf_INT-VPN.mod            # Internal network (INT) to VPN tunnels traffic
│   ├── tf_VPN-INT.mod            # VPN tunnels to internal network (INT) traffic
│   ├── tf_EXT-VPN.mod            # Internet (EXT) to VPN tunnels traffic
│   ├── tf_VPN-EXT.mod            # VPN tunnels to Internet (EXT) traffic
│   ├── tf_DMZ-VPN.mod            # DMZ to VPN tunnels traffic
│   └── tf_VPN-DMZ.mod            # VPN tunnels to DMZ traffic
├── manual/                       # In-depth technical documentation manuals
│   ├── tuxfrw-manual-5.00-pt-br.md # Complete technical manual in Brazilian Portuguese
│   └── tuxfrw-manual-5.00-en.md    # Complete technical manual in English
├── README.md & README.pt-br.md   # Project overview and main documentation (EN / PT-BR)
├── INSTALL.md & INSTALL.pt-br.md # Installation and validation guides (EN / PT-BR)
├── CHANGELOG.md                  # Release notes and change history (Keep a Changelog)
├── CREDITS.md                    # Historical credits from legacy versions (IPTables/CFTK)
├── AUTHORS                       # Project author and maintainer
├── LICENSE                       # GNU General Public License v2 (GPLv2)
└── VERSION                       # Current release version string (5.0)
```

### OS Deployment Layout

When `./install.sh` is executed, files are installed to the system with strict permissions:

| System Path | Permissions | Purpose |
| :--- | :--- | :--- |
| `/usr/sbin/tuxfrw-nft` | `0700` (`rwx------`) | Executable CLI management script |
| `/etc/systemd/system/tuxfrw-nft.service` | `0644` (`rw-r--r--`) | Systemd service unit |
| `/etc/tuxfrw-nft/` | `0700` (`rwx------`) | Configuration and rule modules directory |
| `/etc/tuxfrw-nft/tuxfrw.conf` | `0600` (`rw-------`) | Central firewall configuration |
| `/etc/tuxfrw-nft/tf_BASE.mod` | `0600` (`rw-------`) | Base orchestration and batch compiler |
| `/etc/tuxfrw-nft/tf_KERNEL.mod` | `0600` (`rw-------`) | Kernel modules and sysctl tuning |
| `/etc/tuxfrw-nft/rules/*.mod` | `0600` (`rw-------`) | 20 specialized rule modules |

---

## Requirements

- **Operating System**: GNU/Linux (kernel 4.19 or higher with `nf_tables` support);
- **nftables Utility**: `nftables` package installed (`nft` version 0.9.0 or higher);
- **Shell**: Bash (`/bin/bash`);
- **Privileges**: Superuser (`root`) access.

---

## Quick Start

> See [INSTALL.md](INSTALL.md) for detailed, step-by-step instructions.

```bash
# 1. Clone the repository
git clone https://github.com/gondimcodes/tuxfrw-nft.git
cd tuxfrw-nft

# 2. Run the installer as root
sudo ./install.sh

# 3. Configure your variables and mode
sudo nano /etc/tuxfrw-nft/tuxfrw.conf

# 4. Start in testing mode
sudo tuxfrw-nft start

# 5. Once validated, enable at system boot
sudo systemctl enable tuxfrw-nft
```

---

## CLI Usage

The `/usr/sbin/tuxfrw-nft` launcher supports the following operations:

| Command | Description |
| :--- | :--- |
| `tuxfrw-nft start` | Compiles modules and atomically loads the ruleset into the kernel |
| `tuxfrw-nft stop` | Safely tears down TuxFrw tables (preserving Docker in Docker mode) |
| `tuxfrw-nft restart` | Runs `stop` followed by `start` |
| `tuxfrw-nft status` | Displays active tables and chains created by TuxFrw-NFT |
| `tuxfrw-nft load <MODULE>` | Atomically recompiles and reloads only the specified module |
| `tuxfrw-nft panic` | Emergency lockdown: immediately drops all network traffic |
| `tuxfrw-nft natopen` | *(Gateway Mode)* Dynamically loads DNAT rules on demand |

### Dynamic Reloading Examples

```bash
# Apply container policy adjustments after editing rules/tf_DOCKER.mod
tuxfrw-nft load DOCKER

# Refresh host protections after updating rules/tf_INPUT.mod
tuxfrw-nft load INPUT

# Update internal routing rules after editing rules/tf_INT-EXT.mod
tuxfrw-nft load INT-EXT
```

---

## Operational Modes

### Native Docker Compatibility Mode (`DOCKER_SUPPORT="1"`)
Recommended for application servers hosting Docker containers.
- The physical host is protected under `INPUT`.
- Container inbound traffic is filtered in `FORWARD` at `priority -5` via `rules/tf_DOCKER.mod` before Docker's default permissive accept rules.
- Container outbound traffic (package updates, external DNS queries) is fully preserved.
- Avoids `flush ruleset`, preventing destruction of Docker daemon virtual bridges.

### Classic Gateway Mode (`DOCKER_SUPPORT="0"`)
Recommended for perimeter routers and corporate firewalls.
- Enables the full multi-zone forwarding matrix (`INT`, `EXT`, `DMZ`, VPNs).
- Loads nftables NAT tables (SNAT/Masquerade and DNAT/Port Forwarding).
- Controls system-wide kernel IP forwarding via `tf_KERNEL.mod`.

---

## Technical Documentation

In-depth technical manuals and architecture guides:
- [Complete TuxFrw-NFT Technical Manual (English)](manual/tuxfrw-manual-5.00-en.md)
- [Manual Completo do TuxFrw-NFT (Português)](manual/tuxfrw-manual-5.00-pt-br.md)
- [Installation Guide (English)](INSTALL.md)
- [Guia de Instalação (Português)](INSTALL.pt-br.md)
- [Release Notes & Changelog](CHANGELOG.md)

---

## Authorship & Historical Credits

**The TuxFrw Team**
- **Marcelo Gondim** <gondim@gmail.com> (Author & Primary Maintainer - TuxFrw-NFT 5.0)

Acknowledgments and contributions to legacy project versions (Netfilter/IPTables and Conectiva CFTK) are documented in [CREDITS.md](CREDITS.md).

Official Repository: [https://github.com/gondimcodes/tuxfrw-nft](https://github.com/gondimcodes/tuxfrw-nft)

---

## License

This project is free software released under the terms of the **GNU General Public License v2 (GPLv2)**. See the [LICENSE](LICENSE) file for details.
