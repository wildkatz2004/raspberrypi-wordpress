#!/bin/bash

# Prefer IPv4
sed -i "s|#precedence ::ffff:0:0/96  100|precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
if ! is_root
then
    printf "\n${Red}Sorry, you are not root.\n${Color_Off}You must type: ${Cyan}sudo ${Color_Off}bash %s/wordpress_install.sh\n" "$SCRIPTS"
    exit 1
fi

# Test RAM size (2GB min) + CPUs (min 1)
#ram_check 2 Wordpress
#cpu_check 1 Wordpress

# Show current user
echo
echo "Current user with sudo permissions is: $UNIXUSER".
echo "This script will set up everything with that user."
echo "If the field after ':' is blank you are probably running as a pure root user."
echo "It's possible to install with root, but there will be minor errors."
echo
echo "Please create a user with sudo permissions if you want an optimal installation."
run_static_script adduser


# Check Ubuntu version
#echo "Checking server OS and version..."
#if [ "$OS" != 1 ]
#then
#    echo "Ubuntu Server is required to run this script."
#    echo "Please install that distro and try again."
#    exit 1
#fi


#if ! version 16.04 "$DISTRO" 16.04.5; then
#    echo "Ubuntu version $DISTRO must be between 16.04 - 16.04.4"
#    exit
#fi

printf "${Green}Gathering System info${Color_Off}\n" 
preinstall_lamp
if [[ "yes" == $(ask_yes_or_no "Check if this is clean server... ?") ]]
then
	printf "${Green}Beginning check if server is clean...${Color_Off}\n" 
	# Check if it's a clean server
	is_this_installed postgresql
	is_this_installed apache2
	is_this_installed php
	is_this_installed mysql-common
	is_this_installed mysql-server
	printf "${Green}Server is clean...${Color_Off}\n" 
else
	printf "${Green}OK, moving to next step...${Color_Off}\n" 
fi

#Install tools
install_tool

# Change DNS
yes | dpkg-reconfigure --frontend=noninteractive resolvconf
echo "nameserver 208.67.222.222" > /etc/resolvconf/resolv.conf.d/base
echo "nameserver 208.67.220.220" >> /etc/resolvconf/resolv.conf.d/base

sudo ifdown "$IFACE" && sudo ifup "$IFACE"
if ! nslookup google.com
then
    echo "Network NOT OK. You must have a working Network connection to run this script."
    exit 1
fi

# Create $SCRIPTS dir
if [ ! -d "$SCRIPTS" ]
then
	log "Info" "Creating Scripts directory ($SCRIPTS)..."
	mkdir -p "$SCRIPTS"
	log "Info" "Directory created ($SCRIPTS)..."    
fi

print_text_in_color "$ICyan" "Getting scripts from GitHub to be able to run the first setup..."

# All the shell scripts in static (.sh)

download_static_script security
download_static_script update
download_static_script test_connection
download_static_script wp-permissions
download_static_script change_mysql_pass
download_static_script techandme
download_static_script index
download_le_script activate-ssl

# Make $SCRIPTS excutable
chmod +x -R "$SCRIPTS"
chown root:root -R "$SCRIPTS"

# Allow wordpress to run figlet script
chown wordpress:wordpress $SCRIPTS/techandme.sh
clear

msg_box"This script will do the final setup for you

- Genereate new server SSH keys
- Set static IP
- Create a new WP user
- Upgrade the system
- Activate SSL (Let's Encrypt)
- Install Adminer
- Change keyboard setup 
- Change system timezone
- Set new password to the Linux system (user: wordpress)
############### D&B Consulting -  $(date +"%Y") ###############"

clear
# Set keyboard layout
print_text_in_color "$ICyan" "Current keyboard layout is $(localectl status | grep "Layout" | awk '{print $3}')"
if [[ "no" == $(ask_yes_or_no "Do you want to change keyboard layout?") ]]
then
    print_text_in_color "$ICyan" "Not changing keyboard layout..."
    sleep 1
    clear
else
    dpkg-reconfigure keyboard-configuration
clear
fi

# Change Timezone
print_text_in_color "$ICyan" "Current timezone is $(cat /etc/timezone)"
if [[ "no" == $(ask_yes_or_no "Do you want to change timezone?") ]]
then
    print_text_in_color "$ICyan" "Not changing timezone..."
    sleep 1
    clear
else
    dpkg-reconfigure tzdata
clear
fi

# Generate new SSH Keys
printf "\nGenerating new SSH keys for the server...\n"
rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

whiptail --title "Which apps do you want to install?" --checklist --separate-output "Automatically configure and install selected apps\nSelect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Fail2ban" "(Extra Bruteforce protection)   " OFF \
"Webmin" "(Server GUI)       " OFF \
"Adminer" "(*SQL GUI)       " OFF 2>results
while read -r -u 9 choice
do
    case $choice in
        Fail2ban)
            run_app_script fail2ban

        ;;

        Webmin)
            run_app_script webmin

        ;;

        Adminer)
            run_app_script adminer
        ;;

        *)
        ;;
    esac
done 9< results
rm -f results
clear

# Update system
apt-get update -q4 & spinner_loading


if [[ "yes" == $(ask_yes_or_no "Begin installing base packages...?") ]]
then
	log "Info" "Preparing to install base packages..."
	install_base_packages
	log "Info" "Completed installing base packages..."
else
	printf "${Green}OK, moving to next step...${Color_Off}\n" 
fi


#Install Composer
if [[ "yes" == $(ask_yes_or_no "Begin installing Composer...?") ]]
then
	log "Info" "Preparing to install Composer..."
	curl -sS https://getcomposer.org/installer | php
	mv composer.phar /usr/local/bin/composer
else
	printf "${Green}OK, moving to next step...${Color_Off}\n" 
fi

# Install Lamp
if [[ "yes" == $(ask_yes_or_no "Begin installing LEMP...?") ]]
then
	log "Info" "Preparing to install LAMP..."
	run_static_script lemp_install
	log "Info" "Completed installing LAMP..."
else
	printf "${Green}OK, moving to next step...${Color_Off}\n" 
fi



# Install WordPress
if [[ "yes" == $(ask_yes_or_no "Begin installing WordPress...?") ]]
then
	log "Info" "Preparing to install WordPress..."
	run_static_script wp_install
	log "Info" "Completed installing WordPress..."
else
	printf "${Green}OK, moving to next step...${Color_Off}\n" 
fi

# Define FQDN and create new WP user
MYANSWER="no"
while [ "$MYANSWER" == "no" ] 
do
   clear
   cat << ENTERNEW
+-----------------------------------------------+
|    Please define the FQDN and create a new    |
|    user for Wordpress.                        |
|    Make sure your FQDN starts with either     |
|    http:// or https://, otherwise your        |
|    installation will not work correctly!      |
+-----------------------------------------------+
ENTERNEW
   print_text_in_color "$IGreen" "Enter FQDN (http(s)://yourdomain.com):"
   read -r FQDN
   echo
   print_text_in_color "$IGreen" "Enter username:"
   read -r USER
   echo
   print_text_in_color "$IGreen" "Enter password:"
   read -r NEWWPADMINPASS
   echo
   print_text_in_color "$IGreen" "Enter email address:"
   read -r EMAIL
   echo
   MYANSWER=$(ask_yes_or_no "Is this correct?  FQDN: $FQDN User: $USER Password: $NEWWPADMINPASS Email: $EMAIL") 
done
clearecho "$FQDN" > fqdn.txt
wp_cli_cmd option update siteurl < fqdn.txt --path="$WPATH"
rm fqdn.txt

OLDHOME=$(wp_cli_cmd option get home --path="$WPATH")
wp_cli_cmd search-replace "$OLDHOME" "$FQDN" --precise --all-tables --path="$WPATH"

wp_cli_cmd user create "$USER" "$EMAIL" --role=administrator --user_pass="$NEWWPADMINPASS" --path="$WPATH"
wp_cli_cmd user delete 1 --reassign="$USER" --path="$WPATH"
{
echo "WP USER: $USER"
echo "WP PASS: $NEWWPADMINPASS"
} > /var/adminpass.txt

# Change servername in Nginx
server_name=$(echo "$FQDN" | cut -d "/" -f3)
sed -i "s|# server_name .*|server_name $server_name;|g" $HTTP_CONF
sed -i "s|# server_name .*|server_name $server_name;|g" $SSL_CONF
check_command service nginx restart

# Show current administrators
echo
print_text_in_color "$ICyan" "This is the current administrator(s):"
wp_cli_cmd user list --role=administrator --path="$WPATH"
any_key "Press any key to continue..."
clear



#############################################################################
unattended-upgrades()
{
sudo apt-get install unattended-upgrades
# Following are additional software required
# we only need mailutils or bsd-mailx, choose 1
#Setup unattended security upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Origins-Pattern {
        // Codename based matching:
        // This will follow the migration of a release through different
        // archives (e.g. from testing to stable and later oldstable).
//      "o=Debian,n=jessie";
//      "o=Debian,n=jessie-updates";
//      "o=Debian,n=jessie-proposed-updates";
//      "o=Debian,n=jessie,l=Debian-Security";
        "o=${distro_id},n=${distro_codename}";
        "o=${distro_id},n=${distro_codename}-updates";
        "o=${distro_id},n=${distro_codename}-proposed-updates";
        "o=${distro_id},n=${distro_codename},l=Debian-Security";
	// Archive or Suite based matching:
        // Note that this will silently match a different release after
        // migration to the specified archive (e.g. testing becomes the
        // new stable).
//      "o=Debian,a=stable";
//      "o=Debian,a=stable-updates";
//      "o=Debian,a=proposed-updates";
        "origin=Debian,codename=${distro_codename},label=Debian-Security";
};
Unattended-Upgrade::Package-Blacklist {
//
};
Unattended-Upgrade::Mail "duane.britting@gmail.com";
Unattended-Upgrade::Automatic-Reboot "true";
EOF

cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
#sudo unattended-upgrade -d -v --dry-run
sudo dpkg-reconfigure --priority=low unattended-upgrades

}

#############################################################################

# Configure unattended security upgrades
if [[ "yes" == $(ask_yes_or_no "Begin unattended security upgrades...?") ]]
then
	log "Info" "Setup unattended security upgrades..."
	unattended-upgrades
	log "Info" "Completed setup unattended security upgrades..."
else
	printf "${Green}OK, moving to next step...${Color_Off}\n" 
fi

# Enable UTF8mb4 (4-byte support)
#log "Info" "Will attempt to Enable UTF8mb4 ..."
#any_key "Press any key to continue the script..."
#check_command alter_database_char_set $MARIADBMYCNFPASS
#log "Info" "UTF8mb4 enabled..."
#databases=$(mysql -u root -p"$MARIADBMYCNFPASS" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)
#for db in $databases; do
#    if [[ "$db" != "performance_schema" ]] && [[ "$db" != _* ]] && [[ "$db" != "information_schema" ]];
#    then
#        echo "Changing to UTF8mb4 on: $db"
#        mysql -u root -p"$MARIADBMYCNFPASS" -e "ALTER DATABASE $db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
#    fi
#done

# Enable OPCache for PHP
log "Info" "Will attempt to Enable OPCache for PHP..."
any_key "Press any key to continue the script..."
# Enable OPCache for PHP
phpenmod opcache
{
echo "# OPcache settings for Wordpress"
echo "opcache.enable=1"
echo "opcache.enable_cli=1"
echo "opcache.interned_strings_buffer=8"
echo "opcache.max_accelerated_files=10000"
echo "opcache.memory_consumption=128"
echo "opcache.save_comments=1"
echo "opcache.revalidate_freq=1"
echo "opcache.validate_timestamps=1"
} >> /etc/php/7.3/fpm/php.ini
cat /etc/php/7.3/fpm/php.ini

log "Info" "OPCache Enabled for PHP..."
# Set secure permissions final
run_static_script redis-server-pi
run_static_script wp-permissions

#cration of robots.txt
log "Info" "Attempting to create robot.txt file..."
sleep 3
cat > $WPATH/robots.txt <<EOL
User-agent: *
Disallow: /cgi-bin
Disallow: /wp-admin/
Disallow: /wp-includes/
Disallow: /wp-content/
Disallow: /wp-content/plugins/
Disallow: /wp-content/themes/
Disallow: /trackback
Disallow: */trackback
Disallow: */*/trackback
Disallow: */*/feed/*/
Disallow: */feed
Disallow: /*?*
Disallow: /tag
Disallow: /?author=*
EOL

cat $WPATH/robots.txt
log "Info" "Robot.txt file created..."

# Prepare for first mount
download_static_script instruction
download_static_script history

# Cleanup
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e ''"$(uname -r | cut -f1,2 -d"-")"'' | grep -e '[0-9]' | xargs sudo apt -y purge)
echo "$CLEARBOOT"

# Cleanup 1
rm -f "$SCRIPTS/ip.sh"
rm -f "$SCRIPTS/test_connection.sh"
rm -f "$SCRIPTS/instruction.sh"
rm -f "$SCRIPTS/wordpress-startup-script.sh"
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name '*.zip*' \) -delete

# Upgrade system
print_text_in_color "$ICyan" "System will now upgrade..."
bash $SCRIPTS/update.sh

# Cleanup 2
apt-get autoremove -y
apt-get autoclean

ADDRESS2=$(grep "server_name" /etc/nginx/sites-available/wordpress_port_80.conf | awk '$1 == "server_name" { print $2 }' | cut -d ";" -f1)
# Success!
clear
# Success!
msg_box "Congratulations! You have successfully installed Wordpress!
Login to Wordpress in your browser:
- IP: $ADDRESS
- Hostname: $(hostname -f)

SUPPORT:
Please ask for help in the forums, or visit our shop to buy support,
Email: duane.britting@gmail.com

BUGS:
Please report any bugs here: https://github.com/wildkatz2004/raspberrypi-wordpress

TIPS & TRICKS:
1. Publish your server online: https://goo.gl/iUGE2U
2. To update this VM just type: sudo bash /var/scripts/update.sh
3. Change IP to something outside DHCP: sudo nano /etc/netplan/01-netcfg.yaml

 ######################### D&B Consulting - $(date +"%Y") #########################  "


# Allow wordpress to run theese scripts
chown www-data:www-data "$SCRIPTS/instruction.sh"
chown www-data:www-data "$SCRIPTS/history.sh"
sudo usermod -a -G redis www-data
sudo find /var/www/html/wordpress -type d -exec chmod 755 {} \;
sudo find /var/www/html/wordpress -type f -exec chmod 644 {} \;
sudo chown -R www-data /var/www/html/wordpress
sudo service php"$PHPVER"-fpm restart && sudo service nginx restart

# Upgrade
apt-get dist-upgrade -y
# Remove LXD (always shows up as failed during boot)
apt-get purge lxd -y

# Prefer IPv6
#sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Reboot
log "Info" "Installation done, system will now reboot..."

sleep 10
reboot
