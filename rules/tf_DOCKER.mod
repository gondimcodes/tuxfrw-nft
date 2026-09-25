# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2026 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# tf_DOCKER.mod - TuxFrw Docker container protection rules module
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
# FORWARD chain rules when DOCKER_SUPPORT="1"
# Priority -5 ensures these rules execute BEFORE Docker's standard forward chains (priority 0).
#

# 1. Allow state established/related
$NFT 'add rule inet filter FORWARD ct state related,established counter accept'

# 2. Allow ICMP essentiels for path MTU discovery and health checks
$NFT 'add rule inet filter FORWARD icmp type destination-unreachable counter accept'
$NFT 'add rule inet filter FORWARD icmp type time-exceeded counter accept'
$NFT 'add rule inet filter FORWARD icmp type parameter-problem counter accept'
$NFT 'add rule inet filter FORWARD icmp type echo-request counter accept'

$NFT 'add rule inet filter FORWARD meta l4proto ipv6-icmp icmpv6 type destination-unreachable counter accept'
$NFT 'add rule inet filter FORWARD meta l4proto ipv6-icmp icmpv6 type packet-too-big counter accept'
$NFT 'add rule inet filter FORWARD meta l4proto ipv6-icmp icmpv6 type time-exceeded counter accept'
$NFT 'add rule inet filter FORWARD meta l4proto ipv6-icmp icmpv6 type parameter-problem counter accept'
$NFT 'add rule inet filter FORWARD meta l4proto ipv6-icmp icmpv6 type echo-request counter accept'

# 3. Allow containers outbound traffic (from docker interfaces to internet / external interface)
#    Containers need to reach external networks, repositories, APIs, DNS, etc.
$NFT 'add rule inet filter FORWARD iifname "docker0" counter accept'
$NFT 'add rule inet filter FORWARD iifname "br-*" counter accept'

# 4. Allow traffic between containers within docker networks
$NFT 'add rule inet filter FORWARD iifname "docker0" oifname "docker0" counter accept'
$NFT 'add rule inet filter FORWARD iifname "br-*" oifname "br-*" counter accept'

#==============================================================================
# Container Inbound Access Control (FORWARD to containers)
# Place your specific container allow/deny rules below!
#
# In Docker, inbound traffic to published ports (-p HOST_PORT:CONTAINER_PORT)
# goes through the FORWARD chain after PREROUTING DNAT.
#
# Examples:
#
# Allow Akvorado web UI (e.g. port 3000) ONLY from trusted management IP or subnet:
# $NFT 'add rule inet filter FORWARD ip saddr 203.0.113.50 tcp dport 3000 counter accept'
# $NFT 'add rule inet filter FORWARD tcp dport 3000 counter drop'
#
# Allow HTTP/HTTPS public container:
# $NFT 'add rule inet filter FORWARD tcp dport { 80, 443 } counter accept'
#
# Allow a database container (e.g. PostgreSQL 5432) only from application server:
# $NFT 'add rule inet filter FORWARD ip saddr 192.168.1.10 tcp dport 5432 counter accept'
# $NFT 'add rule inet filter FORWARD tcp dport 5432 counter drop'
#==============================================================================

#==============================================================================
# reject all the unmatched packets. Insert your rules above this line.
#$NFT 'add rule inet filter FORWARD limit rate 1/minute burst 5 packets counter log prefix "tuxfrw: DOCKER! "'
