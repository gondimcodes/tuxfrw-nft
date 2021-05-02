# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2021 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# tf_FORWARD.mod - TuxFrw main rules module
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
# FORWARD chain
#

# accept forward packets with allowed state
$NFT 'add rule inet filter FORWARD ct state established  counter accept'

# ICMP rules
$NFT 'add rule inet filter FORWARD ip protocol icmp counter accept'
$NFT 'add rule inet filter FORWARD meta l4proto ipv6-icmp counter accept'

# accept the forwardings of the nets
if [ "$DMZ_IFACE" != "" ]; then $NFT "add rule inet filter FORWARD iifname $DMZ_IFACE oifname $DMZ_IFACE counter accept"; fi
if [ "$INT_IFACE" != "" ]; then $NFT "add rule inet filter FORWARD iifname $INT_IFACE oifname $INT_IFACE counter accept"; fi
if [ "$EXT_IFACE" != "" ]; then $NFT "add rule inet filter FORWARD iifname $EXT_IFACE oifname $EXT_IFACE counter accept"; fi

# "link" the available networks together
if [ "$INT_IFACE" != "" -a "$DMZ_IFACE" != "" ]; then
  $NFT "add rule inet filter FORWARD iifname $INT_IFACE oifname $DMZ_IFACE counter jump INT2DMZ" 
  $NFT "add rule inet filter FORWARD iifname $DMZ_IFACE oifname $INT_IFACE counter jump DMZ2INT" 
fi
if [ "$INT_IFACE" != "" -a "$EXT_IFACE" != "" ]; then
  $NFT "add rule inet filter FORWARD iifname $INT_IFACE oifname $EXT_IFACE counter jump INT2EXT"
  $NFT "add rule inet filter FORWARD iifname $EXT_IFACE oifname $INT_IFACE counter jump EXT2INT"
fi
if [ "$DMZ_IFACE" != "" -a "$EXT_IFACE" != "" ]; then
  $NFT "add rule inet filter FORWARD iifname $DMZ_IFACE oifname $EXT_IFACE counter jump DMZ2EXT" 
  $NFT "add rule inet filter FORWARD iifname $EXT_IFACE oifname $DMZ_IFACE counter jump EXT2DMZ" 
fi
if [ "$INT_IFACE" != "" -a "$PPTP_IFACE" != "" ]; then
  $NFT "add rule inet filter FORWARD iifname $INT_IFACE oifname $PPTP_IFACE counter jump INT2VPN" 
  $NFT "add rule inet filter FORWARD iifname $PPTP_IFACE oifname $INT_IFACE counter jump VPN2INT" 
fi
if [ "$EXT_IFACE" != "" -a "$PPTP_IFACE" != "" ]; then
  $NFT "add rule inet filter FORWARD iifname $EXT_IFACE oifname $PPTP_IFACE counter jump EXT2VPN" 
  $NFT "add rule inet filter FORWARD iifname $PPTP_IFACE oifname $EXT_IFACE counter jump VPN2EXT" 
fi
if [ "$DMZ_IFACE" != "" -a "$PPTP_IFACE" != "" ]; then
  $NFT "add rule inet filter FORWARD iifname $DMZ_IFACE oifname $PPTP_IFACE counter jump DMZ2VPN" 
  $NFT "add rule inet filter FORWARD iifname $PPTP_IFACE oifname $DMZ_IFACE counter jump VPN2DMZ" 
fi
if [ "$INT_IFACE" != "" -a "$OpenVPN_IFACE" != "" ]; then
  $NFT "add rule inet filter FORWARD iifname $INT_IFACE oifname $OpenVPN_IFACE counter jump INT2VPN" 
  $NFT "add rule inet filter FORWARD iifname $OpenVPN_IFACE oifname $INT_IFACE counter jump VPN2INT" 
fi
if [ "$EXT_IFACE" != "" -a "$OpenVPN_IFACE" != "" ]; then
  $NFT "add rule inet filter FORWARD iifname $EXT_IFACE oifname $OpenVPN_IFACE counter jump EXT2VPN" 
  $NFT "add rule inet filter FORWARD iifname $OpenVPN_IFACE oifname $EXT_IFACE counter jump VPN2EXT" 
fi
if [ "$DMZ_IFACE" != "" -a "$OpenVPN_IFACE" != "" ]; then
  $NFT "add rule inet filter FORWARD iifname $DMZ_IFACE oifname $OpenVPN_IFACE counter jump DMZ2VPN" 
  $NFT "add rule inet filter FORWARD iifname $OpenVPN_IFACE oifname $DMZ_IFACE counter jump VPN2DMZ" 
fi

