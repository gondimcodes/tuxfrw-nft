# ----------------------------------------------------------------------------
# TuxFrw-NFT 6.0.3
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
# ----------------------------------------------------------------------------
#
# tf_VPN-INT.mod - TuxFrw VPN->INT rules module
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
# VPN->INT directional chain
#
# Controla conexoes originadas nos tuneis de VPN com destino a rede local (INT).

# Exemplo 1: Permitir ping (ICMP Echo Request) para diagnostico na rede local
#$NFT 'add rule inet filter VPN2INT icmp type echo-request counter accept'
#$NFT 'add rule inet filter VPN2INT icmpv6 type echo-request counter accept'

# Exemplo 2: Permitir acesso a servicos de intranet e gerenciamento interno (SSH, HTTP, HTTPS, RDP, SMB)
#$NFT 'add rule inet filter VPN2INT tcp dport { 22, 80, 443, 445, 3389 } counter accept'

# Exemplo 3: Permitir acesso irrestrito para uma sub-rede administrativa da VPN (ex: 10.8.0.0/24)
#$NFT 'add rule inet filter VPN2INT ip saddr 10.8.0.0/24 counter accept'

# log and reject all the unmatched packets
#$NFT 'add rule inet filter VPN2INT counter log prefix "tuxfrw: VPN->INT! "'
