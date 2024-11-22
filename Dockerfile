FROM centos:7

ARG ENV_NAME

RUN useradd -m magefine

RUN mkdir /var/www && mkdir /var/www/magefine \
&& mkdir /workspace \
&& mkdir /workspace/dumps

RUN rm -f /etc/localtime \
&& ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime

RUN sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo \
&& sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo \
&& sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo

RUN yum update -y \
&& yum -y install https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm \
&& yum -y install https://rpms.remirepo.net/enterprise/remi-release-7.rpm \
&& yum install -y vim git wget curl make httpd yum-utils sudo \
&& yum update

RUN yum-config-manager --disable 'remi-php*' \
&& yum-config-manager --enable remi-php81 \
&& yum repolist

RUN yum -y install php php-{cli,fpm,mysqlnd,zip,devel,gd,mbstring,curl,xml,pear,bcmath,json,opcache,redis,memcache,soap,intl,xdebug} \
&& yum -y install ImageMagick ImageMagick-devel php81-php-pecl-imagick Xvfb atk gtk3 gsound patch

RUN yum install -y unzip tar cronie \
autoconf automake zip redis gcc-c++ make mod_ssl pkill

RUN echo "xdebug.mode = debug" >> /etc/php.d/15-xdebug.ini \
&& echo "xdebug.discover_client_host = 1" >> /etc/php.d/15-xdebug.ini

RUN yum install -y mysql

RUN curl -s https://getcomposer.org/installer | php \
&& mv composer.phar /usr/bin/composer

RUN cd /usr/share \
&& wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip \
&& unzip phpMyAdmin-5.2.1-all-languages.zip && mv phpMyAdmin-5.2.1-all-languages phpmyadmin \
&& chown -R apache:apache /usr/share/phpmyadmin && chmod -R 755 /usr/share/phpmyadmin

RUN cd /usr/share/phpmyadmin \
&& cp config.sample.inc.php config.inc.php \
&& sed -i "s/ = 'localhost';/ = '${ENV_NAME}_mysql';/g" config.inc.php

RUN cd /usr/share/phpmyadmin \
&& echo "\$cfg['Lang'] = 'en';" >> config.inc.php \
&& echo "\$cfg['Servers'][\$i]['ssl'] = true;" >> config.inc.php \
&& echo "\$cfg['Servers'][\$i]['ssl_verify'] = false;" >> config.inc.php

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
RUN source /root/.bashrc && nvm install 16.15.1 && nvm install-latest-npm

RUN sed -i "s/display_errors = Off/display_errors = On/g" /etc/php.ini \
&& sed -i "s/post_max_size = 8M/post_max_size = 20M/g" /etc/php.ini \
&& sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/g" /etc/php.ini \
&& sed -i "s/memory_limit = 128M/memory_limit = 4096M/g" /etc/php.ini \
&& sed -i "s/max_execution_time = 30/max_execution_time = 300/g" /etc/php.ini \
&& sed -i "s/;error_log = php_errors.log/error_log = php_errors.log/g" /etc/php.ini \
&& sed -i "s/E_ALL & ~E_DEPRECATED & ~E_STRICT/E_ALL/g" /etc/php.ini

RUN sed -i "s/User apache/User magefine/g" /etc/httpd/conf/httpd.conf \
&& sed -i "s/Group apache/Group magefine/g" /etc/httpd/conf/httpd.conf

RUN sed -i "s/IncludeOptional conf.d\/*.conf/IncludeOptional conf.d\/vhost.conf/g" /etc/httpd/conf/httpd.conf

RUN chown -R magefine:magefine /var/lib/php/session \
&& chmod -R 777 /var/lib/php/session

RUN head -n -162 /etc/httpd/conf.d/ssl.conf > /etc/httpd/conf.d/ssl-out.conf \
&& mv /etc/httpd/conf.d/ssl-out.conf /etc/httpd/conf.d/ssl.conf

RUN echo "" >> /etc/httpd/conf.d/ssl.conf \
&& echo "<VirtualHost *:80>" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    ServerAdmin magefine@example.com" >> /etc/httpd/conf.d/ssl.conf \
&& echo "" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    ServerName ${ENV_NAME}.local" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    ServerAlias ${ENV_NAME}.local" >> /etc/httpd/conf.d/ssl.conf \
&& echo "" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    Alias /phpmyadmin \"/usr/share/phpmyadmin/\"" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    " >> /etc/httpd/conf.d/ssl.conf \
&& echo "    <Directory \"/usr/share/phpmyadmin/\">" >> /etc/httpd/conf.d/ssl.conf \
&& echo "        Require all granted" >> /etc/httpd/conf.d/ssl.conf \
&& echo "        AllowOverride All" >> /etc/httpd/conf.d/ssl.conf \
&& echo "        DirectoryIndex index.php" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    </Directory>" >> /etc/httpd/conf.d/ssl.conf \
&& echo "" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    DocumentRoot /var/www/magefine/pub" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    " >> /etc/httpd/conf.d/ssl.conf \
&& echo "    <Directory /var/www/magefine/pub>" >> /etc/httpd/conf.d/ssl.conf \
&& echo "        DirectoryIndex index.php" >> /etc/httpd/conf.d/ssl.conf \
&& echo "        AllowOverride All" >> /etc/httpd/conf.d/ssl.conf \
&& echo "        Require all granted" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    </Directory>" >> /etc/httpd/conf.d/ssl.conf \
&& echo "" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    ErrorLog /var/log/httpd/${ENV_NAME}.local-error_log" >> /etc/httpd/conf.d/ssl.conf \
&& echo "    CustomLog /var/log/httpd/${ENV_NAME}.local-access_log common" >> /etc/httpd/conf.d/ssl.conf \
&& echo "" >> /etc/httpd/conf.d/ssl.conf \
&& echo "</VirtualHost>" >> /etc/httpd/conf.d/ssl.conf

RUN echo "#!/bin/bash" > /entrypoint.sh \
&& echo "" >> /entrypoint.sh \
&& echo "/usr/sbin/crond" >> /entrypoint.sh \
&& echo "" >> /entrypoint.sh \
&& echo "cd /var/www/magefine" >> /entrypoint.sh \
&& echo "rm -rf var/cache/* && chmod -R 777 ." >> /entrypoint.sh \
&& echo "" >> /entrypoint.sh \
&& echo "chown -R magefine:magefine /var/www/magefine" >> /entrypoint.sh \
&& echo "" >> /entrypoint.sh \
&& echo "/usr/sbin/httpd -D FOREGROUND" >> /entrypoint.sh \
&& chmod +x /entrypoint.sh

WORKDIR /var/www/magefine

ENTRYPOINT /bin/bash /entrypoint.sh

