#!/bin/bash

# Install mariadb server and mariadb client

apt-get update
apt-get upgrade -y
apt-get install -y mariadb-server mariadb-client

# Create mylmsdb and its admin mylmsadmin on localhost and on network 192.168.1.x/24

mysql -u root 2> /dev/null <<EOF
CREATE DATABASE IF NOT EXISTS mylmsdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'mylmsadmin'@localhost IDENTIFIED BY "mylmsadminpw";
GRANT ALL PRIVILEGES ON mylmsdb.* TO mylmsadmin@localhost;
CREATE USER 'mylmsadmin'@'192.168.1.%' IDENTIFIED BY "mylmsadminpw";
GRANT ALL PRIVILEGES ON mylmsdb.* TO 'mylmsadmin'@'192.168.1.%';
FLUSH PRIVILEGES;
SHOW DATABASES;
EOF

# Mariadb requirements and allow access on all interfaces

FILE_MYSQL="/etc/mysql/my.cnf"

grep -q "mysqld" "${FILE_MYSQL}"
if [ $? != 0 ] ; then
cat << EOF >> "${FILE_MYSQL}"
[client]
default-character-set = utf8mb4

[mysqld]
innodb_file_format = Barracuda
innodb_file_per_table = ON
innodb_large_prefix = ON
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
bind-address = 0.0.0.0

[mysql]
default-character-set = utf8mb4
EOF
fi

# Restart database service

systemctl restart mysql
