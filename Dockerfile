# Inherit from Heroku's stack
FROM heroku/heroku:16

# Internally, we arbitrarily use port 3000
ENV PORT 3000

# Which versions?
ENV PHP_VERSION 7.2.0
ENV REDIS_VERSION 3.1.4
ENV HTTPD_VERSION 2.4.20
ENV NGINX_VERSION 1.8.1
ENV COMPOSER_VERSION 1.5.2
ENV NODE_ENGINE 8.8.1

ENV PATH /app/heroku/node/bin:/app/user/node_modules/.bin:$PATH

# Install sudo
RUN apt-get update && apt-get install sudo

# Create some needed directories
RUN mkdir -p /app/.heroku/php /app/heroku/node /app/.profile.d
WORKDIR /app/user

# so we can run PHP in here
ENV PATH /app/.heroku/php/bin:/app/.heroku/php/sbin:$PATH

# Install Apache
RUN curl --silent --location https://lang-php.s3.amazonaws.com/dist-cedar-16-stable/apache-$HTTPD_VERSION.tar.gz | tar xz -C /app/.heroku/php
# Config
RUN curl --silent --location https://raw.githubusercontent.com/heroku/heroku-buildpack-php/5a770b914549cf2a897cbbaf379eb5adf410d464/conf/apache2/httpd.conf.default > /app/.heroku/php/etc/apache2/httpd.conf
# FPM socket permissions workaround when run as root
RUN echo "\n\
Group root\n\
" >> /app/.heroku/php/etc/apache2/httpd.conf

#
#
#
#
# Install Nginx
RUN curl --silent --location https://lang-php.s3.amazonaws.com/dist-cedar-16-stable/nginx-$NGINX_VERSION.tar.gz | tar xz -C /app/.heroku/php
# Config
RUN curl --silent --location https://raw.githubusercontent.com/heroku/heroku-buildpack-php/5a770b914549cf2a897cbbaf379eb5adf410d464/conf/nginx/nginx.conf.default > /app/.heroku/php/etc/nginx/nginx.conf
# FPM socket permissions workaround when run as root
RUN echo "\n\
user nobody root;\n\
" >> /app/.heroku/php/etc/nginx/nginx.conf

#
#
#
#
# Install PHP
RUN curl --silent --location https://lang-php.s3.amazonaws.com/dist-cedar-14-develop/php-$PHP_VERSION.tar.gz | tar xz -C /app/.heroku/php
# Config
RUN mkdir -p /app/.heroku/php/etc/php/conf.d
COPY config/php.ini /app/.heroku/php/etc/php/php.ini
#RUN curl --silent --location https://raw.githubusercontent.com/heroku/heroku-buildpack-php/master/support/build/_conf/php/php.ini > /app/.heroku/php/etc/php/php.ini

#
#
#
#
# Install Redis extension for PHP 7
RUN curl --silent --location https://lang-php.s3.amazonaws.com/dist-cedar-14-develop/extensions/no-debug-non-zts-20170718/redis-$REDIS_VERSION.tar.gz | tar xz -C /app/.heroku/php

# Enable all optional exts
RUN echo "\n\
user_ini.cache_ttl = 30 \n\
opcache.enable_cli = 1 \n\
opcache.validate_timestamps = 1 \n\
opcache.revalidate_freq = 0 \n\
opcache.fast_shutdown = 0 \n\
extension=bcmath.so \n\
extension=calendar.so \n\
extension=exif.so \n\
extension=ftp.so \n\
extension=gd.so \n\
extension=gettext.so \n\
extension=mbstring.so \n\
extension=pcntl.so \n\
extension=redis.so \n\
extension=shmop.so \n\
extension=soap.so \n\
extension=sqlite3.so \n\
extension=pdo_sqlite.so \n\
extension=xmlrpc.so \n\
extension=xsl.so\n\
" >> /app/.heroku/php/etc/php/php.ini

# Enable timestamps validation for opcache for development
RUN sed -i /opcache.validate_timestamps/d /app/.heroku/php/etc/php/conf.d/010-ext-zend_opcache.ini

# Install Composer
RUN curl --silent --location https://lang-php.s3.amazonaws.com/dist-cedar-14-stable/composer-$COMPOSER_VERSION.tar.gz | tar xz -C /app/.heroku/php
RUN composer self-update

# Install Node.js
RUN curl -s https://s3pository.heroku.com/node/v$NODE_ENGINE/node-v$NODE_ENGINE-linux-x64.tar.gz | tar --strip-components=1 -xz -C /app/heroku/node

# Export the node path in .profile.d
RUN echo "export PATH=\"/app/heroku/node/bin:/app/user/node_modules/.bin:\$PATH\"" > /app/.profile.d/nodejs.sh

# Install yarn package manager
RUN npm install --global yarn

# copy dep files first so Docker caches the install step if they don't change
ONBUILD COPY composer.lock /app/user/
ONBUILD COPY composer.json /app/user/
# run install but without scripts as we don't have the app source yet
ONBUILD RUN composer install --no-scripts
# require the buildpack for execution
ONBUILD RUN composer show --installed heroku/heroku-buildpack-php || { echo 'Your composer.json must have "heroku/heroku-buildpack-php" as a "require-dev" dependency.'; exit 1; }
# rest of app
ONBUILD ADD . /app/user/

# Export heroku bin
ENV PATH /app/user/bin:$PATH
