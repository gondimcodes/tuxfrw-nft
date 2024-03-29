# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2022 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# tf_DMZ-EXT.mod - TuxFrw DMZ->EXT rules module
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
# DMZ->EXT directional chain
#

$NFT "add rule inet filter DMZ2EXT ip saddr $IP_DNS1 udp dport 53 counter accept" 
$NFT "add rule inet filter DMZ2EXT ip saddr $IP_DNS1 tcp dport 53 counter accept" 
$NFT "add rule inet filter DMZ2EXT ip6 saddr $IP6_DNS1 udp dport 53 counter accept" 
$NFT "add rule inet filter DMZ2EXT ip6 saddr $IP6_DNS1 tcp dport 53 counter accept" 
$NFT "add rule inet filter DMZ2EXT ip saddr $IP_DNS2 udp dport 53 counter accept" 
$NFT "add rule inet filter DMZ2EXT ip saddr $IP_DNS2 tcp dport 53 counter accept" 
$NFT "add rule inet filter DMZ2EXT ip6 saddr $IP6_DNS2 udp dport 53 counter accept" 
$NFT "add rule inet filter DMZ2EXT ip6 saddr $IP6_DNS2 tcp dport 53 counter accept" 
$NFT "add rule inet filter DMZ2EXT ip saddr $IP_SMTP tcp dport 25 counter accept" 
$NFT "add rule inet filter DMZ2EXT ip6 saddr $IP6_SMTP tcp dport 25 counter accept" 

# log and reject all the unmatched packets
#$NFT 'add rule inet filter DMZ2EXT counter log prefix "tuxfrw: DMZ->EXT! "'
