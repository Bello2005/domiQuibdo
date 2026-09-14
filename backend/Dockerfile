FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --optimize-autoloader
COPY . .
RUN composer dump-autoload --optimize --no-dev

FROM php:8.4-cli-alpine
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions \
    && install-php-extensions pdo_pgsql pgsql bcmath mbstring opcache

ENV APP_ENV=production
ENV APP_DEBUG=false
ENV LOG_CHANNEL=stderr

WORKDIR /app
COPY --from=vendor /app ./

EXPOSE 80
CMD ["sh", "-c", "php artisan config:cache; php artisan route:cache; php artisan migrate --force; php artisan serve --host=0.0.0.0 --port=80"]
