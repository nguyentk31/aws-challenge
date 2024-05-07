#!/bin/bash 
apt update -y 
apt install php libapache2-mod-php php-mysql -y
apt install -y apache2 wget unzip
apt install mysql-server -y
wget --no-check-certificate 'https://drive.google.com/uc?export=download&id=1hhRje0ccz1J4PERTnHjDTnX5KGIdcAAP' -O html.zip
unzip html.zip -d /var/www/html/
rm /var/www/html/index.html
mysqladmin -u root password r00tPassword
mysqladmin -u root -p create student
systemctl restart mysql.service
MYSQL_USER="root"
MYSQL_PASSWORD="r00tPassword"
DATABASE_NAME="student"
NEW_USER="user"
NEW_USER_PASSWORD="myP4ssword"
SQL_COMMAND_1="CREATE USER IF NOT EXISTS '$NEW_USER'@'localhost' IDENTIFIED BY '$NEW_USER_PASSWORD';
GRANT ALL PRIVILEGES ON $DATABASE_NAME.* TO '$NEW_USER'@'localhost';
FLUSH PRIVILEGES;"
echo "$SQL_COMMAND_1" | mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD"
SQL_COMMAND_2="Create database $DATABASE_NAME";
echo "$SQL_COMMAND_2" | mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD"
chmod 766 /var/www/html/config.php
