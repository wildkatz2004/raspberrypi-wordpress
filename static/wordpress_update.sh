#!/bin/bash

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
MYCNFPW=1 . <(curl -sL https://raw.githubusercontent.com/techandme/wordpress-vm/master/lib.sh)
unset MYCNFPW

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${Cyan}sudo ${Color_Off}bash %s/wordpress_update.sh\n" "$SCRIPTS"
    exit 1
fi

# Make sure old instaces can upgrade as well
if [ ! -f "$MYCNF" ] && [ -f /var/mysql_password.txt ]
then
    regressionpw=$(grep "New MySQL ROOT password:" /var/mysql_password.txt | awk '{print $5}')
cat << LOGIN > "$MYCNF"
[client]
password='$regressionpw'
LOGIN
    chmod 0600 $MYCNF
    chown root:root $MYCNF
    print_text_in_color "$ICyan" "Please restart the upgrade process, we fixed the password file $MYCNF."
    exit 1
elif [ -z "$MARIADBMYCNFPASS" ] && [ -f /var/mysql_password.txt ]
then
    regressionpw=$(cat /var/mysql_password.txt)
    {
    echo "[client]"
    echo "password='$regressionpw'"
    } >> "$MYCNF"
    print_text_in_color "$ICyan" "Please restart the upgrade process, we fixed the password file $MYCNF."
    exit 1
fi

if [ -z "$MARIADBMYCNFPASS" ]
then
    print_text_in_color "$IRed" "Something went wrong with copying your mysql password to $MYCNF."
    print_text_in_color "$IRed" "Please report this issue to $ISSUES, thanks!"
    exit 1
else
    rm -f /var/mysql_password.txt
fi

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# System Upgrade
apt update -q2
apt dist-upgrade -y

# Update Redis PHP extension
print_text_in_color "$ICyan" "Trying to upgrade the Redis PECL extenstion..."
if ! pecl list | grep redis >/dev/null 2>&1
then
    if dpkg -l | grep php7.2 > /dev/null 2>&1
    then
        install_if_not php7.2-dev
    else
        install_if_not php7.0-dev
    fi
    apt purge php-redis -y
    apt autoremove -y
    pecl channel-update pecl.php.net
    yes no | pecl install redis
    service redis-server restart
    if nginx -v 2> /dev/null
    then
        service nginx restart
    elif apache2 -v 2> /dev/null
    then
        service apache2 restart
    fi
elif pecl list | grep redis >/dev/null 2>&1
then
    if dpkg -l | grep php7.2 > /dev/null 2>&1
    then
        install_if_not php7.2-dev
    else
        install_if_not php7.0-dev
    fi
    pecl channel-update pecl.php.net
    yes no | pecl upgrade redis
    service redis-server restart
    if nginx -v 2> /dev/null
    then
        service nginx restart
    elif apache2 -v 2> /dev/null
    then
        service apache2 restart
    fi
fi

# Update adminer
if [ -d $ADMINERDIR ]
then
    print_text_in_color "$ICyan" "Updating Adminer..."
    rm -f "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php
    wget -q "http://www.adminer.org/latest.php" -O "$ADMINERDIR"/latest.php
    ln -s "$ADMINERDIR"/latest.php "$ADMINERDIR"/adminer.php
fi

# Set secure permissions
if [ ! -f "$SECURE" ]
then
    mkdir -p "$SCRIPTS"
    download_static_script wp-permissions
    chmod +x "$SECURE"
    bash "$SECURE"
elif [ -f "$SECURE" ]
then
    bash "$SECURE"
fi

# Upgrade WP-CLI
wp cli update

# Upgrade Wordpress and apps
cd $WPATH
wp_cli_cmd db export mysql_backup.sql
mv $WPATH/mysql_backup.sql /var/www/mysql_backup.sql
chown root:root /var/www/mysql_backup.sql
wp_cli_cmd core update --force
wp_cli_cmd plugin update --all
wp_cli_cmd core update-db
wp_cli_cmd db optimize
print_text_in_color "$ICyan" "This is the current version installed:"
wp_cli_cmd core version --extra

# Cleanup un-used packages
apt autoremove -y
apt autoclean

# Update GRUB, just in case
update-grub

# Write to log
touch /var/log/cronjobs_success.log
echo "WORDPRESS UPDATE success-$(date +%Y-%m-%d_%H:%M)" >> /var/log/cronjobs_success.log

# Un-hash this if you want the system to reboot
# reboot

exit
