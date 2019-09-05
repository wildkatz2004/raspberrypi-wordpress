#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
. <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)

# T&M Hansson IT AB © - 2019, https://www.hanssonit.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Check Ubuntu version
print_text_in_color "$ICyan" "Checking server OS and version..."
#if [ "$OS" != 1 ]
#then
#    print_text_in_color "$IRed" "Ubuntu Server is required to run this script."
#    print_text_in_color "$IRed" "Please install that distro and try again."
#    exit 1
#fi


#if ! version 18.04 "$DISTRO" 18.04.4; then
#    print_text_in_color "$IRed" "Ubuntu version $DISTRO must be between 18.04 - 18.04.4"
#    exit
#fi

# Check if dir exists
if [ ! -d $SCRIPTS ]
then
    mkdir -p $SCRIPTS
fi

#############################################################################

configure_redis()
{

## Redis performance tweaks ##
if ! grep -Fxq "vm.overcommit_memory = 1" /etc/sysctl.conf
then
    echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
fi

# Configure the general settings
sed -i "s|# unixsocket .*|unixsocket $REDIS_SOCK|g" $REDIS_CONF
sed -i "s|# unixsocketperm .*|unixsocketperm 777|g" $REDIS_CONF
sed -i "s|^port.*|port 0|" $REDIS_CONF
sed -i "s|# requirepass .*|requirepass $(cat /tmp/redis_pass.txt)|g" $REDIS_CONF
sed -i 's|# rename-command CONFIG ""|rename-command CONFIG ""|' $REDIS_CONF
sed -i "s|supervised no|supervised systemd|g" $REDIS_CONF
sed -i "s|daemonize no|daemonize yes|g" $REDIS_CONF
sed -i "s|# maxmemory <bytes>|maxmemory 250mb|g" $REDIS_CONF
sed -i "s|# maxmemory-policy noeviction|maxmemory-policy allkeys-lru|g" $REDIS_CONF
sed -i "s|dir ./|dir /var/lib/redis|g" $REDIS_CONF
sed -i "s|save 60 10000|# save 60 10000|g" $REDIS_CONF
sed -i "s|save 300 10|# save 300 10|g" $REDIS_CONF
sed -i "s|save 900 1|# save 900 1|g" $REDIS_CONF

# Create a Redis systemd Unit File
cat << EOF > /etc/systemd/system/redis.service
[Unit]
Description=Redis Server
After=network.target

[Service]
Type=forking
User=redis
Group=redis
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecReload=/bin/kill -USR2 $MAINPID
ExecStop=/usr/local/bin/redis-cli shutdown
Restart=always

[Install]
WantedBy=multi-user.target
EOF


# Secure Redis
chown redis:root /etc/redis/redis.conf
chmod 600 /etc/redis/redis.conf

}

#############################################################################
install_redis_dev()
{
#Download Redis package and unpack

mkdir -p /tmp/redis
cd /tmp/redis
wget http://download.redis.io/releases/redis-stable.tar.gz
tar xzf redis-stable.tar.gz
cd redis-stable
#Next step is to compile Redis with make utility and install

sudo make
sudo make install clean
sudo mkdir /etc/redis

#Then copy the configuration file to that directory.
sudo cp /tmp/redis/redis-stable/redis.conf /etc/redis
#Use the below command to create a user and user group.
sudo adduser --system --group --no-create-home redis
#Then, you have to create the directory.
sudo mkdir /var/lib/redis
#The directory is created and now you have to give the ownership of the directory to the newly created user and user group.
sudo chown redis:redis /var/lib/redis
#You have to block the user or group which doesn't have ownership towards the directory.
sudo chmod 770 /var/lib/redis

configure_redis
}

#############################################################################
install_redis()
{

# Install Redis
if ! apt -y install redis-server
then
    echo "Installation failed."
    sleep 3
    exit 1
else
    printf "${Green}\nRedis installation OK!${Color_Off}\n"
fi


configure_redis
}

#############################################################################
start_redis()
{
# Start Redis
sudo systemctl start redis
sudo systemctl status redis | cat
sudo systemctl stop redis
sudo systemctl enable redis
sudo systemctl restart redis
}
#############################################################################

# Install Redis
install_if_not php7.3-dev
pecl channel-update pecl.php.net
if ! yes no | pecl install -Z redis
then
    msg_box "PHP module installation failed"
exit 1
else
    print_text_in_color "$IGreen" "PHP module installation OK!"
fi

install_redis

# Set globally doesn't work for some reason
# touch /etc/php/7.0/mods-available/redis.ini
# print_text_in_color "$ICyan" 'extension=redis.so' > /etc/php/7.0/mods-available/redis.ini
# phpenmod redis
# Setting direct to apache2 works if 'libapache2-mod-php7.0' is installed
echo 'extension=redis.so' >> /etc/php/7.3/fpm/php.ini
service nginx restart


redis-cli SHUTDOWN
rm -f /tmp/redis_pass.txt

# Secure Redis
chown redis:root /etc/redis/redis.conf
chmod 600 /etc/redis/redis.conf

start_redis

#Start php7
sudo service php7.3-fpm status | cat
sudo service php7.3-fpm restart

apt update -q4 & spinner_loading
apt autoremove -y
apt autoclean

exit
