# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2022 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
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
# SYNPROXY protection
# check mss and wscale with command: tcpdump -pni eth0 -c 1 'tcp[tcpflags] == (tcp-syn|tcp-ack)' and port 443
$NFT 'add synproxy inet filter https-synproxy mss 1460 wscale 12 timestamp sack-perm'

# accept input packets from lo
$NFT 'add rule inet filter INPUT iifname "lo" counter accept'

$NFT 'add rule inet filter INPUT rt type 0 counter drop'

# accept input packets with allowed state
$NFT 'add rule inet filter INPUT ct state related,established counter accept'

$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type echo-reply counter accept'

$NFT 'add rule inet filter INPUT ct state invalid,untracked synproxy name "https-synproxy" counter'

$NFT 'add rule inet filter INPUT ct state invalid counter drop'

# icmpv4 allow
$NFT 'add rule inet filter INPUT icmp type destination-unreachable counter accept'
$NFT 'add rule inet filter INPUT icmp type time-exceeded counter accept'
$NFT 'add rule inet filter INPUT icmp type parameter-problem counter accept'
$NFT 'add rule inet filter INPUT icmp type echo-request counter accept'

# icmpv6 allow
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type destination-unreachable counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type packet-too-big counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type time-exceeded counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type parameter-problem counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type echo-request counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type nd-router-solicit ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type nd-router-advert ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type nd-neighbor-solicit ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type nd-neighbor-advert ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type ind-neighbor-solicit ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type ind-neighbor-advert ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type mld-listener-query counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type mld-listener-report counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type mld-listener-done counter accept'
$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type mld2-listener-report counter accept'

# not implemented
#$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type 148 ip6 hoplimit 255 counter accept'
#$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type 149 ip6 hoplimit 255 counter accept'
#$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type 151 ip6 hoplimit 1 counter accept'
#$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type 152 ip6 hoplimit 1 counter accept'
#$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type 153 ip6 hoplimit 1 counter accept'
#$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type 144 counter accept'
#$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type 145 counter accept'
#$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type 146 counter accept'
#$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type 147 counter accept'

$NFT 'add rule inet filter INPUT ip6 saddr fe80::/10 ip6 daddr fe80::/10 udp sport 547 udp dport 546 counter accept'
$NFT 'add rule inet filter INPUT ip6 daddr ff02::fb udp dport 5353 counter accept'
$NFT 'add rule inet filter INPUT ip6 daddr ff02::f udp dport 1900 counter accept'

$NFT 'add rule inet filter INPUT udp sport 67 udp dport 68 counter accept'

$NFT 'add rule inet filter INPUT ip daddr 224.0.0.251 udp dport 5353 counter accept'

$NFT 'add rule inet filter INPUT ip daddr 239.255.255.250 udp dport 1900 counter accept'

# accept SSH input from remote administrator IP
if [ "$RMT_ADMIN_IP" != "" ]; then
   $NFT "add rule inet filter INPUT ip saddr $RMT_ADMIN_IP tcp dport $SSH_PORT tcp flags & (fin|syn|rst|ack) == syn counter accept"
fi
if [ "$RMT_ADMIN_IP6" != "" ]; then
   $NFT "add rule inet filter INPUT ip6 saddr $RMT_ADMIN_IP6 tcp dport $SSH_PORT tcp flags & (fin|syn|rst|ack) == syn counter accept"
fi

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

# SYNPROXY HTTPS protection example:
#$NFT "add rule inet filter https-synproxy tcp dport 443 tcp flags syn notrack counter"







#==============================================================================
# reject all the unmatched packets. Insert your rules above this line.
#$NFT 'add rule inet filter INPUT limit rate 1/minute burst 5 packets counter log prefix "tuxfrw: INPUT! "'
