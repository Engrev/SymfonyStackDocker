ARG PHP_VERSION
FROM php:${PHP_VERSION}-fpm-alpine

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN echo "Building with USER_ID=${USER_ID}, GROUP_ID=${GROUP_ID}, PHP_VERSION=${PHP_VERSION}"

# Install system dependencies and PHP extensions common for Symfony
RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        icu-dev \
        libzip-dev \
        oniguruma-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libxml2-dev \
        postgresql-dev \
        mariadb-dev \
        openssl-dev \
        libsodium-dev \
        linux-headers \
        shadow; \
    \
    apk add --no-cache \
        bash \
        git \
        curl \
        wget \
        fcgi \
        icu-data-full \
        libzip \
        libpng \
        libjpeg-turbo \
        freetype \
        libxml2 \
        libpq \
        mariadb-connector-c; \
    \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-configure intl; \
    docker-php-ext-install -j"$(nproc)" \
        intl \
        mbstring \
        zip \
        gd \
        xml \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        opcache \
        sodium \
        bcmath; \
    \
    pecl install xdebug redis apcu; \
    docker-php-ext-enable xdebug redis apcu; \
    \
    TARGET_USER_ID=${USER_ID:-1000}; \
    TARGET_GROUP_ID=${GROUP_ID:-1000}; \
    if getent group www-data > /dev/null 2>&1; then \
        groupmod -g $TARGET_GROUP_ID www-data; \
    else \
        addgroup -g $TARGET_GROUP_ID www-data; \
    fi; \
    if getent passwd www-data > /dev/null 2>&1; then \
        usermod -u $TARGET_USER_ID -g $TARGET_GROUP_ID -s /bin/bash www-data; \
    else \
        adduser -D -u $TARGET_USER_ID -G www-data -s /bin/bash www-data; \
    fi; \
    mkdir -p /home/www-data /composer/cache; \
    chown -R $TARGET_USER_ID:$TARGET_GROUP_ID /home/www-data /composer; \
    apk del .build-deps shadow; \
    rm -rf /tmp/* /var/cache/apk/* /usr/src/php*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN curl -sS https://get.symfony.com/cli/installer | bash -s -- --install-dir=/usr/local/bin

RUN echo "ping.path = /ping" >> /usr/local/etc/php-fpm.d/zz-docker.conf

# Configuration PHP via ini files
COPY .docker/php/conf/php.ini /usr/local/etc/php/conf.d/zz-symfony.ini
COPY .docker/php/conf/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini
COPY .docker/php/conf/apcu.ini /usr/local/etc/php/conf.d/apcu.ini

# Définir le répertoire de travail
WORKDIR /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1

# Utiliser l'utilisateur non-root
USER www-data

# Définir bash comme shell par défaut pour les commandes interactives
SHELL ["/bin/bash", "-c"]

# Exposer le port PHP-FPM
EXPOSE 9000
