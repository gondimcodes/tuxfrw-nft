# ----------------------------------------------------------------------------
# TuxFrw-NFT 6.0.3
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
# ----------------------------------------------------------------------------
#
# tf_VPN-EXT.mod - TuxFrw VPN->EXT rules module
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
# VPN->EXT directional chain
#
# Controla conexoes originadas na VPN com destino a Internet (EXT).
# Utilizado no cenario de Full Tunneling (clientes navegando pela Internet do firewall).
# Nota: Para saida para a Internet, certifique-se de configurar o masquerade em tf_NAT-OUT.mod.

# Exemplo 1: Permitir navegacao Web (HTTP, HTTPS) e consultas DNS para clientes da VPN
#$NFT 'add rule inet filter VPN2EXT tcp dport { 80, 443 } counter accept'
#$NFT 'add rule inet filter VPN2EXT udp dport 53 counter accept'
#$NFT 'add rule inet filter VPN2EXT tcp dport 53 counter accept'
#$NFT 'add rule inet filter VPN2EXT icmp type echo-request counter accept'

# Exemplo 2: Permitir envio e recebimento de e-mails para clientes da VPN
#$NFT 'add rule inet filter VPN2EXT tcp dport { 587, 993, 995 } counter accept'

# Exemplo 3: Permitir saida irrestrita de qualquer trafego da VPN para a Internet
#$NFT 'add rule inet filter VPN2EXT counter accept'

# log and reject all the unmatched packets
#$NFT 'add rule inet filter VPN2EXT counter log prefix "tuxfrw: VPN->EXT! "'
