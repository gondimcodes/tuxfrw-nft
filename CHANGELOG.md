# Changelog

All notable changes to the **TuxFrw-NFT** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to semantic release versioning.

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
