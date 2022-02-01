# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2022 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# tf_BASE.mod - TuxFrw base functions module
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
# Flush, delete and zero all chains
#
clear_rules()
{
  echo '#!/usr/sbin/nft -f' > $CONF_DIR/tuxfrw.nft
  echo 'flush ruleset' >> $CONF_DIR/tuxfrw.nft
}

defines()
{
  echo 'define bogons_v4 = { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 192.168.0.0/16, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4, 255.255.255.255/32 }' >> $CONF_DIR/tuxfrw.nft
  echo 'define bogons_v6 = { 0100::/64, 2001:2::/48, 2001:10::/28, 2001:db8::/32, 3ffe::/16, fc00::/7, fec0::/10, ff00::/8 }' >> $CONF_DIR/tuxfrw.nft
}

run_nft()
{
  chmod 700 $CONF_DIR/tuxfrw.nft
  $CONF_DIR/tuxfrw.nft 2> /tmp/tf_error
  echo -n "Running rules in memory: "
  evaluate_retval
}

run_natopen()
{
  # setup NAT
  if   [ "$NAT" -eq 1 ]; then
    $NFT 'add table ip nat' >> $CONF_DIR/tuxfrw.nft 
    $NFT 'add table ip6 nat' >> $CONF_DIR/tuxfrw.nft 
    $NFT 'add chain ip nat POSTROUTING { type nat hook postrouting priority 100; policy accept; }' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add chain ip6 nat POSTROUTING { type nat hook postrouting priority 100; policy accept; }' >> $CONF_DIR/tuxfrw.nft
    . $CONF_DIR/rules/tf_NAT-OUT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading NAT-OUT" 
    evaluate_retval
  elif [ "$NAT" -eq 2 ]; then
    $NFT 'add table ip nat' >> $CONF_DIR/tuxfrw.nft 
    $NFT 'add table ip6 nat' >> $CONF_DIR/tuxfrw.nft 
    $NFT 'add chain ip nat POSTROUTING { type nat hook postrouting priority 100; policy accept; }' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add chain ip6 nat POSTROUTING { type nat hook postrouting priority 100; policy accept; }' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add chain ip nat PREROUTING { type nat hook prerouting priority -100; policy accept; }' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add chain ip6 nat PREROUTING { type nat hook prerouting priority -100; policy accept; }' >> $CONF_DIR/tuxfrw.nft
    . $CONF_DIR/rules/tf_NAT-IN.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading NAT-IN" 
    evaluate_retval
    . $CONF_DIR/rules/tf_NAT-OUT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading NAT-OUT" 
    evaluate_retval
  elif [ "$NAT" -eq 3 ]; then
    $NFT 'add table ip nat' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add table ip6 nat' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add chain ip nat PREROUTING { type nat hook prerouting priority -100; policy accept; }' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add chain ip6 nat PREROUTING { type nat hook prerouting priority -100; policy accept; }' >> $CONF_DIR/tuxfrw.nft
    . $CONF_DIR/rules/tf_NAT-IN.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading NAT-IN" 
    evaluate_retval
  fi
}

#
# Create and load the rules and chains
#
create_rules()
{

  # load kernel modules
  if [ "$KERN_MOD" != "0" ]; then
    load_kernel_modules
  fi

  # set /proc options
  set_sysctl

  # setup netdev
  if [ "$EXT_IFACE" != "" -o "$DMZ_IFACE" != "" -o "$INT_IFACE" != "" ]; then
     $NFT 'add table netdev filter' >> $CONF_DIR/tuxfrw.nft
  fi
  if [ "$EXT_IFACE" != "" ]; then
     $NFT "add chain netdev filter $EXT_IFACE { type filter hook ingress device $EXT_IFACE priority 0; policy accept; }" >> $CONF_DIR/tuxfrw.nft
  fi
  if [ "$INT_IFACE" != "" ]; then
     $NFT "add chain netdev filter $INT_IFACE { type filter hook ingress device $INT_IFACE priority 0; policy accept; }" >> $CONF_DIR/tuxfrw.nft
  fi
  if [ "$DMZ_IFACE" != "" ]; then
     $NFT "add chain netdev filter $DMZ_IFACE { type filter hook ingress device $DMZ_IFACE priority 0; policy accept; }" >> $CONF_DIR/tuxfrw.nft
  fi
  . $CONF_DIR/rules/tf_NETDEV.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
  echo -n "Loading NETDEV"
  evaluate_retval
  
# setup mangle
  if [ "$MANGLE" == "1" ]; then
     $NFT 'add table inet mangle' >> $CONF_DIR/tuxfrw.nft
     $NFT 'add chain inet mangle FORWARD { type filter hook forward priority -150; policy accept; }' >> $CONF_DIR/tuxfrw.nft
     . $CONF_DIR/rules/tf_MANGLE.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
     echo -n "Loading MANGLE"
     evaluate_retval
  fi

  # setup NAT
  run_natopen

  # base I/O rules
  $NFT 'add table inet filter' >> $CONF_DIR/tuxfrw.nft
  $NFT 'add chain inet filter INPUT { type filter hook input priority 0; policy drop; }' >> $CONF_DIR/tuxfrw.nft
  . $CONF_DIR/rules/tf_INPUT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
  echo -n "Loading INPUT" 
  evaluate_retval
  $NFT 'add chain inet filter OUTPUT { type filter hook output priority 0; policy drop; }' >> $CONF_DIR/tuxfrw.nft
  . $CONF_DIR/rules/tf_OUTPUT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
  echo -n "Loading OUTPUT"
  evaluate_retval

  # INT<->DMZ rules
  if [ "$INT_IFACE" != "" -a "$DMZ_IFACE" != "" ]; then
    $NFT 'add chain inet filter INT2DMZ' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add chain inet filter DMZ2INT' >> $CONF_DIR/tuxfrw.nft
    . $CONF_DIR/rules/tf_INT-DMZ.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading INT->DMZ"
    evaluate_retval
    . $CONF_DIR/rules/tf_DMZ-INT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading DMZ->INT"
    evaluate_retval
  fi

  # DMZ<->EXT rules
  if [ "$DMZ_IFACE" != "" -a "$EXT_IFACE" != "" ]; then
    $NFT 'add chain inet filter DMZ2EXT' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add chain inet filter EXT2DMZ' >> $CONF_DIR/tuxfrw.nft
    . $CONF_DIR/rules/tf_DMZ-EXT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading DMZ->EXT"
    evaluate_retval
    . $CONF_DIR/rules/tf_EXT-DMZ.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading EXT->DMZ"
    evaluate_retval
  fi

  # INT<->EXT rules
  if [ "$INT_IFACE" != "" -a "$EXT_IFACE" != "" ]; then
    $NFT 'add chain inet filter INT2EXT' >> $CONF_DIR/tuxfrw.nft
    $NFT 'add chain inet filter EXT2INT' >> $CONF_DIR/tuxfrw.nft
    . $CONF_DIR/rules/tf_INT-EXT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading INT->EXT"
    evaluate_retval
    . $CONF_DIR/rules/tf_EXT-INT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
    echo -n "Loading EXT->INT"
    evaluate_retval
  fi

  # INT<->VPN rules
  if [ "$INT_IFACE" != "" ]; then
     if [ "$PPTP_IFACE" != "" -o "$OpenVPN_IFACE" != "" ]; then
        $NFT 'add chain inet filter INT2VPN' >> $CONF_DIR/tuxfrw.nft
        $NFT 'add chain inet filter VPN2INT' >> $CONF_DIR/tuxfrw.nft
        . $CONF_DIR/rules/tf_INT-VPN.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
        echo -n "Loading INT->VPN"
        evaluate_retval
        . $CONF_DIR/rules/tf_VPN-INT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
        echo -n "Loading VPN->INT"
        evaluate_retval
     fi
  fi
  
  # EXT<->VPN rules
  if [ "$EXT_IFACE" != "" ]; then
     if [ "$PPTP_IFACE" != "" -o "$OpenVPN_IFACE" != "" ]; then
        $NFT 'add chain inet filter EXT2VPN' >> $CONF_DIR/tuxfrw.nft
        $NFT 'add chain inet filter VPN2EXT' >> $CONF_DIR/tuxfrw.nft
        . $CONF_DIR/rules/tf_EXT-VPN.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
        echo -n "Loading EXT->VPN"
        evaluate_retval
        . $CONF_DIR/rules/tf_VPN-EXT.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
        echo -n "Loading VPN->EXT"
        evaluate_retval
     fi
  fi

  # DMZ<->VPN rules
  if [ "$DMZ_IFACE" != "" ]; then
     if [ "$PPTP_IFACE" != "" -o "$OpenVPN_IFACE" != "" ]; then
        $NFT 'add chain inet filter DMZ2VPN' >> $CONF_DIR/tuxfrw.nft
        $NFT 'add chain inet filter VPN2DMZ' >> $CONF_DIR/tuxfrw.nft
        . $CONF_DIR/rules/tf_DMZ-VPN.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
        echo -n "Loading DMZ->VPN"
        evaluate_retval
        . $CONF_DIR/rules/tf_VPN-DMZ.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
        echo -n "Loading VPN->DMZ"
        evaluate_retval
     fi
  fi

  if [ "$EXT_IFACE" != "" ]; then
     if [ "$INT_IFACE" != "" -o "$DMZ_IFACE" != "" ]; then
        $NFT 'add chain inet filter FORWARD { type filter hook forward priority 0; policy drop; }' >> $CONF_DIR/tuxfrw.nft
        # create forward rules :-)
        . $CONF_DIR/rules/tf_FORWARD.mod 2> /tmp/tf_error >> $CONF_DIR/tuxfrw.nft
        echo -n "Loading FORWARD"
        evaluate_retval
     fi
  fi
}

#
# Load the NAT rules
#
create_natopen()
{
  # load kernel modules
  if [ "$KERN_MOD" != "0" ]; then
    load_kernel_modules
  fi

  # set /proc options
  set_sysctl

  # setup NAT
  run_natopen
}
