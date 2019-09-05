#!/bin/bash

# Prefer IPv4
sed -i "s|#precedence ::ffff:0:0/96  100|precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
WPDB=1 && MYCNFPW=1 . <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)
unset MYCNFPW
unset WPDB

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
install_if_not install lshw
# Change DNS
install_if_not resolvconf
yes | dpkg-reconfigure --frontend=noninteractive resolvconf
echo "nameserver 208.67.222.222" > /etc/resolvconf/resolv.conf.d/base
echo "nameserver 208.67.220.220" >> /etc/resolvconf/resolv.conf.d/base

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


# Create $SCRIPTS dir
if [ ! -d "$SCRIPTS" ]
then
	log "Info" "Creating Scripts directory ($SCRIPTS)..."
	mkdir -p "$SCRIPTS"
	log "Info" "Directory created ($SCRIPTS)..."    
fi

# Check network
if ! [ -x "$(command -v nslookup)" ]
then
    apt install dnsutils -y -q
fi
if ! [ -x "$(command -v ifup)" ]
then
    apt install ifupdown -y -q
fi
sudo ifdown "$IFACE" && sudo ifup "$IFACE"
if ! nslookup google.com
then
    echo "Network NOT OK. You must have a working Network connection to run this script."
    exit 1
fi

#Changing local timezone to Central Standard
#sudo timedatectl set-timezone America/Mexico_City
# Update system
apt update -q4 & spinner_loading

#Install base packages
install_base_packages(){

    if check_sys packageManager apt; then
        apt_depends=(
		build-essential curl nano wget lftp unzip bzip2 arj nomarch 
		lzop htop openssl gcc git binutils libmcrypt4 libpcre3-dev make python2.7 
		python-pip supervisor unattended-upgrades whois zsh imagemagick tcl
		tree locate software-properties-common screen
		net-tools ffmpeg ghostscript libfile-fcntllock-perl
		gnupg2 lsb-release ssl-cert ca-certificates apt-transport-https
        )
        log "Info" "Starting to install base packages..."
        for depend in ${apt_depends[@]}
        do
            error_detect_depends "apt-get -y install ${depend}"
        done
         log "Info" "Install base packages completed..."
     fi
	
}

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
if [[ "yes" == $(ask_yes_or_no "Begin installing LAMP...?") ]]
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

#############################################################################
unattended-upgrades()
{
sudo apt-get install unattended-upgrades
# Following are additional software required
# we only need mailutils or bsd-mailx, choose 1
sudo apt-get install mailutils
sudo apt-get install bsd-mailx
sudo apt-get install update-notifier-common 

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

# Install Figlet
apt install figlet -y

# Configure VirtualHost Files
if [[ "yes" == $(ask_yes_or_no "Begin creating VirtualHost Files......?") ]]
then
	log "Info" "Preparing to Create VirtualHost Files..."
	run_static_script create_vhost_files
	log "Info" "Completed preparing Create VirtualHost Files..."
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
run_static_script change-root-profile
run_static_script change-wordpress-profile
if [ ! -f "$SCRIPTS"/wordpress-startup-script.sh ]
then
check_command wget -q "$GITHUB_REPO"/wordpress-startup-script.sh -P "$SCRIPTS"
fi

# Make $SCRIPTS excutable
chmod +x -R "$SCRIPTS"
chown root:root -R "$SCRIPTS"

# Allow wordpress to run theese scripts
chown www-data:www-data "$SCRIPTS/instruction.sh"
chown www-data:www-data "$SCRIPTS/history.sh"

# Upgrade
apt dist-upgrade -y

# Remove LXD (always shows up as failed during boot)
apt purge lxd -y

# Cleanup
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e ''"$(uname -r | cut -f1,2 -d"-")"'' | grep -e '[0-9]' | xargs sudo apt -y purge)
echo "$CLEARBOOT"
apt autoremove -y
apt autoclean
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name '*.zip*' \) -delete

# Prefer IPv6
sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Reboot
log "Info" "Installation done, system will now reboot..."

reboot
