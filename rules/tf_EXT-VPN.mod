# ----------------------------------------------------------------------------
# TuxFrw-NFT 6.0.0
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
# ----------------------------------------------------------------------------
#
# tf_EXT-VPN.mod - TuxFrw EXT->VPN rules module
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
# EXT->VPN directional chain
#
# Controla conexoes originadas na Internet (EXT) com destino a hosts na VPN.
# ATENCAO: Por seguranca, conexoes novas nao solicitadas vindas da Internet
# para a rede interna da VPN devem ser bloqueadas por padrao.

# Protecao preventiva: descarta pacotes invalidos
$NFT 'add rule inet filter EXT2VPN ct state invalid counter drop'

# Exemplo 1: Permitir acesso a um servico em host da VPN atraves de Port Forwarding / DNAT
# (Exemplo: servidor web ou aplicacao na VPN recebendo conexoes encaminhadas via tf_NAT-IN.mod)
#$NFT 'add rule inet filter EXT2VPN ip daddr 10.8.0.50 tcp dport 80 counter accept'

# log and reject all the unmatched packets
#$NFT 'add rule inet filter EXT2VPN counter log prefix "tuxfrw: EXT->VPN! "'
