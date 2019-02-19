#!/bin/bash

apt-get update
apt-get upgrade -y

FILE_HOSTS="/etc/hosts"

grep -q "mylms" "${FILE_HOSTS}"
if [ $? != 0 ] ; then
cat << EOF >> "${FILE_HOSTS}"
127.0.0.1       localhost.localdomain                   localhost
192.168.1.10    mylms.opensharing.priv                  mylms
192.168.1.11    mydb.opensharing.priv                   mydb
EOF
fi