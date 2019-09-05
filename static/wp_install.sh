#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)

echo mariadb"$MYCNFPW"
# Run WordPress Install Function
wordpress_install(){

# Download wp-cli.phar to be able to install Wordpress
check_command curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Add www-data in sudoers
{
echo "# WP-CLI" 
echo "$SUDO_USER ALL=(www-data) NOPASSWD: /usr/local/bin/wp"
echo "root ALL=(www-data) NOPASSWD: /usr/local/bin/wp"
} >> /etc/sudoers

# Create dir
mkdir -p "$WPATH"
chown -R www-data:www-data "$WPATH"
if [ ! -d /home/"$SUDO_USER"/.wp-cli ]
then
    mkdir -p /home/"$SUDO_USER"/.wp-cli/
    chown -R www-data:www-data /home/"$SUDO_USER"/.wp-cli/
fi

# Create wp-cli.yml
touch $WPATH/wp-cli.yml
cat << YML_CREATE > "$WPATH/wp-cli.yml"
nginx_modules:
  - mod_rewrite
YML_CREATE

# Show info about wp-cli
wp --info --allow-root

# Download Wordpress
cd "$WPATH"
check_command wp core download --allow-root --force --debug --path="$WPATH"

# Populate DB
mysql -u root -p"$MYCNFPW" <<MYSQL_SCRIPT
CREATE DATABASE $WPDBNAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '$WPDBUSER'@'localhost' IDENTIFIED BY '$WPDBPASS';
GRANT ALL PRIVILEGES ON brwordpress.* TO 'wordpressuser'@'localhost' IDENTIFIED BY '$WPDBPASS';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
wp_cli_cmd core config --dbname=$WPDBNAME --dbuser=$WPDBUSER --dbpass="$WPDBPASS" --dbhost=localhost --path=$WPATH --extra-php <<PHP
/** REDIS PASSWORD */
define( 'WP_REDIS_PASSWORD', '$REDIS_PASS' );
/** REDIS CLIENT */
define( 'WP_REDIS_CLIENT', 'pecl' );
/** REDIS SOCKET */
define( 'WP_REDIS_SCHEME', 'unix' );
/** REDIS PATH TO SOCKET */
define( 'WP_REDIS_PATH', '$REDIS_SOCK' );
/** REDIS SALT */
define('WP_REDIS_MAXTTL', 9600);
/** AUTO UPDATE */
define( 'WP_AUTO_UPDATE_CORE', true );
/** WP DEBUG? */
define( 'WP_DEBUG', false );
/** WP MEMORY SETTINGS*/
define( 'WP_MEMORY_LIMIT', '128M' );
PHP

# Make sure the passwords are the same, this file will be deleted when Redis is run.
echo "$REDIS_PASS" > /tmp/redis_pass.txt

# Install Wordpress
check_command wp core install --allow-root --url=http://"$ADDRESS"/ --title=Wordpress --admin_user=$WPADMINUSER --admin_password="$WPADMINPASS" --admin_email=duane.britting@gmail.com --path=$WPATH --skip-email
echo "WP PASS: $WPADMINPASS" > /var/adminpass.txt
chown wordpress:wordpress /var/adminpass.txt

# Create welcome post
check_command wget -q $STATIC/welcome.txt
sed -i "s|wordpress_user_login|$WPADMINUSER|g" welcome.txt
sed -i "s|wordpress_password_login|$WPADMINPASS|g" welcome.txt
wp post create ./welcome.txt --post_title='Tech and Me - Welcome' --post_status=publish --path=$WPATH --allow-root
rm -f welcome.txt
wp post delete 1 --force --allow-root

# Show version
wp core version --allow-root
sleep 3

# delete akismet and hello dolly
wp plugin delete akismet --allow-root
wp plugin delete hello --allow-root

# Install Apps
wp plugin install --allow-root opcache
wp plugin install --allow-root wp-mail-smtp
wp plugin install --allow-root redis-cache
#wp plugin install --allow-root all-in-one-wp-migration --activate

#sed -i "s|define( 'AI1WM_MAX_FILE_SIZE', 2 << 28 )|define( 'AI1WM_MAX_FILE_SIZE', 536870912 * 20 )|g" /var/www/html/wordpress/wp-content/plugins/all-in-one-wp-migration/constants.php


# set pretty urls
wp rewrite structure '/%postname%/' --hard --allow-root
wp rewrite flush --hard --allow-root
}

# Run WordPress Install Function
wordpress_install

# Secure permissions
run_static_script wp-permissions

# Hardening security
# create .htaccess to protect uploads directory
cat > $WPATH/wp-content/uploads/.htaccess <<'EOL'
# Protect this file
<Files .htaccess>
Order Deny,Allow
Deny from All
</Files>
# whitelist file extensions to prevent executables being
# accessed if they get uploaded
order deny,allow
deny from all
<Files ~ ".(docx?|xlsx?|pptx?|txt|pdf|xml|css|jpe?g|png|gif)$">
allow from all
</Files>
EOL


# Secure wp-includes
# https://wordpress.org/support/article/hardening-wordpress/#securing-wp-includes
{
echo "# Block wp-includes folder and files"
echo "<IfModule mod_rewrite.c>"
echo "RewriteEngine On"
echo "RewriteBase /"
echo "RewriteRule ^wp-admin/includes/ - [F,L]"
echo "RewriteRule !^wp-includes/ - [S=3]"
echo "RewriteRule ^wp-includes/[^/]+\.php$ - [F,L]"
echo "RewriteRule ^wp-includes/js/tinymce/langs/.+\.php - [F,L]"
echo "RewriteRule ^wp-includes/theme-compat/ - [F,L]"
echo "# RewriteRule ^wp-includes/* - [F,L]" # Block EVERYTHING
echo "</IfModule>"
} >> $WPATH/.htaccess

# Set up a php-fpm pool with a unixsocket
cat << POOL_CONF > "$PHP_POOL_DIR/www_wordpress.conf"
[www_wordpress]
user = www-data
group = www-data
listen = $PHP_FPM_SOCK
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 17
pm.start_servers = 5
pm.min_spare_servers = 2
pm.max_spare_servers = 10
pm.max_requests = 500
env[HOSTNAME] = $(hostname -f)
env[PATH] = /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
security.limit_extensions = .php
php_admin_value [cgi.fix_pathinfo] = 1
POOL_CONF

# Disable regular pool
mv $PHP_POOL_DIR/www.conf $PHP_POOL_DIR/default_www.config
