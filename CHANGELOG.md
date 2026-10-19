# Changelog

All notable changes to the **TuxFrw-NFT** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to semantic release versioning.

## [6.0.0] - 2026-10-19

### Added
- **Modular TCP SYNPROXY (Anti-SYN Flood DDoS Mitigation)**:
  - Implemented modular TCP SYNPROXY architecture controlled via `SYNPROXY` and `SYNPROXY_PORTS` in `tuxfrw.conf`.
  - Added `synproxy-prerouting` chain at raw priority in `tf_BASE.mod` marking incoming SYNs on protected ports as `notrack` to bypass premature conntrack session allocation.
  - Implemented Dual-Stack SYNPROXY objects (`synproxy-v4` MSS 1460, WScale 7; `synproxy-v6` MSS 1440, WScale 7) in `rules/tf_INPUT.mod` with RFC 4987 cryptographic cookie verification.
  - Automated kernel sysctl parameter tuning in `tf_KERNEL.mod` (`nf_conntrack_tcp_loose=0`, `tcp_syncookies=1`, `tcp_timestamps=1`) upon enabling SYNPROXY.
  - Added atomic CLI reloading command: `tuxfrw-nft load SYNPROXY`.
- **Modern Directional VPN Matrix (OpenVPN, WireGuard, L2TP/IPsec)**:
  - Added full native support in `tuxfrw.conf` for OpenVPN (`OpenVPN_IFACE`, `OpenVPN_PORT`, `OpenVPN_PROTO`, `OpenVPN_PEER_IP/6`), WireGuard (`WG_IFACE`, `WG_PORT`, `WG_PEER_IP/6`), and L2TP/IPsec (`L2TP_IFACE`, `L2TP_PEER_IP/6`, UDP 500, 4500, 1701 and ESP protocol 50 Dual-Stack).
  - Dynamic DRY forwarding attachment loop in `rules/tf_FORWARD.mod` interconnecting active VPN interfaces with `INT`, `EXT`, and `DMZ` directional chains (`VPN2INT`, `VPN2EXT`, `VPN2DMZ`, `INT2VPN`, `EXT2VPN`, `DMZ2VPN`).
  - Added dynamic kernel module autoloader in `tf_KERNEL.mod` loading necessary drivers on demand (`wireguard`, `tun`, `ppp_generic`, `l2tp_core`, `esp4`, `esp6`).
- **RFC 8201 ICMPv6 PMTUD in Forwarding Path**:
  - Added full transit forwarding for essential ICMPv6 types in `rules/tf_FORWARD.mod` (`packet-too-big`, `destination-unreachable`, `time-exceeded`, `parameter-problem`, `echo-request`), preventing IPv6 Black Hole MTU negotiation failures.
- **Directional VPN Rule Templates & INT2EXT Port Modernization**:
  - Added structured, commented-by-default rule templates across all 6 directional VPN modules (`tf_VPN-INT`, `tf_INT-VPN`, `tf_VPN-EXT`, `tf_EXT-VPN`, `tf_VPN-DMZ`, `tf_DMZ-VPN`).
  - Updated `rules/tf_INT-EXT.mod` default outbound TCP ports to modern mail and web standards (`80, 443, 587, 995, 993, 21, 143, 110, 53`).

### Changed
- **Semantic Versioning Transition**:
  - Migrated project versioning scheme to 3-digit Semantic Versioning (`MAJOR.MINOR.PATCH`).
- **Security by Default in DMZ and NAT**:
  - Converted placeholder server IP variables (`IP_DNS*`, `IP_WWW*`, `IP_SMTP*`, `IP6_*`) and 1:1 NAT mapping rules in `tuxfrw.conf` and `rules/tf_*.mod` to commented documentation examples with `if [ "$VAR" != "" ]` guards, preventing accidental exposure of ports to unconfigured IPs on clean setups.
- **LAN Discovery Protocol Hardening**:
  - Restricted mDNS (UDP 5353) and SSDP (UDP 1900) services in `rules/tf_INPUT.mod` strictly to the internal LAN interface (`iifname $INT_IFACE`).

### Removed
- **Abolished PPTP Protocol**:
  - Permanently removed support for legacy and vulnerable PPTP VPN (TCP port 1723 / GRE protocol 47) from `tuxfrw.conf`, `tf_KERNEL.mod`, `tf_BASE.mod`, `rules/tf_INPUT.mod`, and `rules/tf_FORWARD.mod`.
- **Abolished Legacy Transparent Proxy (Squid/Lusca)**:
  - Removed obsolete transparent HTTP proxy redirection and authorization parameters (`PROXY_PORT` and `PROXY_T`) from `tuxfrw.conf`, `rules/tf_NAT-IN.mod`, and `rules/tf_INPUT.mod`.

### Fixed
- Fixed chain name typo in `rules/tf_DMZ-VPN.mod` (corrected from non-existent `DMZ-VPN` to `DMZ2VPN`).
- Fixed table family declarations in `rules/tf_VPN-INT.mod`, `rules/tf_VPN-EXT.mod`, and `rules/tf_VPN-DMZ.mod` (corrected from `ip filter` to `inet filter`).
- Removed duplicate rules for NULL scan and FIN-without-ACK in `rules/tf_NETDEV.mod`.

---

## [5.3] - 2026-10-12

### Added
- **Fail2ban & Third-Party Daemon Zero-Touch Coexistence**:
  - Abolished global `flush ruleset` across all operational modes in `tf_BASE.mod:clear_rules()`, shifting to strict, surgical table-level deletion (`inet filter`, `netdev filter`, `inet mangle`, `ip nat`, `ip6 nat`).
  - Completely preserves foreign Netfilter namespaces in kernel memory, ensuring Fail2ban (`table inet f2b-table` or `table ip filter`), Docker bridges, WireGuard, and Tailscale rulesets remain 100% intact across `tuxfrw-nft start`, `stop`, `restart`, and `load` commands.
  - Aligned systemd boot ordering in `tuxfrw-nft.service` via `Before=network-pre.target shutdown.target fail2ban.service` to establish base packet filtering before Fail2ban jail initialisation.
  - Documented hook priority chaining in the technical manuals: Fail2ban blocks banned IPs at `priority -1` on the outer edge before TuxFrw rules execute at `priority 0`.

---

## [5.2] - 2026-10-06

### Added
- **Cloudflare Reverse Proxy Shielding (`cf-update`)**:
  - Added CLI command `tuxfrw-nft cf-update` to automatically fetch, validate, and format official Cloudflare IPv4 and IPv6 proxy CIDR blocks via HTTPS with strict regex sanitization against injection or corrupted feeds.
  - Implemented satellite file architecture `/etc/tuxfrw-nft/cloudflare.conf` (`0600`) isolating dynamic CDN IP feeds from static host networking configs.
  - Integrated `CF_IPV4` and `CF_IPV6` variables into `tf_BASE.mod` defines (`$cf_ipv4` and `$cf_ipv6`) with ready-to-use rule templates in `rules/tf_INPUT.mod`, `rules/tf_DOCKER.mod`, and `rules/tf_EXT-DMZ.mod` to shield web origin servers and containers from direct IP bypass.

---

## [5.1] - 2026-09-28

### Added
- **Native uRPF and Complete Anti-Spoofing Architecture (FIB & BCP 38)**:
  - Added native Strict uRPF lookup (`fib saddr . iif oif missing counter drop`) in `PREROUTING` for both IPv4 and IPv6 across all active physical interfaces (`EXT`, `INT`, `DMZ`).
  - Added IPv6 DAD and SLAAC link-local exemption (`ip6 saddr :: ip6 daddr ff02::/16 accept`) preventing initialization drops.
  - Added atomic reloading command: `tuxfrw-nft load URPF`.
  - Added Egress Anti-Spoofing (BCP 38 / RFC 2827) in `rules/tf_INT-EXT.mod` and `rules/tf_DMZ-EXT.mod` dropping forged source packets leaving local subnets.
  - Added strict isolation in `rules/tf_EXT-INT.mod` dropping unsolicited inbound connections (`ct state new`) from the Internet into the LAN.
  - Added DDoS reflection and amplification mitigation in `rules/tf_EXT-DMZ.mod` blocking high-risk UDP abuse ports (NTP 123, Memcached 11211, SSDP 1900, SNMP 161/162, CLDAP 389, WS-Discovery 3702, mDNS 5353, Chargen 19, QOTD 17) and applying rate-limiting to public DNS resolvers.

### Fixed
- Fixed missing stderr redirection in `setup_urpf` calls in `tf_BASE.mod` and hardened `evaluate_retval` in `tuxfrw-nft` to prevent spurious `cat`/`rm` error messages when `/tmp/tf_error` is absent.

---

## [5.0] - 2026-09-28

### Added
- **Native Docker Compatibility Mode (`DOCKER_SUPPORT="1"`)**:
  - Added dedicated module `rules/tf_DOCKER.mod` for fine-grained container traffic control on the `FORWARD` hook using high priority (`priority -5`).
  - Added atomic reloading command: `tuxfrw-nft load DOCKER`.
  - Added non-destructive table teardown: `clear_rules()` cleans only TuxFrw tables (`inet filter`, `netdev filter`, `inet mangle`), preventing destruction of Docker daemon chains, virtual bridges (`docker0`, `br-*`), and container NAT.
- **Dedicated Systemd Service**:
  - Added `tuxfrw-nft.service` unit (`Type=oneshot`, `RemainAfterExit=yes`, `Before=network-pre.target`).
- **Modern Markdown Documentation**:
  - Converted documentation files to GitHub Flavored Markdown (`README.md`, `README.pt-br.md`, `INSTALL.md`, `INSTALL.pt-br.md`, `CHANGELOG.md`, `CREDITS.md`).
  - Renamed legacy `.Portuguese` documentation to standard `.pt-br.md`.
  - Rewrote technical reference manuals in `manual/` (`tuxfrw-manual-5.1-pt-br.md` and `tuxfrw-manual-5.1-en.md`).

### Changed
- **Installer Modernization**:
  - Overhauled `install.sh` with system checks, clean terminal UI styling, and detection of existing installations with explicit overwrite confirmation prompts (`[y/N]`).
  - Deliberately omitted automatic `systemctl enable` at boot during installation to prevent accidental remote lockouts prior to rule review.
- **Kernel Tuning Hygiene**:
  - Removed aggressive and invasive TCP/VM `sysctl` modifications in `tf_KERNEL.mod`, preserving strictly `forwarding` state control.
- **BOGON Decoupling**:
  - Added `BOGONS` toggle in `tuxfrw.conf` (default `"0"` / disabled) and decoupled RFC 1918 private subnets (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) from the default filter to prevent dropping internal corporate and DNS traffic at the `netdev` ingress hook.

### Fixed
- Fixed port configuration bug in `rules/tf_INT-DMZ.mod` (`WWW6` ports corrected to `{ 80, 443 }`).
- Fixed DHCPv4 ports (`udp { 67, 68 }`) and DHCPv6 ports (`udp { 546, 547 }`) in `rules/tf_INPUT.mod`.
- Fixed IPv6 SSDP multicast groups in `rules/tf_INPUT.mod` (`{ ff02::c, ff05::c }`).
- Fixed missing essential outbound ICMPv4 rules in `rules/tf_OUTPUT.mod`.
- Fixed table leak where `table netdev filter` persisted in memory after `tuxfrw-nft stop` when in Docker mode.

---

## [1.0] - 2022-02-13

### Added
- Initial port and full support for the Linux Netfilter **nftables** (`nft`) subsystem.
- Dynamic atomic batch ruleset compilation (`nft -f`).
- Dual-Stack IPv4 and IPv6 packet filtering under unified `inet filter` tables.
- Modular directional architecture (`tf_INPUT`, `tf_OUTPUT`, `tf_FORWARD`, `tf_NETDEV`, `tf_NAT-IN`, `tf_NAT-OUT`).
- Ingress raw packet filtering via `netdev` tables for early TCP flag anomaly mitigation and anti-spoofing.
