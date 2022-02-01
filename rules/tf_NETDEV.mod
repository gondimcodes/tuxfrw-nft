# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2022 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# tf_RAW.mod - TuxFrw RAW rules module
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

if [ "$EXT_IFACE" != "" ]; then
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|syn|rst|psh|ack|urg) == 0x0 counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|syn) == fin|syn counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (syn|rst) == syn|rst counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|rst) == fin|rst counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|ack) == fin counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (ack|urg) == urg counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|ack) == fin counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (psh|ack) == psh counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|syn|rst|psh|ack|urg) == fin|syn|rst|psh|ack|urg counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|syn|rst|psh|ack|urg) == 0x0 counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|syn|rst|psh|ack|urg) == fin|psh|urg counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|syn|rst|psh|ack|urg) == fin|syn|psh|urg counter drop"
   $NFT "add rule netdev filter $EXT_IFACE tcp flags & (fin|syn|rst|psh|ack|urg) == fin|syn|rst|ack|urg counter drop"

   # drop BOGONS
   $NFT "add rule netdev filter $EXT_IFACE ip saddr \$bogons_v4 counter drop"
   $NFT "add rule netdev filter $EXT_IFACE ip6 saddr \$bogons_v6 counter drop"

   # drop fragmentation
   #$NFT "add rule netdev filter $EXT_IFACE ip frag-off & 0x1fff != 0 counter drop"

   # SPOOF_CHECK packets
   if [ "$EXT_IP" != "" ]; then $NFT "add rule netdev filter $EXT_IFACE ip saddr $EXT_IP counter drop"; fi
   if [ "$EXT_IP6" != "" ]; then $NFT "add rule netdev filter $EXT_IFACE ip6 saddr $EXT_IP6 counter drop"; fi
   if [ "$EXT_BRO" != "" ]; then $NFT "add rule netdev filter $EXT_IFACE ip saddr $EXT_BRO counter drop"; fi
fi

if [ "$INT_IFACE" != "" ]; then
   if [ "$INT_IP" != "" ]; then $NFT "add rule netdev filter $INT_IFACE ip saddr $INT_IP counter drop"; fi
   if [ "$INT_IP6" != "" ]; then $NFT "add rule netdev filter $INT_IFACE ip6 saddr $INT_IP6 counter drop"; fi
   if [ "$INT_BRO" != "" ]; then $NFT "add rule netdev filter $INT_IFACE ip saddr $INT_BRO counter drop"; fi
fi

if [ "$DMZ_IFACE" != "" ]; then
   if [ "$DMZ_IP" != "" ]; then $NFT "add rule netdev filter $DMZ_IFACE ip saddr $DMZ_IP counter drop"; fi
   if [ "$DMZ_IP6" != "" ]; then $NFT "add rule netdev filter $DMZ_IFACE ip6 saddr $DMZ_IP6 counter drop"; fi
   if [ "$DMZ_BRO" != "" ]; then $NFT "add rule netdev filter $DMZ_IFACE ip saddr $DMZ_BRO counter drop"; fi
fi 
