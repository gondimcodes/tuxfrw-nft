# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2021 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# tf_INPUT.mod - TuxFrw main rules module
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
# INPUT chains
#

# accept input packets with allowed state
$NFT 'add rule inet filter INPUT ct state established  counter accept'

# accept input packets from lo
$NFT 'add rule inet filter INPUT iifname "lo" counter accept'

# drop new connection tcp that not flag syn
$NFT 'add rule inet filter INPUT tcp flags & (fin|syn|rst|ack) != syn ct state new counter drop'

# accept link local address and multicast
$NFT 'add rule inet filter INPUT ip6 daddr fe80::/64 counter accept'
$NFT 'add rule inet filter INPUT ip6 daddr ff00::/8 counter accept'

# accept SSH input from remote administrator IP
if [ "$RMT_ADMIN_IP" != "" ]; then
   $NFT "add rule inet filter INPUT ip saddr $RMT_ADMIN_IP tcp dport $SSH_PORT tcp flags & (fin|syn|rst|ack) == syn counter accept"
fi
if [ "$RMT_ADMIN_IP6" != "" ]; then
   $NFT "add rule inet filter INPUT ip6 saddr $RMT_ADMIN_IP6 tcp dport $SSH_PORT tcp flags & (fin|syn|rst|ack) == syn counter accept"
fi

# ICMP rule
$NFT 'add rule inet filter INPUT ip protocol icmp counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp counter accept'

# accept UNIX Traceroute Requests
# $NFT 'add rule inet filter INPUT udp dport 33434-33474 counter reject'

# Proxy access - authorization
if [ "$PROXY_PORT" != "" -a "$INT_IFACE" != "" ]; then
   $NFT "add rule inet filter INPUT iifname $INT_IFACE tcp dport $PROXY_PORT counter accept"
fi

# accept OpenVPN between this firewall and another
if [ "$OpenVPN_IP" != "" -a "$OpenVPN_PORT" != "" ]; then
   $NFT "add rule inet filter INPUT ip saddr $OpenVPN_IP tcp dport $OpenVPN_PORT counter accept"
fi
if [ "$OpenVPN_IP6" != "" -a "$OpenVPN_PORT" != "" ]; then
   $NFT "add rule inet filter INPUT ip6 saddr $OpenVPN_IP6 tcp dport $OpenVPN_PORT counter accept"
fi

# accept VPN between this firewall and another (using PPTP)
if [ "$PPTP_IP" != "" ]; then
   $NFT "add rule inet filter INPUT ip protocol gre ip saddr $PPTP_IP counter accept"
   $NFT "add rule inet filter INPUT ip saddr $PPTP_IP tcp dport 1723 counter accept"
fi
if [ "$PPTP_IP6" != "" ]; then
   $NFT "add rule inet filter INPUT meta l4proto gre ip6 saddr $PPTP_IP6 counter accept"
   $NFT "add rule inet filter INPUT ip6 saddr $PPTP_IP6 tcp dport 1723 counter accept"
fi
#==============================================================================
# Place your rules below
#==============================================================================









#==============================================================================
# reject all the unmatched packets. Insert your rules above this line.
#$NFT 'add rule inet filter INPUT limit rate 1/minute burst 5 packets counter log prefix "tuxfrw: INPUT! "'
