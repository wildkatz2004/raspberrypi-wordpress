#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)
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

#Install MariaDB Function

log "Info" "Write DB password to file to prepare for LAMP install..."
# Write MARIADB pass to file and keep it safe

# Write MARIADB pass to file and keep it safe
{
echo "[client]"
echo "password='$MARIADB_PASS'"
} > "$MYCNF"
chmod 0600 $MYCNF
chown root:root $MYCNF

install_mariadb(){

# Install MARIADB
sudo debconf-set-selections <<< "mariadb-server-10.3 mysql-server/root_password password $MARIADB_PASS"
sudo debconf-set-selections <<< "mariadb-server-10.3 mysql-server/root_password_again password $MARIADB_PASS"
apt update -q4 & spinner_loading
check_command apt install mariadb-server mariadb-client -y

# Prepare for MySQL user updates
log "Info" "Updating mysql user..."
# https://blog.v-gar.de/2017/02/en-solved-error-1698-28000-in-mysqlmariadb/
mysql -u root mysql -p"$MARIADB_PASS" -e "UPDATE user SET plugin='' WHERE user='root';"
mysql -u root mysql -p"$MARIADB_PASS" -e "UPDATE user SET password=PASSWORD('$MARIADB_PASS') WHERE user='root';"
mysql -u root -p"$MARIADB_PASS" -e "flush privileges;"
log "Info" "Mysql user updates completed..."

# mysql_secure_installation
apt -y install expect
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MARIADB_PASS\r\"
expect \"Change the root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"
apt -y purge expect

log "Info" "mysql_secure_installation config. completed..."
# Write a new MariaDB config
log "Info" "Preparing to create new mycnf file..."
run_static_script new_etc_mycnf
log "Info" "Creation of new mycnf file completed..."
}

# Install Nginx
install_nginx(){
apt update -q4 && spinner_loading
	if check_sys packageManager apt; then
		apt_nginx_package=(
		nginx
		)
		log "Info" "Starting to install primary packages for NGINX..."
		for depend in ${apt_nginx_package[@]}
		do
		    error_detect_depends "apt-get -y install ${depend}"
		done
		log "Info" "Install primary packages for NGINX completed..."
	fi
	
sudo systemctl stop nginx.service
sudo systemctl start nginx.service
sudo systemctl enable nginx.service
}

# Install PHP Dependencies Function
install_php_depends(){

    if check_sys packageManager apt; then
        apt_depends=(
            autoconf patch m4 snmp python-software-properties
        )
        log "Info" "Starting to install dependencies packages for PHP..."
        for depend in ${apt_depends[@]}
        do
            error_detect_depends "apt-get -y install ${depend}"
        done
        log "Info" "Install dependencies packages for PHP completed..."
     fi
	
}

# Configure PHP Function
configure_php(){
log "Info" "Beginning php.ini edits."
	# Make file backups
	sudo cp /etc/php/$PHPVER/fpm/pool.d/www.conf /etc/php/$PHPVER/fpm/pool.d/www.conf.bak
	sudo cp /etc/php/$PHPVER/cli/php.ini /etc/php/$PHPVER/cli/php.ini.bak
	sudo cp /etc/php/$PHPVER/fpm/php.ini /etc/php/$PHPVER/fpm/php.ini.bak
	sudo cp /etc/php/$PHPVER/fpm/php-fpm.conf /etc/php/$PHPVER/fpm/php-fpm.conf.bak
	sudo cp /etc/php/$PHPVER/fpm/pool.d/www.conf /etc/php/$PHPVER/fpm/pool.d/www.conf.bak
	sudo cp /etc/php/$PHPVER/cli/php.ini /etc/php/$PHPVER/cli/php.ini.bak
	# Configure PHP
	sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/pm.max_children = .*/pm.max_children = 240/" /etc/php/$PHPVER/fpm/pool.d/www.conf
	sudo sed -i "s/pm.start_servers = .*/pm.start_servers = 20/" /etc/php/$PHPVER/fpm/pool.d/www.conf
	sudo sed -i "s/pm.min_spare_servers = .*/pm.min_spare_servers = 10/" /etc/php/$PHPVER/fpm/pool.d/www.conf
	sudo sed -i "s/pm.max_spare_servers = .*/pm.max_spare_servers = 20/" /etc/php/$PHPVER/fpm/pool.d/www.conf
	sudo sed -i "s/;pm.max_requests = 500/pm.max_requests = 500/" /etc/php/$PHPVER/fpm/pool.d/www.conf
	sudo sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/$PHPVER/cli/php.ini
	sudo sed -i "s|max_execution_time =.*|max_execution_time = 360|g" /etc/php/$PHPVER/cli/php.ini
	sudo sed -i "s|cgi.fix_pathinfo =.*|cgi.fix_pathinfo=0|g" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/$PHPVER/cli/php.ini
	sudo sed -i "s/post_max_size =.*/post_max_size = 110M/" /etc/php/$PHPVER/cli/php.ini
	sudo sed -i "s/max_file_uploads =.*/max_file_uploads = 100/" /etc/php/$PHPVER/cli/php.ini
	sudo sed -i "s/;session.cookie_secure.*/session.cookie_secure = True/" /etc/php/$PHPVER/cli/php.ini
	sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s|max_execution_time =.*|max_execution_time = 360|g" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/post_max_size =.*/post_max_size = 110M/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/upload_max_filesize =.*/upload_max_filesize = 256M/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/max_file_uploads =.*/max_file_uploads = 100/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;session.cookie_secure.*/session.cookie_secure = True/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;opcache.enable=.*/opcache.enable=1/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;opcache.enable_cli=.*/opcache.enable_cli=1/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=128/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=8/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;opcache.save_comments=.*/opcache.save_comments=1/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;emergency_restart_threshold =.*/emergency_restart_threshold = 10/" /etc/php/$PHPVER/fpm/php-fpm.conf
	sudo sed -i "s/;emergency_restart_interval =.*/emergency_restart_interval = 1m/" /etc/php/$PHPVER/fpm/php-fpm.conf
	sudo sed -i "s/;process_control_timeout =.*/process_control_timeout = 10s/" /etc/php/$PHPVER/fpm/php-fpm.conf
	sudo sed -i "s|allow_url_fopen =.*|allow_url_fopen = On|g" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s|file_uploads =.*|file_uploads = On|g" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s|cgi.fix_pathinfo =.*|cgi.fix_pathinfo=0|g" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/$PHPVER/cli/php.ini
	sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/$PHPVER/cli/php.ini
	sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL \& ~E_NOTICE \& ~E_STRICT \& ~E_DEPRECATED/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/display_errors = .*/display_errors = Off/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/$PHPVER/fpm/php.ini
	sudo sed -i "s/pm.max_children = .*/pm.max_children = 240/" /etc/php/$PHPVER/fpm/pool.d/www.conf
	sudo sed -i "s/pm.start_servers = .*/pm.start_servers = 20/" /etc/php/$PHPVER/fpm/pool.d/www.conf
	#Tune PHP-FPM pool settings
	#sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.3/fpm/pool.d/www.conf
	#sed -i "s/;request_terminate_timeout.*/request_terminate_timeout = 60/" /etc/php/7.3/fpm/pool.d/www.conf
	#sed -i "s/pm\.max_children.*/pm.max_children = 70/" /etc/php/7.3/fpm/pool.d/www.conf
	#sed -i "s/pm\.start_servers.*/pm.start_servers = 20/" /etc/php/7.3/fpm/pool.d/www.conf
	#sed -i "s/pm\.min_spare_servers.*/pm.min_spare_servers = 20/" /etc/php/7.3/fpm/pool.d/www.conf
	#sed -i "s/pm\.max_spare_servers.*/pm.max_spare_servers = 35/" /etc/php/7.3/fpm/pool.d/www.conf
	#sed -i "s/;pm\.max_requests.*/pm.max_requests = 500/" /etc/php/7.3/fpm/pool.d/www.conf	
	
	#Configure sessions directory permissions
	#chmod 733 /var/lib/php/sessions
	#chmod +t /var/lib/php/sessions
	
	# Restart NGINX
	sudo service php7.3-fpm restart && sudo service nginx restart

log "Info" "Php.ini edits completed."
}

# Install PHP Function
install_php(){
local phpversion=php7.3

	if check_sys packageManager apt; then
		apt_php_package=(
		php"$PHPVER" php"$PHPVER"-fpm php"$PHPVER"-common php"$PHPVER"-mysql
		php"$PHPVER"-common php"$PHPVER"-cli php"$PHPVER"-dev php"$PHPVER"-pgsql php"$PHPVER"-sqlite3 php"$PHPVER"-gd php"$PHPVER"-curl php-memcached 
		php"$PHPVER"-imap php"$PHPVER"-mbstring php"$PHPVER"-xml php-imagick php"$PHPVER"-zip php"$PHPVER"-bcmath php"$PHPVER"-soap 
		php"$PHPVER"-intl php"$PHPVER"-readline php"$PHPVER"-pspell php"$PHPVER"-tidy php"$PHPVER"-xmlrpc php"$PHPVER"-xsl
		php"$PHPVER"-opcache php-apcu	
		)
		log "Info" "Starting to install primary packages for PHP..."
		for depend in ${apt_php_package[@]}
		do
		    error_detect_depends "apt-get -y install ${depend}"
		done
		log "Info" "Install primary packages for PHP completed..."
	fi
	
# Configure PHP
configure_php

php -v

# Lets also check if the php7.3-FPM is running, if not start it

service php"$PHPVER"-fpm status
if (( $(ps -ef | grep -v grep | grep "$phpversion-fpm" | wc -l) > 0 ))
then
echo "$service is running"
else
service $phpversion-fpm start  # (if the service isn't running already)
fi
}

# Install Lamp
lamp(){
	log "Info" "Beginning MariaDB install..."
	install_mariadb
	log "Info" "MariaDB install completed..."
	log "Info" "Beginning Nginx install..."
	install_nginx
	log "Info" "MariaDB Nginx completed..."	
	log "Info" "Beginning PHP install..."
	#install_php_depends	
	install_php
	log "Info" "PHP install completed..."	
	log "Info" "Beginning NGINX file configs..."	
	run_static_script create_nginx_files
	log "Info" "NGINX file configs completed..."	
	log "Info" "Beginning igbinary & apcu file configs..."		
	run_static_script config_igbinary_apcu
	log "Info" "igbinary & apcu file configs completed..."	
	
}

lamp 
