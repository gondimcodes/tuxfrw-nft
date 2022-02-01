# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2022 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# tf_NAT-OUT.mod - TuxFrw NAT rules module
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
# create NAT_OUT rules
#

# Makes 1:1 NAT with public and private IP
$NFT "add rule ip nat POSTROUTING ip saddr $IP_DNS1 counter snat to $IP_DNS1_NAT"
$NFT "add rule ip nat POSTROUTING ip saddr $IP_DNS2 counter snat to $IP_DNS2_NAT"
$NFT "add rule ip nat POSTROUTING ip saddr $IP_WWW1 counter snat to $IP_WWW1_NAT"
$NFT "add rule ip nat POSTROUTING ip saddr $IP_SMTP counter snat to $IP_SMTP_NAT"

if [ "$DMZ_IFACE" != "" -a "$DMZ_NET" != "" -a "$DMZ_IP" != "" ]; then
  $NFT "add rule ip nat POSTROUTING oifname $DMZ_IFACE ip saddr $DMZ_NET ip daddr $DMZ_NET counter snat to $DMZ_IP"
fi
if [ "$INT_IFACE" != "" -a "$INT_NET" != "" -a "$INT_IP" != "" ]; then
  $NFT "add rule ip nat POSTROUTING oifname $INT_IFACE ip saddr $INT_NET ip daddr $INT_NET counter snat to $INT_IP"
fi
if [ "$EXT_IFACE" != "" ]; then
  $NFT "add rule ip nat POSTROUTING oifname $EXT_IFACE counter masquerade"
fi
