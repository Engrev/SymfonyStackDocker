ARG PHP_VERSION
FROM php:${PHP_VERSION}-fpm-bookworm

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN echo "Building with USER_ID=${USER_ID}, GROUP_ID=${GROUP_ID}, PHP_VERSION=${PHP_VERSION}"

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git unzip zip \
    libzip-dev libpng-dev libjpeg62-turbo-dev libwebp-dev \
    libfreetype6-dev libicu-dev libxml2-dev \
    libpq-dev libmariadb-dev-compat libssl-dev \
    libonig-dev libsodium-dev \
    acl procps \
    libfcgi-bin \
    && rm -rf /var/lib/apt/lists/*

# Adjust www-data ID to match host user (prevents permission conflicts)
RUN usermod -u ${USER_ID} -s /bin/bash www-data && groupmod -g ${GROUP_ID} www-data

# PHP Extensions
RUN docker-php-ext-configure gd \
    --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo pdo_mysql pdo_pgsql \
        zip gd intl opcache \
        xml mbstring sodium \
        bcmath pcntl sockets \
    && pecl install apcu xdebug redis \
    && docker-php-ext-enable apcu xdebug redis

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN curl -fsSL https://get.symfony.com/cli/installer | bash -s -- --install-dir=/usr/local/bin

# PHP configuration via ini files
COPY .docker/php/conf/php.ini /usr/local/etc/php/conf.d/99-symfony.ini
COPY .docker/php/conf/opcache.ini /usr/local/etc/php/conf.d/98-opcache.ini
COPY .docker/php/conf/apcu.ini /usr/local/etc/php/conf.d/97-apcu.ini
COPY .docker/php/conf/xdebug.ini /usr/local/etc/php/conf.d/96-xdebug.ini

WORKDIR /var/www/html

RUN chown -R www-data:www-data /var/www

RUN echo "ping.path = /ping" >> /usr/local/etc/php-fpm.d/zz-docker.conf

USER www-data

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1

# Expose PHP-FPM port
EXPOSE 9000

CMD ["php-fpm"]
