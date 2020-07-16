# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2019 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
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

# accept output packets with allowed state
$NFT 'add rule inet filter OUTPUT ct state established  counter accept'

# accept output packets from LO_IFACE
$NFT 'add rule inet filter OUTPUT oifname "lo" counter accept'

# accept link local address
$NFT 'add rule inet filter OUTPUT ip6 daddr fe80::/64 counter accept'

# accept unmatched OUTPUT packets
# - To enhance security, comment out this line after tests.
$NFT 'add rule inet filter OUTPUT counter accept'

# accept ICMP output packets (from the firewall to any other host)
# $NFT 'add rule inet filter OUTPUT ip protocol icmp counter accept'
# $NFT 'add rule inet filter OUTPUT meta l4proto ipv6-icmp counter accept'

#==============================================================================
# Place your rules below
#==============================================================================










#==============================================================================
# reject all the unmatched packets (won't work if output is totally accepted)
#$NFT 'add rule inet filter OUTPUT limit rate 1/minute burst 5 packets counter log prefix "tuxfrw: OUTPUT! "'
