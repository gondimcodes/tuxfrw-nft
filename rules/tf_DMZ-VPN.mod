# ----------------------------------------------------------------------------
# TuxFrw-NFT 6.0.0
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
# ----------------------------------------------------------------------------
#
# tf_DMZ-VPN.mod - TuxFrw DMZ->VPN rules module
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
# DMZ->VPN directional chain
#
# Controla conexoes originadas na DMZ com destino a hosts na VPN.
# ATENCAO: A DMZ e uma zona exposta a Internet. Conexoes iniciadas a partir da DMZ
# em direcao a VPN devem ser estritamente restritas.

# Exemplo 1: Permitir que um servidor da DMZ envie backups para um storage na VPN (ex: 10.8.0.100:22)
#$NFT 'add rule inet filter DMZ2VPN ip daddr 10.8.0.100 tcp dport 22 counter accept'

# Exemplo 2: Permitir envio de logs (Syslog UDP 514) da DMZ para servidor coletor na VPN
#$NFT 'add rule inet filter DMZ2VPN ip daddr 10.8.0.100 udp dport 514 counter accept'

# Exemplo 3: Permitir integracao de monitoramento passivo (Zabbix/Prometheus exporter -> Server na VPN)
#$NFT 'add rule inet filter DMZ2VPN ip daddr 10.8.0.100 tcp dport 10051 counter accept'

# log and reject all the unmatched packets
#$NFT 'add rule inet filter DMZ2VPN counter log prefix "tuxfrw: DMZ->VPN! "'
