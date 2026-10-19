# ----------------------------------------------------------------------------
# TuxFrw-NFT 6.0.0
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
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
# SYNPROXY protection (if enabled in tuxfrw.conf)
# Protects designated public TCP ports against SYN flood attacks using kernel-level SYN cookies.
if [ "$SYNPROXY" = "1" -a "$SYNPROXY_PORTS" != "" ]; then
   $NFT 'add synproxy inet filter synproxy-v4 mss 1460 wscale 7 timestamp sack-perm'
   $NFT 'add synproxy inet filter synproxy-v6 mss 1440 wscale 7 timestamp sack-perm'
fi

# accept input packets from lo
$NFT 'add rule inet filter INPUT iifname "lo" counter accept'

$NFT 'add rule inet filter INPUT rt type 0 counter drop'

# accept input packets with allowed state
$NFT 'add rule inet filter INPUT ct state related,established counter accept'

$NFT 'add rule inet filter INPUT meta l4proto ipv6-icmp icmpv6 type echo-reply counter accept'

if [ "$SYNPROXY" = "1" -a "$SYNPROXY_PORTS" != "" ]; then
   $NFT "add rule inet filter INPUT meta nfproto ipv4 tcp dport { $SYNPROXY_PORTS } ct state invalid,untracked synproxy name \"synproxy-v4\" counter"
   $NFT "add rule inet filter INPUT meta nfproto ipv6 tcp dport { $SYNPROXY_PORTS } ct state invalid,untracked synproxy name \"synproxy-v6\" counter"
fi

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

# DHCPv6 (clients and servers)
$NFT 'add rule inet filter INPUT ip6 saddr fe80::/10 udp sport { 546, 547 } udp dport { 546, 547 } counter accept'

# DHCPv4 (clients and servers)
$NFT 'add rule inet filter INPUT udp sport { 67, 68 } udp dport { 67, 68 } counter accept'

# Local Network Discovery: mDNS (5353) and SSDP (1900) - restricted strictly to internal network
if [ "$INT_IFACE" != "" ]; then
   $NFT "add rule inet filter INPUT iifname $INT_IFACE ip6 daddr ff02::fb udp dport 5353 counter accept"
   $NFT "add rule inet filter INPUT iifname $INT_IFACE ip6 daddr { ff02::c, ff05::c } udp dport 1900 counter accept"
   $NFT "add rule inet filter INPUT iifname $INT_IFACE ip daddr 224.0.0.251 udp dport 5353 counter accept"
   $NFT "add rule inet filter INPUT iifname $INT_IFACE ip daddr 239.255.255.250 udp dport 1900 counter accept"
fi

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

# accept incoming VPN connections (OpenVPN, WireGuard, L2TP/IPsec)
if [ "$OpenVPN_PORT" != "" -a "$OpenVPN_IFACE" != "" ]; then
   local ovpn_proto="${OpenVPN_PROTO:-udp}"
   if [ "$OpenVPN_PEER_IP" != "" ]; then
      $NFT "add rule inet filter INPUT ip saddr $OpenVPN_PEER_IP $ovpn_proto dport $OpenVPN_PORT counter accept"
   else
      $NFT "add rule inet filter INPUT $ovpn_proto dport $OpenVPN_PORT counter accept"
   fi
   if [ "$OpenVPN_PEER_IP6" != "" ]; then
      $NFT "add rule inet filter INPUT ip6 saddr $OpenVPN_PEER_IP6 $ovpn_proto dport $OpenVPN_PORT counter accept"
   fi
fi

if [ "$WG_PORT" != "" -a "$WG_IFACE" != "" ]; then
   if [ "$WG_PEER_IP" != "" ]; then
      $NFT "add rule inet filter INPUT ip saddr $WG_PEER_IP udp dport $WG_PORT counter accept"
   else
      $NFT "add rule inet filter INPUT udp dport $WG_PORT counter accept"
   fi
   if [ "$WG_PEER_IP6" != "" ]; then
      $NFT "add rule inet filter INPUT ip6 saddr $WG_PEER_IP6 udp dport $WG_PORT counter accept"
   fi
fi

if [ "$L2TP_IFACE" != "" ]; then
   if [ "$L2TP_PEER_IP" != "" ]; then
      $NFT "add rule inet filter INPUT ip saddr $L2TP_PEER_IP udp dport { 500, 4500, 1701 } counter accept"
      $NFT "add rule inet filter INPUT ip saddr $L2TP_PEER_IP ip protocol esp counter accept"
   else
      $NFT "add rule inet filter INPUT udp dport { 500, 4500, 1701 } counter accept"
      $NFT "add rule inet filter INPUT ip protocol esp counter accept"
      $NFT "add rule inet filter INPUT meta l4proto esp counter accept"
   fi
   if [ "$L2TP_PEER_IP6" != "" ]; then
      $NFT "add rule inet filter INPUT ip6 saddr $L2TP_PEER_IP6 udp dport { 500, 4500, 1701 } counter accept"
      $NFT "add rule inet filter INPUT ip6 saddr $L2TP_PEER_IP6 meta l4proto esp counter accept"
   fi
fi
#==============================================================================
# Place your rules below
#==============================================================================

# Example of custom subnet blocking rules (using RFC 5737 documentation blocks):
#$NFT "add rule inet filter INPUT ip saddr { 198.51.100.0/24, 203.0.113.0/24 } tcp dport { 587, 465 } counter drop"

# Cloudflare reverse proxy only for Web (HTTP/HTTPS) example:
# Restricts incoming Web traffic on EXT_IFACE exclusively to official Cloudflare IP ranges.
# Run 'tuxfrw-nft cf-update' first to generate /etc/tuxfrw-nft/cloudflare.conf.
#if [ "$CF_IPV4" != "" -a "$EXT_IFACE" != "" ]; then
#   $NFT "add rule inet filter INPUT iif $EXT_IFACE ip saddr \$cf_ipv4 tcp dport { 80, 443 } counter accept"
#fi
#if [ "$CF_IPV6" != "" -a "$EXT_IFACE" != "" ]; then
#   $NFT "add rule inet filter INPUT iif $EXT_IFACE ip6 saddr \$cf_ipv6 tcp dport { 80, 443 } counter accept"
#fi
#==============================================================================
# reject all the unmatched packets. Insert your rules above this line.
#$NFT 'add rule inet filter INPUT limit rate 1/minute burst 5 packets counter log prefix "tuxfrw: INPUT! "'
