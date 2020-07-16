#!/usr/bin/env bash
#
# ----------------------------------------------------------------------------
# TuxFrw-NFT 1.0
# Copyright (C) 2001-2019 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)
# ----------------------------------------------------------------------------
#
# install.sh - TuxFrw installation script
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


# change the following variable to point the directory you want

SBIN_DIR="/sbin"
CONF_DIR="/etc/tuxfrw-nft"

echo
echo "------------------------------------------------------------------------------------"
echo "#                                                                                  #"
echo "# TuxFrw-NFT 1.0                                                                   #"
echo "# Copyright (C) 2001-2019 Marcelo Gondim (https://tuxfrw.linuxinfo.com.br/)        #"
echo "#                                                                                  #"
echo "------------------------------------------------------------------------------------"
echo

# check for root user
ROOT_UID=0
if [ "$UID" -ne "$ROOT_UID" ]; then
  echo " ERROR: This program can only be run by the system administrator."
  echo
  exit 1
fi

echo " Welcome to TuxFrw installation!"
echo
echo -e " Press ENTER to continue or CTRL-C to exit... \c"
read BUFFER

# check for nft
echo -n " Looking for nft... "
NFT="`type -p nft`"
sleep 1
if [ -z $NFT ]; then 
  echo "not found!"
  exit 1
fi
echo "found! (`$NFT -v`)"

echo
echo " Installing TuxFrw. Please wait... "
echo
sleep 1

mkdir -p $SBIN_DIR

mkdir -p $CONF_DIR/rules
chmod -R 700 $CONF_DIR
if [ -d "$CONF_DIR" ]; then
  install -v -m 600 rules/tf_*-*.mod $CONF_DIR/rules
  install -v -m 600 rules/tf_NETDEV.mod $CONF_DIR/rules
  install -v -m 600 rules/tf_INPUT.mod $CONF_DIR/rules
  install -v -m 600 rules/tf_OUTPUT.mod $CONF_DIR/rules
  install -v -m 600 rules/tf_FORWARD.mod $CONF_DIR/rules
  install -v -m 600 rules/tf_MANGLE.mod $CONF_DIR/rules
  install -v -m 600 tf_KERNEL.mod $CONF_DIR
  install -v -m 600 tf_BASE.mod $CONF_DIR
  install -v -m 600 tuxfrw.conf $CONF_DIR
  install -v -m 700 tuxfrw-nft $SBIN_DIR
fi

echo
echo " TuxFrw installation is finished! "
echo " Configure $CONF_DIR/tuxfrw.conf now."
echo

exit 0

