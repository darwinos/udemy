#!/bin/bash

# Install Apache/PHP

apt-get update
apt-get upgrade -y
apt-get install -y apache2 apache2-doc
apt-get install -y php \
				   php-apcu \
				   php-bz2 \
				   php-curl \
				   php-fpm \
				   php-gd \
				   php-geoip \
				   php-gmp \
				   php-intl \
				   php-ldap \
				   php-mbstring \
				   php-mcrypt \
				   php-memcached \
				   php-msgpack \
				   php-mysql \
				   php-pear \
				   php-soap \
				   php-xml \
				   php-xmlrpc \
				   php-zip

# Extract installed PHP version
				   
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1-3)

# Settings Opcache

OPCACHESET=(
		"opcache.memory_consumption=128" \
		"opcache.interned_strings_buffer=8"	\
		"opcache.max_accelerated_files=32531" \
		"opcache.revalidate_freq=60" \
		"opcache.fast_shutdown=1" \
		"opcache.enable_cli=1" \
		)

FILE_OPCACHE="/etc/php/${PHP_VERSION}/mods-available/opcache.ini"
		
for SETTING in "${OPCACHESET[@]}"
do
  PARAM=$(echo "${SETTING}" | cut -d"=" -f1)
  grep -q "${PARAM}" "${FILE_OPCACHE}"
  if [ $? == 0 ] ; then sed -i "s/.*${PARAM}.*/${SETTING}/" "${FILE_OPCACHE}"
  else echo "${SETTING}" >> "${FILE_OPCACHE}"
  fi
done

# Settings PHP
		
PHPSET=(
        "max_execution_time = 300"        \
        "max_input_time = 600"            \
        "post_max_size = 100M"             \
        "upload_max_filesize = 100M"             \
        "date.timezone = 'Europe\/Paris'" \
        "session.cookie_httponly = On"		\
        "opcache.enable = 1" \
      )

FILE_PHP="/etc/php/${PHP_VERSION}/apache2/php.ini"

for SETTING in "${PHPSET[@]}"
do
  PARAM=$(echo "${SETTING}" | cut -d"=" -f1)
  grep -q "${PARAM}" "${FILE_PHP}"
  if [ $? == 0 ] ; then sed -i "s/.*${PARAM}.*/${SETTING}/" "${FILE_PHP}"
  else echo "${SETTING}" >> "${FILE_PHP}"
  fi
done

# Copy remote web config to guest web directory

wget -O /etc/apache2/sites-available/mylms.conf https://raw.githubusercontent.com/darwinos/udemy/master/Chamilo/files/mylms.conf

# Download and extract Chamilo

apt-get install -y python-xapian libxapian-dev
mkdir /var/www/mylms
wget -qO - https://github.com/chamilo/chamilo-lms/releases/download/v1.11.8/chamilo-1.11.8-php7.tar.gz | tar zxv -C /var/www/mylms/ --strip-components 1

# Generate self-signed certificate (for development)

openssl req -nodes -newkey rsa:2048 -keyout /etc/ssl/private/mylmsperso.key -out /etc/ssl/certs/mylmsperso.csr -subj "/C=FR/ST=Ile-de-France/L=Paris/O=OpenSharing/OU=IT/CN=mylms.opensharing.priv/emailAddress=admin@opensharing.priv"
openssl x509 -req -days 365 -in /etc/ssl/certs/mylmsperso.csr -signkey /etc/ssl/private/mylmsperso.key -out /etc/ssl/certs/mylmsperso.crt

# Enable mylms website and SSL/Rewrite modules

a2ensite mylms
a2dissite 000-default
a2enmod rewrite
a2enmod ssl

# Final fix of permissions and ownerships

chown -R root:www-data /var/www/mylms/
chmod -R g+w /var/www/mylms/{app,main,web}

# Restart web service

systemctl restart apache2