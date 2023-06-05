# FROM ubuntu:20.04
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 libcap2-bin libpng-dev python2 \
    && mkdir -p ~/.gnupg \
    && chmod 600 ~/.gnupg \
    && echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf \
    && apt-key adv --homedir ~/.gnupg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E5267A6C \
    && apt-key adv --homedir ~/.gnupg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C300EE8C \
    && echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu focal main" > /etc/apt/sources.list.d/ppa_ondrej_php.list \
    && apt-get update \
    && apt-get install -y php8.1-cli php8.1-dev \      
        # php8.1-pgsql php8.1-sqlite3 php8.1-gd \ 
        php8.1-curl php8.1-memcached \ 
        php8.1-imap php8.1-mysql php8.1-mbstring \ 
        php8.1-xml php8.1-zip php8.1-bcmath php8.1-soap \ 
        php8.1-intl php8.1-readline \ 
        php8.1-msgpack php8.1-igbinary php8.1-ldap \ 
        php8.1-redis \ 
        php8.1-fpm \
    && php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer \
    && curl -sL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    # && apt-get install -y yarn \
    && apt-get install -y mysql-client \
    && apt-get install -y nginx \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN setcap "cap_net_bind_service=+ep" /usr/bin/php8.1

WORKDIR /var/www/

# Copy project into image.
COPY src/ /var/www/

COPY nginx-default.conf /etc/nginx/sites-enabled/default
COPY nginx-main.conf /etc/nginx/nginx.conf

# the bash script isn't executed but can be useful for debugging
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Install independencies and paackages
RUN composer install
RUN npm install

RUN npm run build

# Set app permission
RUN chown -R www-data:www-data /var/www
RUN chmod -R 775 storage bootstrap/cache

# Clean up
RUN rm -f package.json package-lock.json

## Start Nginx
EXPOSE 80
ENTRYPOINT  service php8.1-fpm start \
    && service nginx start \
    && php artisan migrate:refresh --seed --force \
    && php artisan cache:clear \
    && /usr/bin/php artisan optimize:clear \
    && /usr/bin/php artisan config:cache \
    && tail -f /var/log/nginx/* /var/log/laravel/laravel.log \
    && cp /var/www/public/build/manifest.json /var/www/public/build-manifest.json
