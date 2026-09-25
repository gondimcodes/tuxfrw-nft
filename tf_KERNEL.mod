# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2022 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
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

  if [ "$PPTP_IFACE" != "" ]; then
    $MODPROBE nf_conntrack_pptp
    $MODPROBE nf_nat_pptp
    $MODPROBE ip_gre
    $MODPROBE ip6_gre
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
}
