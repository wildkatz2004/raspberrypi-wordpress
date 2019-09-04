#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
 . <(curl -sL https://raw.githubusercontent.com/wildkatz2004/raspberrypi-wordpress/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Install Figlet
apt install figlet -y

# Generate $SSL_CONF
install_if_not ssl-cert
systemctl stop nginx.service && wait
if [ ! -f $SSL_CONF ];
        then
        touch $SSL_CONF
        cat << SSL_CREATE > $SSL_CONF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    
    ## Your website name goes here.
    # server_name example.com;
    ## Your only path reference.
    root $WPATH;
    ## This should be in your http block and if it is, it's not needed here.
    index index.php;
    resolver $GATEWAY;
    
     ## Show real IP behind proxy (change to the proxy IP)
#    set_real_ip_from  $GATEWAY/24;
#    set_real_ip_from  $GATEWAY;
#    set_real_ip_from  2001:0db8::/32;
#    real_ip_header    X-Forwarded-For;
#    real_ip_recursive on;
    
    # certs sent to the client in SERVER HELLO are concatenated in ssl_certificate
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    # Diffie-Hellman parameter for DHE ciphersuites, recommended 4096 bits
    # ssl_dhparam /path/to/dhparam.pem;
    # intermediate configuration. tweak to your needs.
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS';
    ssl_prefer_server_ciphers on;
    # HSTS (ngx_http_headers_module is required) (15768000 seconds = 6 months)
    add_header Strict-Transport-Security max-age=15768000;
    # OCSP Stapling ---
    # fetch OCSP records from URL in ssl_certificate and cache them
    ssl_stapling on;
    ssl_stapling_verify on;
    ## verify chain of trust of OCSP response using Root CA and Intermediate certs
    # ssl_trusted_certificate /path/to/root_CA_cert_plus_intermediates;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;        
    }
    
    location ~ /\\. {
        access_log off;
        log_not_found off; 
        deny all;
    }
    location = /favicon.ico {
                log_not_found off;
                access_log off;
    }
    location = /robots.txt {
                allow all;
                log_not_found off;
                access_log off;
    }
    location ~* \\.php$ {
                #NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                try_files \$uri =404;
                fastcgi_index index.php;
                include fastcgi.conf;
                include fastcgi_params;
                fastcgi_intercept_errors on;
                fastcgi_pass unix:$PHP_FPM_SOCK;
                fastcgi_buffers 16 16k;
                fastcgi_buffer_size 32k;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
     }
     location ~* \\.(js|css|png|jpg|jpeg|gif|ico)$ {
                expires max;
                log_not_found off;
     }
}
SSL_CREATE
print_text_in_color "$IGreen" "$SSL_CONF was successfully created"
sleep 1
fi

# Generate $HTTP_CONF
if [ ! -f $HTTP_CONF ];
        then
        touch $HTTP_CONF
        cat << HTTP_CREATE > $HTTP_CONF
server {
    listen 80;
    listen [::]:80;
    
    ## Your website name goes here.
    # server_name example.com;
    ## Your only path reference.
    root $WPATH;
    ## This should be in your http block and if it is, it's not needed here.
    index index.php;
    resolver $GATEWAY;
    
    ## Show real IP behind proxy (change to the proxy IP)
#    set_real_ip_from  $GATEWAY/24;
#    set_real_ip_from  $GATEWAY;
#    set_real_ip_from  2001:0db8::/32;
#    real_ip_header    X-Forwarded-For;
#    real_ip_recursive on;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;        
    }
    
    location ~ /\\. {
        access_log off;
        log_not_found off; 
        deny all;
    }
    location = /favicon.ico {
                log_not_found off;
                access_log off;
    }
    location = /robots.txt {
                allow all;
                log_not_found off;
                access_log off;
    }
    location ~* \\.php$ {
                #NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                try_files \$uri =404;
                fastcgi_index index.php;
                include fastcgi.conf;
                include fastcgi_params;
                fastcgi_intercept_errors on;
                fastcgi_pass unix:$PHP_FPM_SOCK;
                fastcgi_buffers 16 16k;
                fastcgi_buffer_size 32k;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
     }
     location ~* \\.(js|css|png|jpg|jpeg|gif|ico)$ {
                expires max;
                log_not_found off;
     }
}
HTTP_CREATE
print_text_in_color "$IGreen" "$HTTP_CONF was successfully created"
sleep 1
fi

# Generate $NGINX_CONF
if [ -f $NGINX_CONF ];
        then
        rm $NGINX_CONF
	touch $NGINX_CONF
        cat << NGINX_CREATE > $NGINX_CONF
user www-data;
worker_processes 2;
pid /run/nginx.pid;
	worker_rlimit_nofile 10240;
events {
	worker_connections 10240;
	multi_accept on;
	use epoll;
}
	
http {
	##
	# Basic Settings
	##
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	server_tokens off;
	client_body_timeout   10;
	client_header_timeout 10;
	client_header_buffer_size 128;
        client_max_body_size 10M;
	# server_names_hash_bucket_size 64;
	# server_name_in_redirect off;
	include /etc/nginx/mime.types;
	default_type application/octet-stream;
	##
	# SSL Settings
	##
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;
	##
	# Logging Settings
	##
	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;
	##
	# Gzip Settings
	##
	gzip on;
	gzip_disable "msie6";
	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	  gzip_buffers 16 4k;
	# gzip_http_version 1.1;	
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
	##
	# Virtual Host Configs
	##
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
	upstream php {
        server unix:/run/php/php"$PHPVER"-fpm.sock;
        }
}
#mail {
#	# See sample authentication script at:
#	# http://wiki.nginx.org/ImapAuthenticateWithApachePhpScript
# 
#	# auth_http localhost/auth.php;
#	# pop3_capabilities "TOP" "USER";
#	# imap_capabilities "IMAP4rev1" "UIDPLUS";
# 
#	server {
#		listen     localhost:110;
#		protocol   pop3;
#		proxy      on;
#	}
# 
#	server {
#		listen     localhost:143;
#		protocol   imap;
#		proxy      on;
#	}
#}
NGINX_CREATE
print_text_in_color "$IGreen" "$NGINX_CONF was successfully created"
sleep 1
fi

# Generate $NGINX_CONF
if [ -f "$NGINX_DEF" ];
then
    rm -f $NGINX_DEF
    rm -f /etc/nginx/sites-enabled/default
    touch $NGINX_DEF
    cat << NGINX_DEFAULT > "$NGINX_DEF"
##
# You should look at the following URL's in order to grasp a solid understanding
# of Nginx configuration files in order to fully unleash the power of Nginx.
# http://wiki.nginx.org/Pitfalls
# http://wiki.nginx.org/QuickStart
# http://wiki.nginx.org/Configuration
#
# Generally, you will want to move this file somewhere, and start with a clean
# file but keep this around for reference. Or just disable in sites-enabled.
#
# Please see /usr/share/doc/nginx-doc/examples/ for more detailed examples.
##
# Default server configuration
#
server {
	listen 80 default_server;
	listen [::]:80 default_server;
# Let's Encrypt
        location ~ /.well-known {
	root /usr/share/nginx/html;
	        allow all;
	}
	# SSL configuration
	#
	# listen 443 ssl default_server;
	# listen [::]:443 ssl default_server;
	#
	# Note: You should disable gzip for SSL traffic.
	# See: https://bugs.debian.org/773332
	#
	# Read up on ssl_ciphers to ensure a secure configuration.
	# See: https://bugs.debian.org/765782
	#
	# Self signed certs generated by the ssl-cert package
	# Don't use them in a production server!
	#
	# include snippets/snakeoil.conf;
	root $WWW_ROOT;
	# Add index.php to the list if you are using PHP
	index index.html index.htm index.nginx-debian.html;
	server_name _;
	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		try_files \$uri \$uri/ =404;
	}
}
NGINX_DEFAULT
print_text_in_color "$IGreen" "$NGINX_DEF was successfully created"
sleep 1
fi

# Enable new config
ln -s "$NGINX_DEF" /etc/nginx/sites-enabled/
ln -s "$SSL_CONF" /etc/nginx/sites-enabled/
ln -s "$HTTP_CONF" /etc/nginx/sites-enabled/
systemctl restart nginx.service

# Enable UTF8mb4 (4-byte support)
databases=$(mysql -u root -p"$MARIADB_PASS" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)
for db in $databases; do
    if [[ "$db" != "performance_schema" ]] && [[ "$db" != _* ]] && [[ "$db" != "information_schema" ]];
    then
        print_text_in_color "$ICyan" "Changing to UTF8mb4 on: $db"
        mysql -u root -p"$MARIADB_PASS" -e "ALTER DATABASE $db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    fi
done

