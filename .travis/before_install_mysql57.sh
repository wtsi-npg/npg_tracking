#!/bin/bash

set -e -x

sudo apt-key add ./.travis/mysql_pubkey.asc # Import public key for MySQL
sudo apt-get remove --purge "^mysql.*"
sudo apt-get autoremove
sudo apt-get autoclean

# If not deleted and corrupted/not compatible may not let the server start
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/log/mysql

# Get MySQL packages and their dependencies
sudo -E apt-get install libaio1 apparmor libmecab2
MYSQL_DOWNLOAD_URL_ROOT='https://downloads.mysql.com/archives/get/p/23/file'
wget "$MYSQL_DOWNLOAD_URL_ROOT/mysql-common_5.7.13-1ubuntu16.04_amd64.deb"
wget "$MYSQL_DOWNLOAD_URL_ROOT/mysql-community-client_5.7.13-1ubuntu16.04_amd64.deb"
wget "$MYSQL_DOWNLOAD_URL_ROOT/mysql-client_5.7.13-1ubuntu16.04_amd64.deb"
wget "$MYSQL_DOWNLOAD_URL_ROOT/mysql-community-server_5.7.13-1ubuntu16.04_amd64.deb"
wget "$MYSQL_DOWNLOAD_URL_ROOT/mysql-server_5.7.13-1ubuntu16.04_amd64.deb"

sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password \"''\""
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password \"''\""
sudo dpkg-preconfigure mysql-community-server_5.7.13-1ubuntu12.04_amd64.deb  
sudo dpkg -i mysql-{common,community-client,client,community-server,server}_*.deb
sudo -E apt-get -q -y install libmysqlclient-dev libdbd-mysql-perl

sudo /etc/init.d/mysql stop
sleep 5
# Start the server without password
sudo mysqld --user=root --skip-grant-tables --explicit_defaults_for_timestamp=false --sql-mode="STRICT_TRANS_TABLES" &

#Give some time for server to start
sleep 10

# print versions
mysql --version
mysql -h localhost -e "SELECT @@GLOBAL.sql_mode; SELECT @@SESSION.sql_mode; SHOW GLOBAL VARIABLES LIKE '%version%'; show variables like '%time%';" -uroot

