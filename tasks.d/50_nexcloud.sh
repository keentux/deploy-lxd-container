#!/bin/bash

# This is a script for managing lxd container
#
# Copyright 2022 Valentin LEFEBVRE
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

ROOT_PASSWORD="PASSWORD_TO_CHANGE"

case "$2" in
    $CONTAINER_DISTRO_SUSE)
        echo_warning "not implemented for opensuse distro"
        ;;
    $CONTAINER_DISTRO_DEBIAN | $CONTAINER_DISTRO_UBUNTU)
        # Execute mysql secure execution
        # see: https://github.com/twitter-forks/mysql/blob/master/scripts/mysql_secure_installation.sh
        lxc exec ${1} --  sh -c 'echo -e "\ny\ny\n${ROOT_PASSWORD}\n${ROOT_PASSWORD}\ny\ny\ny\ny\n" | mysql_secure_installation'
        # Create nextcloud database and user
        lxc exec ${1} -- mysql -u root -e "CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'password';"
        # Mybe flush priviledges here
        lxc exec ${1} -- mysql -u root -e "CREATE DATABASE nextcloud;"
        lxc exec ${1} -- mysql -u root -e "ALTER USER 'nextcloud'@'localhost' IDENTIFIED BY 'password';"
        lxc exec ${1} -- mysql -u root -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"
        lxc exec ${1} -- mysql -u root -e "FLUSH PRIVILEGES;"
        # Set php variables -- version 7.3 should be modified in case of update
        lxc exec ${1} -- sh -c 'echo ";***" >> /etc/php/7.4/apache2/php.ini'
        lxc exec ${1} -- sh -c 'echo ";Variables for nextcloud" >> /etc/php/7.4/apache2/php.ini'
        lxc exec ${1} -- sh -c 'echo ";***" >> /etc/php/7.4/apache2/php.ini'
        lxc exec ${1} -- sh -c 'echo "date.timezone = Europe/Paris" >> /etc/php/7.4/apache2/php.ini'
        lxc exec ${1} -- sh -c 'echo "memory_limit = 512M" >> /etc/php/7.4/apache2/php.ini'
        lxc exec ${1} -- sh -c 'echo "upload_max_filesize = 500M" >> /etc/php/7.4/apache2/php.ini'
        lxc exec ${1} -- sh -c 'echo "post_max_size = 500M" >> /etc/php/7.4/apache2/php.ini'
        lxc exec ${1} -- sh -c 'echo "max_execution_time = 300" >> /etc/php/7.4/apache2/php.ini'
        lxc exec ${1} -- systemctl restart apache2
        # install nextcloud
        lxc exec ${1} -- wget https://download.nextcloud.com/server/releases/latest.zip
        lxc exec ${1} -- unzip latest.zip
        lxc exec ${1} -- rm -rf latest.zip
        lxc exec ${1} -- mv nextcloud /var/www/html/
        lxc exec ${1} -- chown -R www-data:www-data /var/www/html/nextcloud
        lxc exec ${1} -- chmod -R 755 /var/www/html/nextcloud
        # Create apache virtual conf
        lxc exec ${1} -- sh -c 'echo "<VirtualHost *:80>" > /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    ServerAdmin admin@example.com" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    DocumentRoot /var/www/html/nextcloud" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    ServerName example.com" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    ServerAlias www.example.com" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    <Directory /var/www/html/nextcloud/>" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "        Options FollowSymlinks" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "        AllowOverride All" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "        Require all granted" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    </Directory>" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    ErrorLog ${APACHE_LOG_DIR}/error.log" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    CustomLog ${APACHE_LOG_DIR}/access.log combined" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    <Directory /var/www/html/nextcloud/>" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "        RewriteEngine on" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "        RewriteBase /" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "        RewriteCond %{REQUEST_FILENAME} !-f" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "        RewriteRule ^(.*) index.php [PT,L]" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "    </Directory>" >> /etc/apache2/sites-available/nextcloud.conf'
        lxc exec ${1} -- sh -c 'echo "</VirtualHost>" >> /etc/apache2/sites-available/nextcloud.conf'
        # Disable default Apache server configuration
        lxc exec ${1} -- a2dissite 000-default.conf
        lxc exec ${1} -- a2ensite nextcloud.conf
        lxc exec ${1} -- a2enmod headers rewrite env dir mime
        lxc exec ${1} -- systemctl restart apache2
        local ip_addr=$(get_container_ip ${1})
        echo_info "nextcloud well installed on $1, go to http://$ip_addr"
        ;;
    $CONTAINER_DISTRO_CENTOS | $CONTAINER_DISTRO_FEDORA)
        echo_warning "not implemented for redhat based distro"
        ;;
    *)
        echo_error "Unknown distro to install packages"
        ;;
esac