#!/bin/bash

#service nginx start && service php8.0-fpm start && tail -f /var/log/nginx/*

php artisan migrate:refresh --seed
php artisan cache:clear

    service php8.1-fpm reload \
    && nginx reload \
    && /usr/bin/php artisan optimize:clear \
    && /usr/bin/php artisan config:cache \
    && tail -f /var/log/nginx/*

# the bash script isn't executed but can be useful for debugging

# for newly deplyed app:
#    php artisan migrate:refresh --seed
#    php artisan cache:clear
