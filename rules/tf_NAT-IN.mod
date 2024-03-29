# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2022 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# tf_NAT-IN.mod - TuxFrw NAT rules module
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
# create NAT_IN rules
#

# Makes 1:1 NAT with public and private IP
# Don't forget to create eth0 aliases for the public IPs

# Rule for Transparent Proxy
if [ "$PROXY_PORT" != "" -a "$INT_IFACE" != "" -a "$PROXY_T" -eq 1 ]; then
   $NFT "add rule ip nat PREROUTING iifname $INT_IFACE tcp dport 80 counter redirect to :$PROXY_PORT"
   $NFT "add rule ip6 nat PREROUTING iifname $INT_IFACE tcp dport 80 counter redirect to :$PROXY_PORT"
fi

$NFT "add rule ip nat PREROUTING ip daddr $IP_DNS1_NAT counter dnat to $IP_DNS1"
$NFT "add rule ip nat PREROUTING ip daddr $IP_DNS2_NAT counter dnat to $IP_DNS2"
$NFT "add rule ip nat PREROUTING ip daddr $IP_WWW1_NAT counter dnat to $IP_WWW1"
$NFT "add rule ip nat PREROUTING ip daddr $IP_SMTP_NAT counter dnat to $IP_SMTP"
