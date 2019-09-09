#!/bin/bash

# REMOVE disable of SC2154 WHEN PUTTING SPAMHAUS IN PRODUCTION (it's just to fixing travis for now)
# shellcheck disable=2034,2059,SC2154
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

print_text_in_color "$ICyan" "Installing Extra Security..."

# Based on: http://www.techrepublic.com/blog/smb-technologist/secure-your-apache-server-from-ddos-slowloris-and-dns-injection-attacks/

# Protect against DNS Injection
# Insipired by: https://www.c-rieger.de/nextcloud-13-nginx-installation-guide-for-ubuntu-18-04-lts/#spamhausproject

# shellcheck disable=SC2016
DATE='$(date +%Y-%m-%d)'
cat << SPAMHAUS_ENABLE > "$SCRIPTS/spamhaus_cronjob.sh"
#!/bin/bash
# Thanks to @ank0m
EXEC_DATE='date +%Y-%m-%d'
SPAMHAUS_DROP="/usr/local/src/drop.txt"
SPAMHAUS_eDROP="/usr/local/src/edrop.txt"
URL="https://www.spamhaus.org/drop/drop.txt"
eURL="https://www.spamhaus.org/drop/edrop.txt"
DROP_ADD_TO_UFW="/usr/local/src/DROP2.txt"
eDROP_ADD_TO_UFW="/usr/local/src/eDROP2.txt"
DROP_ARCHIVE_FILE="/usr/local/src/DROP_{$EXEC_DATE}"
eDROP_ARCHIVE_FILE="/usr/local/src/eDROP_{$EXEC_DATE}"
# All credits for the following BLACKLISTS goes to "The Spamhaus Project" - https://www.spamhaus.org
echo "Start time: $(date)"
echo " "
echo "Download daily DROP file:"
wget -q -O - "$URL" > $SPAMHAUS_DROP
grep -v '^;' $SPAMHAUS_DROP | cut -d ' ' -f 1 > $DROP_ADD_TO_UFW
echo " "
echo "Extract DROP IP addresses and add to UFW:"
cat $DROP_ADD_TO_UFW | while read line
do
/usr/sbin/ufw insert 1 deny from "$line" comment 'DROP_Blacklisted_IPs'
done
echo " "
echo "Downloading eDROP list and import to UFW"
echo " "
echo "Download daily eDROP file:"
wget -q -O - "$eURL" > $SPAMHAUS_eDROP
grep -v '^;' $SPAMHAUS_eDROP | cut -d ' ' -f 1 > $eDROP_ADD_TO_UFW
echo " "
echo "Extract eDROP IP addresses and add to UFW:"
cat $eDROP_ADD_TO_UFW | while read line
do
/usr/sbin/ufw insert 1 deny from "$line" comment 'eDROP_Blacklisted_IPs'
done
echo " "
#####
## To remove or revert these rules, keep the list of IPs!
## Run a command like so to remove the rules:
# while read line; do ufw delete deny from $line; done < $ARCHIVE_FILE
#####
echo "Backup DROP IP address list:"
mv $DROP_ADD_TO_UFW $DROP_ARCHIVE_FILE
echo " "
echo "Backup eDROP IP address list:"
mv $eDROP_ADD_TO_UFW $eDROP_ARCHIVE_FILE
echo " "
echo End time: $(date)
SPAMHAUS_ENABLE

# Make the file executable
chmod +x "$SCRIPTS"/spamhaus_cronjob.sh

# Add it to crontab
(crontab -l ; echo "10 2 * * * $SCRIPTS/spamhaus_crontab.sh 2>&1") | crontab -u root -

# Run it for the first time
check_command bash "$SCRIPTS"/spamhaus_cronjob.sh

# Enable $SPAMHAUS
if sed -i "s|#MS_WhiteList /etc/spamhaus.wl|MS_WhiteList $SPAMHAUS|g" /etc/apache2/mods-enabled/spamhaus.conf
then
    print_text_in_color "$IGreen" "Security added!"
    restart_webserver
fi
