# ----------------------------------------------------------------------------
# TuxFrw-NFT 6.0.0
# Copyright (C) 2001-2026 Marcelo Gondim (https://github.com/gondimcodes/tuxfrw-nft)
# ----------------------------------------------------------------------------
#
# tf_NAT-IN.mod - TuxFrw NAT rules module
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
# PREROUTING chain (DNAT / Port Forwarding)
# ----------------------------------------------------------------------------

#==============================================================================
# 1:1 NAT Examples (DNAT - Inbound)
# Uncomment and configure if you have public IP aliases dedicated to DMZ servers:
#==============================================================================
#if [ "$IP_DNS1_NAT" != "" -a "$IP_DNS1" != "" ]; then
#   $NFT "add rule ip nat PREROUTING ip daddr $IP_DNS1_NAT counter dnat to $IP_DNS1"
#fi
#if [ "$IP_DNS2_NAT" != "" -a "$IP_DNS2" != "" ]; then
#   $NFT "add rule ip nat PREROUTING ip daddr $IP_DNS2_NAT counter dnat to $IP_DNS2"
#fi
#if [ "$IP_WWW1_NAT" != "" -a "$IP_WWW1" != "" ]; then
#   $NFT "add rule ip nat PREROUTING ip daddr $IP_WWW1_NAT counter dnat to $IP_WWW1"
#fi
#if [ "$IP_SMTP_NAT" != "" -a "$IP_SMTP" != "" ]; then
#   $NFT "add rule ip nat PREROUTING ip daddr $IP_SMTP_NAT counter dnat to $IP_SMTP"
#fi
