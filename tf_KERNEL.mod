# ----------------------------------------------------------------------------
# TuxFrw-NFT 6.0.2
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
# ----------------------------------------------------------------------------
#
# tf_KERNEL.mod - TuxFrw kernel configuration module
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

#
# Firewall modules autoloader
#
load_kernel_modules()
{
  MODPROBE=`type -p modprobe`

  $MODPROBE nf_conntrack_ftp
  $MODPROBE nf_nat_ftp

  if [ "$OpenVPN_IFACE" != "" ]; then
    $MODPROBE tun > /dev/null 2>&1 || true
  fi

  if [ "$WG_IFACE" != "" ]; then
    $MODPROBE wireguard > /dev/null 2>&1 || true
  fi

  if [ "$L2TP_IFACE" != "" ]; then
    $MODPROBE ppp_generic > /dev/null 2>&1 || true
    $MODPROBE l2tp_core > /dev/null 2>&1 || true
    $MODPROBE l2tp_netlink > /dev/null 2>&1 || true
    $MODPROBE l2tp_ppp > /dev/null 2>&1 || true
    $MODPROBE esp4 > /dev/null 2>&1 || true
    $MODPROBE esp6 > /dev/null 2>&1 || true
  fi
}

#
# sysctl kernel options - packet forwarding
#
set_sysctl()
{
  SYSCTL=`type -p sysctl`

  # Configure forwarding according to tuxfrw.conf
  if [ "$FORWARDING" -eq 1 ]; then
    $SYSCTL -w net.ipv4.conf.all.forwarding=1 > /dev/null 2>&1 || true
    $SYSCTL -w net.ipv6.conf.all.forwarding=1 > /dev/null 2>&1 || true
  else
    $SYSCTL -w net.ipv4.conf.all.forwarding=0 > /dev/null 2>&1 || true
    $SYSCTL -w net.ipv6.conf.all.forwarding=0 > /dev/null 2>&1 || true
  fi

  # Configure TCP SYNPROXY kernel options if enabled
  if [ "$SYNPROXY" = "1" ]; then
    $SYSCTL -w net.netfilter.nf_conntrack_tcp_loose=0 > /dev/null 2>&1 || true
    $SYSCTL -w net.ipv4.tcp_syncookies=1 > /dev/null 2>&1 || true
    $SYSCTL -w net.ipv4.tcp_timestamps=1 > /dev/null 2>&1 || true
  fi
}
