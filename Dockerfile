FROM ubuntu:24.04

SHELL ["/bin/bash", "-c"]

ARG ENV_NAME

RUN mkdir /var/www && mkdir /var/www/magefine \
&& mkdir /workspace \
&& mkdir /workspace/dumps

RUN rm -f /etc/localtime \
&& ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime

RUN apt update

RUN DEBIAN_FRONTEND=noninteractive apt -y install vim git wget curl make apache2 apt-utils sudo

RUN DEBIAN_FRONTEND=noninteractive apt -y install unzip tar cronie \
autoconf automake zip redis build-essential make procps xvfb libatk1.0-dev libgtk-3-dev gir1.2-gsound-1.0 patch

RUN apt update

RUN apt install -y php php-cli php-fpm php-mysqlnd php-zip php-dev php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json php-opcache php-redis php-memcache php-soap php-intl php-xdebug \
&& apt install -y libpng-dev libjpeg-dev libtiff-dev imagemagick php-imagick

RUN cd /usr/share \
&& wget https://files.phpmyadmin.net/phpMyAdmin/5.1.3/phpMyAdmin-5.1.3-all-languages.zip \
&& unzip phpMyAdmin-5.1.3-all-languages.zip && mv phpMyAdmin-5.1.3-all-languages phpmyadmin \
&& chmod -R 755 /usr/share/phpmyadmin

RUN cd /usr/share/phpmyadmin \
&& cp config.sample.inc.php config.inc.php \
&& sed -i "s/ = 'localhost';/ = '127.0.0.1';/g" config.inc.php

RUN cd /usr/share/phpmyadmin \
&& echo "\$cfg['Lang'] = 'en';" >> config.inc.php \
&& echo "\$cfg['Servers'][\$i]['ssl'] = true;" >> config.inc.php \
&& echo "\$cfg['Servers'][\$i]['ssl_verify'] = false;" >> config.inc.php

RUN sed -i "s/APACHE_RUN_USER=www-data/APACHE_RUN_USER=ubuntu/g" /etc/apache2/envvars \
&& sed -i "s/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=ubuntu/g" /etc/apache2/envvars

RUN echo "xdebug.mode = debug" >> /etc/php/8.3/mods-available/xdebug.ini \
&& echo "xdebug.discover_client_host = 1" >> /etc/php/8.3/mods-available/xdebug.ini

RUN apt install -y mysql-client

RUN curl -s https://getcomposer.org/installer | php \
&& mv composer.phar /usr/bin/composer

RUN cd /usr/share \
&& wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip \
&& unzip phpMyAdmin-5.2.1-all-languages.zip && mv phpMyAdmin-5.2.1-all-languages phpmyadmin \
&& chown -R ubuntu:ubuntu /usr/share/phpmyadmin && chmod -R 755 /usr/share/phpmyadmin

RUN su - ubuntu -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
ENV NVM_DIR="/home/ubuntu/.nvm"
RUN su - ubuntu -c '. "/home/ubuntu/.nvm/nvm.sh" && nvm install 16.15.1 && nvm use 16.15.1 && nvm alias default 16.15.1 && npm install -g npm@9.3.1'

RUN sed -i "s/display_errors = Off/display_errors = On/g" /etc/php/8.3/cli/php.ini \
&& sed -i "s/post_max_size = 8M/post_max_size = 20M/g" /etc/php/8.3/cli/php.ini \
&& sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/g" /etc/php/8.3/cli/php.ini \
&& sed -i "s/memory_limit = 128M/memory_limit = 4096M/g" /etc/php/8.3/cli/php.ini \
&& sed -i "s/max_execution_time = 30/max_execution_time = 300/g" /etc/php/8.3/cli/php.ini \
&& sed -i "s/;error_log = php_errors.log/error_log = php_errors.log/g" /etc/php/8.3/cli/php.ini \
&& sed -i "s/E_ALL & ~E_DEPRECATED & ~E_STRICT/E_ALL/g" /etc/php/8.3/cli/php.ini

RUN sed -i "s/display_errors = Off/display_errors = On/g" /etc/php/8.3/apache2/php.ini \
&& sed -i "s/post_max_size = 8M/post_max_size = 20M/g" /etc/php/8.3/apache2/php.ini \
&& sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/g" /etc/php/8.3/apache2/php.ini \
&& sed -i "s/memory_limit = 128M/memory_limit = 4096M/g" /etc/php/8.3/apache2/php.ini \
&& sed -i "s/max_execution_time = 30/max_execution_time = 300/g" /etc/php/8.3/apache2/php.ini \
&& sed -i "s/;error_log = php_errors.log/error_log = php_errors.log/g" /etc/php/8.3/apache2/php.ini \
&& sed -i "s/E_ALL & ~E_DEPRECATED & ~E_STRICT/E_ALL/g" /etc/php/8.3/apache2/php.ini

RUN sed -i "s/User \${APACHE_RUN_USER}/User ubuntu/g" /etc/apache2/apache2.conf \
&& sed -i "s/Group \${APACHE_RUN_GROUP}/Group ubuntu/g" /etc/apache2/apache2.conf

#RUN chown -R ubuntu:ubuntu /var/lib/php/session \
#&& chmod -R 777 /var/lib/php/session

RUN echo "" >> /etc/apache2/sites-available/000-default.conf \
&& echo "<VirtualHost *:80>" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    ServerAdmin magefine@example.com" >> /etc/apache2/sites-available/000-default.conf \
&& echo "" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    ServerName ${ENV_NAME}.local" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    ServerAlias ${ENV_NAME}.local" >> /etc/apache2/sites-available/000-default.conf \
&& echo "" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    Alias /phpmyadmin \"/usr/share/phpmyadmin/\"" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    " >> /etc/apache2/sites-available/000-default.conf \
&& echo "    <Directory \"/usr/share/phpmyadmin/\">" >> /etc/apache2/sites-available/000-default.conf \
&& echo "        Require all granted" >> /etc/apache2/sites-available/000-default.conf \
&& echo "        AllowOverride All" >> /etc/apache2/sites-available/000-default.conf \
&& echo "        DirectoryIndex index.php" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    </Directory>" >> /etc/apache2/sites-available/000-default.conf \
&& echo "" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    DocumentRoot /var/www/magefine/pub" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    " >> /etc/apache2/sites-available/000-default.conf \
&& echo "    <Directory /var/www/magefine/pub>" >> /etc/apache2/sites-available/000-default.conf \
&& echo "        DirectoryIndex index.php" >> /etc/apache2/sites-available/000-default.conf \
&& echo "        AllowOverride All" >> /etc/apache2/sites-available/000-default.conf \
&& echo "        Require all granted" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    </Directory>" >> /etc/apache2/sites-available/000-default.conf \
&& echo "" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    ErrorLog /var/log/apache2/${ENV_NAME}.local-error_log" >> /etc/apache2/sites-available/000-default.conf \
&& echo "    CustomLog /var/log/apache2/${ENV_NAME}.local-access_log common" >> /etc/apache2/sites-available/000-default.conf \
&& echo "" >> /etc/apache2/sites-available/000-default.conf \
&& echo "</VirtualHost>" >> /etc/apache2/sites-available/000-default.conf

RUN echo "#!/bin/bash" > /entrypoint.sh \
&& echo "" >> /entrypoint.sh \
&& echo "/usr/sbin/crond" >> /entrypoint.sh \
&& echo "" >> /entrypoint.sh \
&& echo "cd /var/www/magefine" >> /entrypoint.sh \
&& echo "rm -rf var/cache/* && chmod -R 777 ." >> /entrypoint.sh \
&& echo "" >> /entrypoint.sh \
&& echo "chown -R ubuntu:ubuntu /var/www/magefine" >> /entrypoint.sh \
&& echo "" >> /entrypoint.sh \
&& echo "apache2ctl -D FOREGROUND" >> /entrypoint.sh \
&& chmod +x /entrypoint.sh

WORKDIR /var/www/magefine

ENTRYPOINT /bin/bash /entrypoint.sh
