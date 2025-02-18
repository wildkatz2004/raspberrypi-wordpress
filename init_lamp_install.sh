#!/bin/bash

# Prefer IPv4
sed -i "s|#precedence ::ffff:0:0/96  100|precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)

# This file is part of the LAMP script.
#

cur_dir=`pwd`

#lamp main process
lamp(){

#Install tools
install_tool
run_static_script server_setup
}

#Run it
lamp 2>&1 | tee ${cur_dir}/lamp.log
