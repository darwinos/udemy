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
        "max_execution_time = 120" \
        "max_input_time = 120" \
        "memory_limit = 256M" \
        "date.timezone = 'Europe\/Paris'" \
        "user_ini.cache_ttl = 300" \
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

wget -O /etc/apache2/sites-available/mylms.conf https://raw.githubusercontent.com/darwinos/udemy/master/Opigno/files/mylms.conf

# Download and extract Opigno

mkdir /var/www/mylms
wget -qO - https://ftp.drupal.org/files/projects/opigno_lms-7.x-1.35-core.tar.gz | tar zxv -C /var/www/mylms/ --strip-components 1

# Creates settings file from template

cp /var/www/mylms/sites/default/default.settings.php /var/www/mylms/sites/default/settings.php

# Connexion with database on mydb (resolved via plugin vagrant-hosts)

FILE_SETTINGS="/var/www/mylms/sites/default/settings.php"

grep -q "mylmsdb" "${FILE_SETTINGS}"
if [ $? != 0 ] ; then
cat << EOF >> "${FILE_SETTINGS}"
\$databases['default']['default'] = array(
  'driver' => 'mysql',
  'database' => 'mylmsdb',
  'username' => 'mylmsadmin',
  'password' => 'mylmsadminpw',
  'host' => 'mydb',
  'charset' => 'utf8mb4',
  'collation' => 'utf8mb4_unicode_ci',
);
EOF
fi

# Generate self-signed certificate (for development)

openssl req -nodes -newkey rsa:2048 -keyout /etc/ssl/private/mylmsperso.key -out /etc/ssl/certs/mylmsperso.csr -subj "/C=FR/ST=Ile-de-France/L=Paris/O=OpenSharing/OU=IT/CN=mylms.opensharing.priv/emailAddress=admin@opensharing.priv"
openssl x509 -req -days 365 -in /etc/ssl/certs/mylmsperso.csr -signkey /etc/ssl/private/mylmsperso.key -out /etc/ssl/certs/mylmsperso.crt

# Enable mylms website and SSL/Rewrite modules

a2ensite mylms
a2dissite 000-default
a2enmod rewrite
a2enmod ssl

# Install WKHTML and PDFJS libraries for PDF management

apt-get install -y unzip wkhtmltopdf libcanberra-gtk-module libssl-dev php-uploadprogress

mkdir /var/www/mylms/sites/all/libraries/wkhtmltopdf/
ln -s /usr/bin/wkhtmltopdf /var/www/mylms/sites/all/libraries/wkhtmltopdf/wkhtmltopdf
wget https://github.com/mozilla/pdf.js/releases/download/v2.0.943/pdfjs-2.0.943-dist.zip
unzip pdfjs-2.0.943-dist.zip -d /var/www/mylms/sites/all/libraries/pdf.js/
rm pdfjs-2.0.943-dist.zip

# Fix error Dompdf library

grep -q "print_pdf_dompdf_secure_06" "${FILE_SETTINGS}"
if [ $? != 0 ] ; then
cat << EOF >> "${FILE_SETTINGS}"
\$conf['print_pdf_dompdf_secure_06'] = TRUE;
EOF
fi

# Fix error HTTP request

grep -q "drupal_http_request_fails" "${FILE_SETTINGS}"
if [ $? != 0 ] ; then
cat << EOF >> "${FILE_SETTINGS}"
\$conf['drupal_http_request_fails'] = FALSE;
EOF
fi

# Install TinCanPHP library

mkdir /var/www/mylms/sites/all/libraries/TinCanPHP/
wget -qO - https://github.com/RusticiSoftware/TinCanPHP/archive/1.1.0.tar.gz | tar zxv -C /var/www/mylms/sites/all/libraries/TinCanPHP/  --strip-components 1

# Final fix of permissions and ownerships

chown -R root:www-data /var/www/mylms/
chown -R www-data:www-data /var/www/mylms/sites/
chown -R www-data:www-data /var/www/mylms/profiles/opigno_lms/modules/

# Restart web service

systemctl restart apache2