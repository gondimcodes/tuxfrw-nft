# Changelog

All notable changes to the **TuxFrw-NFT** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to semantic release versioning.

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
  - Converted documentation files to GitHub Flavored Markdown (`README.md`, `README.pt-br.md`, `INSTALL.md`, `INSTALL.pt-br.md`, `CHANGELOG.md`).
  - Renamed legacy `.Portuguese` documentation to standard `.pt-br.md`.
  - Rewrote technical reference manuals in `manual/` (`tuxfrw-manual-5.00-br.txt` and `tuxfrw-manual-5.00-en.txt`).

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
