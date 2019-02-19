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
        "memory_limit = 96M" \
        "file_uploads = On" \
        "date.timezone = 'Europe\/Paris'" \
        "opcache.enable = 1"
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

# Copy mounted web config to guest web directory

wget -O /etc/apache2/sites-available/mylms.conf https://raw.githubusercontent.com/darwinos/udemy/master/Moodle/files/mylms.conf

# Download and extract Moodle

mkdir /var/www/mylms
wget -qO - https://download.moodle.org/download.php/direct/stable36/moodle-latest-36.tgz | tar zxv -C /var/www/mylms/ --strip-components 1

# Generate self-signed certificate (for development)

openssl req -nodes -newkey rsa:2048 -keyout /etc/ssl/private/mylmsperso.key -out /etc/ssl/certs/mylmsperso.csr -subj "/C=FR/ST=Ile-de-France/L=Paris/O=OpenSharing/OU=IT/CN=mylms.opensharing.priv/emailAddress=admin@opensharing.priv"
openssl x509 -req -days 365 -in /etc/ssl/certs/mylmsperso.csr -signkey /etc/ssl/private/mylmsperso.key -out /etc/ssl/certs/mylmsperso.crt

# Enable mylms website and SSL/Rewrite modules

a2ensite mylms
a2dissite 000-default
a2enmod rewrite
a2enmod ssl

# Add moodle user for moodledata / Change ownerships and permissions

adduser --system moodle
mkdir /home/moodle/moodledata
chown -R www-data:www-data /home/moodle/moodledata/
chmod 0777 /home/moodle/moodledata/
chown -R root:www-data /var/www/mylms/
chmod -R 0755 /var/www/mylms/

# Connexion with database on mydb (resolved via plugin vagrant-hosts)

FILE_CONFIG="/var/www/mylms/config.php"

cat << EOF > "${FILE_CONFIG}"
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'mydb';
\$CFG->dbname    = 'mylmsdb';
\$CFG->dbuser    = 'mylmsadmin';
\$CFG->dbpass    = 'mylmsadminpw';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '3306',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot   = 'https://localhost:8443';
\$CFG->dataroot  = '/home/moodle/moodledata';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 0777;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF

# Restart web service

systemctl restart apache2