# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2022 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# tf_OUTPUT.mod - TuxFrw main rules module
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
# OUTPUT chain
#
# accept output packets from LO_IFACE
$NFT 'add rule inet filter OUTPUT oifname "lo" counter accept'

$NFT 'add rule inet filter OUTPUT rt type 0 counter drop'

# accept output packets with allowed state
$NFT 'add rule inet filter OUTPUT ct state related,established counter accept'  

# icmpv6 allow
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type destination-unreachable counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type packet-too-big counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type time-exceeded counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type parameter-problem counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type echo-request counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type echo-reply counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type nd-router-solicit ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type nd-router-advert ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type nd-neighbor-solicit ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type nd-neighbor-advert ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type ind-neighbor-solicit ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type ind-neighbor-advert ip6 hoplimit 255 counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type mld-listener-query counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type mld-listener-report counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type mld-listener-done counter accept'
$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type mld2-listener-report counter accept'

# not implemented
#$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type 148 ip6 hoplimit 255 counter accept'
#$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp icmpv6 type 149 ip6 hoplimit 255 counter accept'
#$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type 151 ip6 hoplimit 1 counter accept'
#$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type 152 ip6 hoplimit 1 counter accept'
#$NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp ip6 saddr fe80::/10 icmpv6 type 153 ip6 hoplimit 1 counter accept'

# accept unmatched OUTPUT packets
# - To enhance security, comment out this line after tests.
$NFT 'add rule inet filter OUTPUT counter accept'

#==============================================================================
# Place your rules below
#==============================================================================










#==============================================================================
# reject all the unmatched packets (won't work if output is totally accepted)
#$NFT 'add rule inet filter OUTPUT limit rate 1/minute burst 5 packets counter log prefix "tuxfrw: OUTPUT! "'
