#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
WPDB=1 && MYCNFPW=1 && FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO
unset MYCNFPW
unset WPDB

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

## If you want debug mode, please activate it further down in the code at line ~132

# FUNCTIONS #

msg_box() {
local PROMPT="$1"
    whiptail --msgbox "${PROMPT}" "$WT_HEIGHT" "$WT_WIDTH"
}

is_root() {
    if [[ "$EUID" -ne 0 ]]
    then
        return 1
    else
        return 0
    fi
}

root_check() {
if ! is_root
then
msg_box "Sorry, you are not root. You now have two options:
1. With SUDO directly:
   a) :~$ sudo bash $SCRIPTS/name-of-script.sh
2. Become ROOT and then type your command:
   a) :~$ sudo -i
   b) :~# $SCRIPTS/name-of-script.sh
In both cases above you can leave out $SCRIPTS/ if the script
is directly in your PATH.
More information can be found here: https://unix.stackexchange.com/a/3064"
    exit 1
fi
}

network_ok() {
    print_text_in_color "$ICyan" "Testing if network is OK..."
    service network-manager restart
    if wget -q -T 20 -t 2 http://github.com -O /dev/null
    then
        return 0
    else
        return 1
    fi
}

check_command() {
  if ! "$@";
  then
     print_text_in_color "$IRed" "Sorry but something went wrong. Please report this issue to $ISSUES and include the output of the error message. Thank you!"
	 print_text_in_color "$IRed" "$* failed"
    exit 1
  fi
}

# Colors
Color_Off='\e[0m'
IRed='\e[0;91m'
IGreen='\e[0;92m'
ICyan='\e[0;96m'

print_text_in_color() {
	printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

# END OF FUNCTIONS #

# Check if root
root_check

# Check network
if network_ok
then
    printf "${Green}Online!${Color_Off}\n"
else
    echo "Setting correct interface..."
    [ -z "$IFACE" ] && IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
    # Set correct interface
    {
        sed '/# The primary network interface/q' /etc/network/interfaces
        printf 'auto %s\niface %s inet dhcp\n# This is an autoconfigured IPv6 interface\niface %s inet6 auto\n' "$IFACE" "$IFACE" "$IFACE"
    } > /etc/network/interfaces.new
    mv /etc/network/interfaces.new /etc/network/interfaces
    service networking restart
    # shellcheck source=lib.sh
    CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/wildkatz2004/wordpress-vm/master/lib.sh)
    unset CHECK_CURRENT_REPO
fi

# Check network again
if network_ok
then
    printf "${IGreen}Online!${Color_Off}\n"
else
msg_box "Network NOT OK. You must have a working network connection to run this script.
Please contact us for support:
Email: duane.britting@gmail.com
Please also post this issue on: $ISSUES"
    exit 1
fi
# shellcheck source=lib.sh
WPDB=1 && MYCNFPW=1 && FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO
unset MYCNFPW
unset WPDB

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

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
chmod +x -R $SCRIPTS
chown root:root -R $SCRIPTS

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

# Generate new MARIADB password
print_text_in_color "$ICyan" "Generating new MARIADB password..."
if bash "$SCRIPTS/change_mysql_pass.sh" && wait
then
   rm "$SCRIPTS/change_mysql_pass.sh"
fi
clear

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

# Change password
printf "${Color_Off}\n"
print_text_in_color "$ICyan" "For better security, change the system user password for [$(getent group sudo | cut -d: -f4 | cut -d, -f1)]"
any_key "Press any key to change password for system user..."
while true
do
    sudo passwd "$(getent group sudo | cut -d: -f4 | cut -d, -f1)" && break
done
clear

cat << LETSENC
+-----------------------------------------------+
|  The following script will install a trusted  |
|  SSL certificate through Let's Encrypt.       |
+-----------------------------------------------+
LETSENC
# Let's Encrypt
if [[ "yes" == $(ask_yes_or_no "Do you want to install SSL?") ]]
then
    bash $SCRIPTS/activate-ssl.sh
else
    print_text_in_color "$ICyan" "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/activate-ssl.sh"
    any_key "Press any key to continue..."
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
clear

echo "$FQDN" > fqdn.txt
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
sed -i "s|# server_name .*|server_name $server_name;|g" /etc/nginx/sites-available/wordpress_port_80.conf
sed -i "s|# server_name .*|server_name $server_name;|g" /etc/nginx/sites-available/wordpress_port_443.conf
check_command service nginx restart

# Show current administrators
echo
print_text_in_color "$ICyan" "This is the current administrator(s):"
wp_cli_cmd user list --role=administrator --path="$WPATH"
any_key "Press any key to continue..."
clear


# Cleanup 1
rm -f "$SCRIPTS/ip.sh"
rm -f "$SCRIPTS/test_connection.sh"
rm -f "$SCRIPTS/instruction.sh"
rm -f "$SCRIPTS/wordpress-startup-script.sh"
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name '*.zip*' \) -delete
#sed -i "s|instruction.sh|techandme.sh|g" "/home/$UNIXUSER/.bash_profile"

truncate -s 0 \
    /root/.bash_history \
    "/home/$UNIXUSER/.bash_history" \
    /var/spool/mail/root \
    "/var/spool/mail/$UNIXUSER" \
    /var/log/apache2/access.log \
    /var/log/apache2/error.log \
    /var/log/cronjobs_success.log

#sed -i "s|sudo -i||g" "/home/$UNIXUSER/.bash_profile"
#cat << RCLOCAL > "/etc/rc.local"
##!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exit 0

RCLOCAL
clear

# Upgrade system
print_text_in_color "$ICyan" "System will now upgrade..."
bash $SCRIPTS/update.sh

# Cleanup 2
apt autoremove -y
apt autoclean

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

# Prefer IPv6
#sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

## Reboot
echo "Installations finished. System will now reboot..."
sleep 10
reboot
