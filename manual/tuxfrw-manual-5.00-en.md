# TuxFrw-NFT Technical Manual

> **Comprehensive Guide on Architecture, Operations, Docker Integration, and Diagnostics**  
> *Version 5.0*

---

## Table of Contents
- [1. Introduction](#1-introduction)
  - [Network Zones](#network-zones)
- [2. Architectural Features](#2-architectural-features)
- [3. Modular Structure and Execution Flow](#3-modular-structure-and-execution-flow)
- [4. Component Overview](#4-component-overview)
- [5. CLI Operation & Management](#5-cli-operation--management)
- [6. Docker Compatibility Mode (`DOCKER_SUPPORT="1"`)](#6-docker-compatibility-mode-docker_support1)
  - [The Default Docker Security Pitfall](#the-default-docker-security-pitfall)
  - [The TuxFrw-NFT Architectural Solution](#the-tuxfrw-nft-architectural-solution)
  - [Practical Container Rule Examples](#practical-container-rule-examples)
- [7. Troubleshooting & Error Diagnosis](#7-troubleshooting--error-diagnosis)
- [8. Installation and Systemd Boot Initialization](#8-installation-and-systemd-boot-initialization)
- [9. References and Credits](#9-references-and-credits)

---

## 1. Introduction

**TuxFrw-NFT** is a modular shell-based firewall automation framework that generates deterministic rules for the Linux **Netfilter/nftables** subsystem. The project is designed to make firewall administration, auditing, and maintenance straightforward and secure on mission-critical production servers.

The firewall dynamically compiles an atomic ruleset batch file executed directly by the kernel utility (`/usr/sbin/nft -f`). TuxFrw-NFT operates natively in **Dual-Stack** (IPv4 and IPv6 simultaneously across all tables in the `inet` family) and serves equally well on **application servers hosting Docker containers** and on **perimeter corporate gateways** interconnecting multiple zones:

### Network Zones

| Zone | Identifier | Purpose and Description |
| :--- | :--- | :--- |
| **External** | `EXT` | Public-facing network interface connected to the Internet or untrusted networks. Applies ingress pre-filtering (`netdev`) against invalid TCP flags, scans, and spoofing. |
| **Demilitarized** | `DMZ` | Semi-protected subnet for public-facing servers (HTTP, HTTPS, DNS, SMTP). Isolates the DMZ from accessing internal network resources. |
| **Internal** | `INT` | Local corporate network (LAN). Controls outbound traffic originating from the internal network destined to the Internet and DMZ, logging unauthorized connections. |

---

## 2. Architectural Features

### 1. Stateful Packet Inspection (`conntrack`)
Full connection state tracking (`ct state established, related`) for both IPv4 and IPv6. Drops invalid packets (`ct state invalid`) and eliminates the need for manual return-traffic rules.

### 2. Pre-Routing Ingress Filtering with Netdev (`tf_NETDEV.mod`)
Filtration directly at the network interface driver layer prior to kernel IP stack processing. Discards malformed TCP flags (Xmas scans, NULL scans, SYN/FIN anomalies) with minimal CPU overhead.

### 3. Unified Dual-Stack (`inet filter`)
Unlike legacy IPTables implementations that required separate scripts for IPv4 (`iptables`) and IPv6 (`ip6tables`), TuxFrw-NFT unifies rules under the `inet` family, applying policies seamlessly to both protocols within the same module files.

### 4. Network Address Translation (NAT via nftables)
In classic gateway mode (`DOCKER_SUPPORT="0"`), provides full NAT support:
- **SNAT / Masquerade**: Outbound translation in `POSTROUTING` (`tf_NAT-OUT.mod`);
- **DNAT / Port Forwarding**: Inbound port redirection in `PREROUTING` (`tf_NAT-IN.mod`).

### 5. Native Isolated Docker Integration (`DOCKER_SUPPORT="1"`)
Runs seamlessly on Docker host servers without interfering with Docker's virtual bridges (`docker0`, `br-*`) or internal NAT tables, hardening the physical host on `INPUT` and controlling container port access on `FORWARD` using higher priority (`priority -5`).

---

## 3. Modular Structure and Execution Flow

```text
                                /usr/sbin/tuxfrw-nft
                                         │
                                /etc/tuxfrw-nft/tuxfrw.conf
                                         │
                                /etc/tuxfrw-nft/tf_BASE.mod
                                         │
     ┌───────────────────────────────────┼───────────────────────────────────┐
     │                                   │                                   │
 tf_KERNEL.mod                   tf_INPUT.mod / tf_OUTPUT.mod          tf_NETDEV.mod
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │ (if DOCKER_SUPPORT="1")                       │ (if DOCKER_SUPPORT="0")
                 │                                               │
           tf_DOCKER.mod                                   tf_FORWARD.mod
         (FORWARD prio -5)                                (FORWARD prio 0)
                                                                 │
                                       ┌─────────────────────────┼─────────────────────────┐
                                       │            │            │            │            │
                                   tf_INT-EXT   tf_EXT-INT   tf_INT-DMZ   tf_DMZ-INT   tf_DMZ-EXT
                                       │            │            │            │            │
                                   tf_EXT-DMZ   tf_INT-VPN   tf_VPN-INT   tf_EXT-VPN   tf_VPN-EXT
                                                                 │
                                                            tf_DMZ-VPN / tf_VPN-DMZ
                                                                 │
                                                            tf_MANGLE.mod
                                                                 │
                                                       tf_NAT-IN / tf_NAT-OUT
```

---

## 4. Component Overview

| File / Module | Function and Purpose |
| :--- | :--- |
| `/usr/sbin/tuxfrw-nft` | CLI executable program. Processes command arguments (`start`, `stop`, `load`, etc.) and manages compiler execution. |
| `/etc/tuxfrw-nft/tuxfrw.conf` | Central configuration file. Defines network interfaces, administrative IPs, service ports, and Docker mode. |
| `/etc/tuxfrw-nft/tf_BASE.mod` | Firewall engine core. Orchestrates table creation, safe teardown (`clear_rules`), and batch compilation. |
| `/etc/tuxfrw-nft/tf_KERNEL.mod` | Kernel module loading (`modprobe`) and sysctl `net.ipv4/ipv6.conf.all.forwarding` controls. |
| `rules/tf_INPUT.mod` | Host defense rules (`INPUT`, policy drop): loopback, established states, ICMPv4/v6, DHCP, and SSH access. |
| `rules/tf_OUTPUT.mod` | Host egress rules (`OUTPUT`) for locally generated traffic. |
| `rules/tf_DOCKER.mod` | Active in Docker mode (`DOCKER_SUPPORT="1"`). Governs container traffic on the `FORWARD` hook at priority `-5`. |
| `rules/tf_FORWARD.mod` | Classic routing and zone forwarding (`DOCKER_SUPPORT="0"`). Branches to directional rule modules. |
| `rules/tf_NETDEV.mod` | Ingress filtering at physical interface level against TCP flag attacks and spoofed packets. |
| `rules/tf_NAT-IN.mod` | Inbound DNAT rules (Port Forwarding in `PREROUTING`). |
| `rules/tf_NAT-OUT.mod` | Outbound SNAT rules (Masquerade in `POSTROUTING`). |
| `/etc/systemd/system/tuxfrw-nft.service` | Dedicated systemd service configured for early boot startup (`Before=network-pre.target`). |

---

## 5. CLI Operation & Management

The `tuxfrw-nft` command must be run with `root` privileges:

### 1. Start the Firewall
```bash
sudo tuxfrw-nft start
# or: sudo systemctl start tuxfrw-nft
```
Compiles all modules into `/etc/tuxfrw-nft/tuxfrw.nft` and atomically applies them via `nft -f`.

### 2. Stop the Firewall
```bash
sudo tuxfrw-nft stop
# or: sudo systemctl stop tuxfrw-nft
```
Safely deletes TuxFrw tables (`inet filter`, `netdev filter`, `inet mangle`) without wiping Docker daemon chains or virtual bridges.

### 3. Check Status and Active Rules
```bash
sudo tuxfrw-nft status
```
Displays compiled rulesets currently active in the nftables subsystem.

### 4. Dynamic Atomic Reloading of a Specific Module
The `load` command atomically recompiles and reapplies only the specified module chain without dropping existing connections across other chains:
```bash
sudo tuxfrw-nft load INPUT     # Reload tf_INPUT.mod (e.g. updated SSH IPs)
sudo tuxfrw-nft load DOCKER    # Reload tf_DOCKER.mod (e.g. published container ports)
sudo tuxfrw-nft load OUTPUT    # Reload tf_OUTPUT.mod
sudo tuxfrw-nft load NETDEV    # Reload tf_NETDEV.mod
sudo tuxfrw-nft load INT-EXT   # Reload tf_INT-EXT.mod
sudo tuxfrw-nft load NAT-IN    # Reload tf_NAT-IN.mod
```

### 5. Panic Mode (Emergency Lockdown)
```bash
sudo tuxfrw-nft panic
```
Immediately stops all network traffic and drops host connections.

---

## 6. Docker Compatibility Mode (`DOCKER_SUPPORT="1"`)

### The Default Docker Security Pitfall
The Docker daemon manages its own Netfilter rules. When a container port is published (e.g. `docker run -p 3000:3000 ...`), Docker adds a DNAT rule in `PREROUTING` and routes the packet through the `FORWARD` hook.

1. **Without TuxFrw-NFT**: Docker defaults to accepting all forwarded traffic (`0.0.0.0/0`), exposing the container globally and bypassing `INPUT` host firewalls.
2. **With legacy IPTables firewalls**: Running a firewall restart (`flush ruleset`) stripped away Docker's chains and bridges, breaking container networking entirely.

### The TuxFrw-NFT Architectural Solution
- **Surgical Table Cleanup**: TuxFrw-NFT explicitly flushes only its own tables (`inet filter`, `netdev filter`, `inet mangle`), preserving Docker chains.
- **Higher Hook Priority (`priority -5`)**: Netfilter evaluates the `FORWARD` hook at priority 0 (`NF_IP_PRI_FILTER`). By configuring TuxFrw's Docker forward chain at priority `-5`, rules in `rules/tf_DOCKER.mod` are evaluated **before** Docker's default accept rules.

### Practical Container Rule Examples

Edit `/etc/tuxfrw-nft/rules/tf_DOCKER.mod`:

#### Example 1: Restrict a published container port (e.g. port 3000) to a trusted management IP
```bash
# Allow container port 3000 ONLY from the authorized management IP
$NFT 'add rule inet filter FORWARD ip saddr 203.0.113.50 tcp dport 3000 counter accept'

# Drop all other external attempts to reach port 3000
$NFT 'add rule inet filter FORWARD tcp dport 3000 counter drop'
```

#### Example 2: Allow a public web container (HTTP/HTTPS)
```bash
$NFT 'add rule inet filter FORWARD tcp dport { 80, 443 } counter accept'
```

#### Applying Changes with Zero Downtime
After updating `rules/tf_DOCKER.mod`, apply changes instantly:
```bash
sudo tuxfrw-nft load DOCKER
```

---

## 7. Troubleshooting & Error Diagnosis

TuxFrw-NFT compiles batch rules to `/etc/tuxfrw-nft/tuxfrw.nft` and executes them via `nft`. In case of syntax or configuration issues:

1. **Check execution error logs**:
   ```bash
   cat /tmp/tf_error
   ```

2. **Inspect the compiled batch file to locate offending lines**:
   ```bash
   less /etc/tuxfrw-nft/tuxfrw.nft
   ```

3. **Validate syntax directly using nftables (dry-run without applying)**:
   ```bash
   sudo /usr/sbin/nft -c -f /etc/tuxfrw-nft/tuxfrw.nft
   ```

4. **Monitor dropped packets in real time**:
   ```bash
   sudo journalctl -k -f | grep "tuxfrw:"
   ```
   *(Note: Ensure logging rules in the target module are uncommented).*

---

## 8. Installation and Systemd Boot Initialization

For a complete installation walkthrough, see [INSTALL.md](../INSTALL.md).

```bash
# Run installer from the source repository directory
sudo ./install.sh
```

The installer:
1. Copies executable to `/usr/sbin/tuxfrw-nft` (`0700`);
2. Installs configs and modules in `/etc/tuxfrw-nft/` (`0600`);
3. Deploys `/etc/systemd/system/tuxfrw-nft.service` and runs `systemctl daemon-reload`.

> [!IMPORTANT]
> **Security Notice**: By default, the service is **NOT** enabled at boot. Review your configurations, test manually with `tuxfrw-nft start`, verify SSH connectivity, and then enable automatic boot startup:
> ```bash
> sudo systemctl enable tuxfrw-nft
> ```

---

## 9. References and Credits

- **Author and Maintainer**: Marcelo Gondim <gondim@gmail.com>
- **Official Repository**: [https://github.com/gondimcodes/tuxfrw-nft](https://github.com/gondimcodes/tuxfrw-nft)
- **Official Netfilter / nftables Documentation**: [https://wiki.nftables.org/](https://wiki.nftables.org/)
- **License**: GNU General Public License v2 (GPLv2). See [LICENSE](../LICENSE).
