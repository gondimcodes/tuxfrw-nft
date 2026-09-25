#!/usr/bin/env bash
#
# ----------------------------------------------------------------------------
# TuxFrw-NFT 5.0
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
# ----------------------------------------------------------------------------
#
# install.sh - TuxFrw-NFT installation script
#
# ----------------------------------------------------------------------------
#
# This file is part of TuxFrw
#
# TuxFrw is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# ----------------------------------------------------------------------------

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SBIN_DIR="${SBIN_DIR:-/usr/sbin}"
CONF_DIR="${CONF_DIR:-/etc/tuxfrw-nft}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# UI Styling & Helpers
# -----------------------------------------------------------------------------
if [ -t 1 ]; then
  BOLD="\033[1m"
  CYAN="\033[1;36m"
  GREEN="\033[1;32m"
  YELLOW="\033[1;33m"
  RED="\033[1;31m"
  RESET="\033[0m"
else
  BOLD=""
  CYAN=""
  GREEN=""
  YELLOW=""
  RED=""
  RESET=""
fi

msg_info()  { echo -e "  [${CYAN}..${RESET}] $*"; }
msg_ok()    { echo -e "  [${GREEN}OK${RESET}] $*"; }
msg_warn()  { echo -e "  [${YELLOW}!!${RESET}] $*"; }
msg_err()   { echo -e "  [${RED}ERR${RESET}] $*" >&2; }

print_banner() {
  clear 2>/dev/null || true
  echo -e "${CYAN}================================================================================${RESET}"
  echo -e "${BOLD} TuxFrw-NFT 5.0 - Automated Firewall Setup${RESET}"
  echo -e " Copyright (C) 2001-2026 Marcelo Gondim (${CYAN}https://github.com/gondimcodes/tuxfrw-nft${RESET})"
  echo -e "${CYAN}================================================================================${RESET}"
  echo
}

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------
check_prerequisites() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    msg_err "This installer must be run as root (or with sudo)."
    exit 1
  fi

  msg_info "Checking dependencies..."
  if ! command -v nft >/dev/null 2>&1; then
    msg_err "'nft' (nftables) was not found in PATH."
    msg_err "Please install nftables package (e.g.: apt install nftables / dnf install nftables)."
    exit 1
  fi

  local nft_ver
  nft_ver="$(nft -v 2>/dev/null | head -n1 || echo 'nftables')"
  msg_ok "nftables found: ${BOLD}${nft_ver}${RESET}"

  if ! command -v install >/dev/null 2>&1; then
    msg_err "'install' command (coreutils) is required."
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Installation Steps
# -----------------------------------------------------------------------------
perform_install() {
  msg_info "Preparing destination directories..."
  install -d -m 755 "${SBIN_DIR}"
  install -d -m 700 "${CONF_DIR}"
  install -d -m 700 "${CONF_DIR}/rules"
  msg_ok "Directories initialized."

  msg_info "Installing core modules..."
  install -m 600 "${SCRIPT_DIR}/tf_BASE.mod" "${CONF_DIR}/"
  install -m 600 "${SCRIPT_DIR}/tf_KERNEL.mod" "${CONF_DIR}/"
  msg_ok "Base and Kernel modules installed in ${CONF_DIR}."

  msg_info "Installing directional rules..."
  local rule_count=0
  for mod in "${SCRIPT_DIR}/rules/"*.mod; do
    if [ -f "${mod}" ]; then
      install -m 600 "${mod}" "${CONF_DIR}/rules/"
      rule_count=$((rule_count + 1))
    fi
  done
  msg_ok "Installed ${rule_count} rule modules in ${CONF_DIR}/rules/."

  msg_info "Configuring main configuration file..."
  install -m 600 "${SCRIPT_DIR}/tuxfrw.conf" "${CONF_DIR}/tuxfrw.conf"
  msg_ok "Configuration installed: ${CONF_DIR}/tuxfrw.conf"

  msg_info "Installing main launcher executable..."
  install -m 700 "${SCRIPT_DIR}/tuxfrw-nft" "${SBIN_DIR}/tuxfrw-nft"
  msg_ok "Executable installed at: ${BOLD}${SBIN_DIR}/tuxfrw-nft${RESET}"

  if [ -d "${SYSTEMD_DIR}" ] && command -v systemctl >/dev/null 2>&1; then
    msg_info "Installing systemd unit service..."
    install -m 644 "${SCRIPT_DIR}/tuxfrw-nft.service" "${SYSTEMD_DIR}/tuxfrw-nft.service"
    systemctl daemon-reload >/dev/null 2>&1 || true
    msg_ok "Systemd service installed: ${BOLD}${SYSTEMD_DIR}/tuxfrw-nft.service${RESET}"
  fi

  # Verification
  msg_info "Verifying script syntax..."
  bash -n "${SBIN_DIR}/tuxfrw-nft"
  msg_ok "Integrity check passed."
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
print_banner
check_prerequisites

IS_UPGRADE=0
if [ -d "${CONF_DIR}" ] || [ -f "${SBIN_DIR}/tuxfrw-nft" ]; then
  IS_UPGRADE=1
fi

echo
echo -e " Target Executable : ${BOLD}${SBIN_DIR}/tuxfrw-nft${RESET}"
echo -e " Target Config Dir : ${BOLD}${CONF_DIR}${RESET}"
echo

if [ "${IS_UPGRADE}" -eq 1 ]; then
  msg_warn "${YELLOW}An existing TuxFrw-NFT installation was detected!${RESET}"
  msg_warn "Proceeding will ${BOLD}${RED}OVERWRITE ALL existing files and configuration${RESET} with the new version."
  echo
  read -r -p " Existing installation detected. Overwrite and replace ALL files? [y/N]: " CONFIRM_OVERWRITE
  case "${CONFIRM_OVERWRITE}" in
    [yY]|[yY][eE][sS])
      echo
      msg_info "Proceeding with full replacement..."
      ;;
    *)
      echo
      msg_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
else
  read -r -p " Press ENTER to proceed with installation (or Ctrl+C to cancel)... " _
fi
echo

perform_install

echo
echo -e "${GREEN}================================================================================${RESET}"
echo -e "${BOLD}${GREEN} TuxFrw-NFT installed successfully!${RESET}"
echo -e "${GREEN}================================================================================${RESET}"
echo
echo -e " Next steps:"
echo -e "   1. Review and adjust your rules and network settings FIRST:"
echo -e "      ${CYAN}nano ${CONF_DIR}/tuxfrw.conf${RESET}"
echo -e "      (and review modules under ${CYAN}${CONF_DIR}/rules/${RESET})"
echo
echo -e "   2. Start and test the firewall:"
echo -e "      ${CYAN}tuxfrw-nft start${RESET} (or ${CYAN}systemctl start tuxfrw-nft${RESET})"
echo
echo -e "   3. Check running ruleset:"
echo -e "      ${CYAN}tuxfrw-nft status${RESET}"
echo
echo -e "   ${YELLOW}NOTE: The systemd service is NOT enabled at boot by default.${RESET}"
echo -e "   After verifying and testing your rules, enable it at boot with:"
echo -e "      ${CYAN}systemctl enable tuxfrw-nft${RESET}"
echo

exit 0
