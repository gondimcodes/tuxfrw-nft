# ----------------------------------------------------------------------------
# TuxFrw-NFT 6.0.0
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
# ----------------------------------------------------------------------------
#
# tf_VPN-DMZ.mod - TuxFrw VPN->DMZ rules module
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
# VPN->DMZ directional chain
#
# Controla conexoes originadas na VPN com destino aos servidores da DMZ.

# Exemplo 1: Permitir ping (ICMP Echo Request) para diagnostico de servidores da DMZ
#$NFT 'add rule inet filter VPN2DMZ icmp type echo-request counter accept'
#$NFT 'add rule inet filter VPN2DMZ icmpv6 type echo-request counter accept'

# Exemplo 2: Permitir administracao remota de servidores da DMZ via VPN (SSH, HTTPS, RDP)
#$NFT 'add rule inet filter VPN2DMZ tcp dport { 22, 443, 3389 } counter accept'

# Exemplo 3: Permitir acesso a bancos de dados na DMZ apenas para hosts autorizados da VPN (MySQL, PostgreSQL)
#$NFT 'add rule inet filter VPN2DMZ tcp dport { 3306, 5432 } counter accept'

# log and reject all the unmatched packets
#$NFT 'add rule inet filter VPN2DMZ counter log prefix "tuxfrw: VPN->DMZ! "'
