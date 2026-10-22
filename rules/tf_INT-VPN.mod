# ----------------------------------------------------------------------------
# TuxFrw-NFT 6.0.3
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
# ----------------------------------------------------------------------------
#
# tf_INT-VPN.mod - TuxFrw INT->VPN rules module
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
# INT->VPN directional chain
#
# Controla conexoes originadas na rede local (INT) com destino a hosts nos tuneis de VPN.

# Exemplo 1: Permitir ping (ICMP Echo Request) da rede local para hosts na VPN
#$NFT 'add rule inet filter INT2VPN icmp type echo-request counter accept'
#$NFT 'add rule inet filter INT2VPN icmpv6 type echo-request counter accept'

# Exemplo 2: Permitir acesso a servicos em hosts ou filiais na VPN (SSH, RDP, HTTP, HTTPS)
#$NFT 'add rule inet filter INT2VPN tcp dport { 22, 80, 443, 3389 } counter accept'

# Exemplo 3: Permitir que toda a sub-rede interna acesse a rede VPN irrestritamente
#if [ "$INT_NET" != "" ]; then
#   $NFT "add rule inet filter INT2VPN ip saddr $INT_NET counter accept"
#fi

# log and reject all the unmatched packets
#$NFT 'add rule inet filter INT2VPN counter log prefix "tuxfrw: INT->VPN! "'
