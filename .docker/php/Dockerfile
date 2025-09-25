ARG PHP_VERSION=8.2
ARG USER_ID=1000
ARG GROUP_ID=1000
FROM php:${PHP_VERSION}-fpm-alpine

RUN echo "Building with USER_ID=${USER_ID}, GROUP_ID=${GROUP_ID}, PHP_VERSION=${PHP_VERSION}"

# Install system dependencies and PHP extensions common for Symfony
RUN set -eux; \
    apk update; \
    apk add --no-cache \
        bash git curl wget icu-dev libzip-dev zlib-dev oniguruma-dev libpng-dev libjpeg-turbo-dev freetype-dev \
        libxml2-dev imagemagick imagemagick-dev libpq-dev mysql-dev autoconf g++ make openssl-dev libsodium-dev \
        linux-headers pkgconf shadow $PHPIZE_DEPS; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-configure intl; \
    docker-php-ext-install -j"$(nproc)" \
        intl mbstring zip gd xml pdo pdo_mysql pdo_pgsql opcache sodium bcmath; \
    pecl install xdebug && docker-php-ext-enable xdebug; \
    pecl install imagick && docker-php-ext-enable imagick; \
    pecl install redis && docker-php-ext-enable redis; \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer; \
    curl -sS https://get.symfony.com/cli/installer | bash -s -- --install-dir=/usr/local/bin; \
    mkdir -p /composer/cache; \
    apk del --no-cache autoconf g++ make linux-headers pkgconf $PHPIZE_DEPS; \
    rm -rf /tmp/* /var/cache/apk/* /usr/src/php*

ARG USER_ID
ARG GROUP_ID
RUN set -eux; \
    TARGET_USER_ID=${USER_ID:-1000}; \
    TARGET_GROUP_ID=${GROUP_ID:-1000}; \
    echo "Configuring user with UID=${TARGET_USER_ID}, GID=${TARGET_GROUP_ID}"; \
    if getent group www-data > /dev/null 2>&1; then \
        echo "Group www-data exists, modifying it"; \
        groupmod -g $TARGET_GROUP_ID www-data || echo "Group ID modification failed or already correct"; \
    else \
        echo "Creating group www-data with GID $TARGET_GROUP_ID"; \
        addgroup -g $TARGET_GROUP_ID www-data; \
    fi; \
    if getent passwd www-data > /dev/null 2>&1; then \
        echo "User www-data exists, modifying it"; \
        usermod -u $TARGET_USER_ID -g $TARGET_GROUP_ID -s /bin/bash www-data || echo "User modification failed or already correct"; \
        mkdir -p /home/www-data; \
        chown $TARGET_USER_ID:$TARGET_GROUP_ID /home/www-data; \
    else \
        echo "Creating user www-data with UID $TARGET_USER_ID"; \
        adduser -D -u $TARGET_USER_ID -G www-data -s /bin/bash www-data; \
    fi; \
    chown -R $TARGET_USER_ID:$TARGET_GROUP_ID /composer; \
    echo "User configuration completed"

# Configuration PHP via ini files
COPY .docker/php/conf/php.ini /usr/local/etc/php/conf.d/zz-symfony.ini
COPY .docker/php/conf/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# Définir le répertoire de travail
WORKDIR /var/www/html

# S'assurer que les répertoires Symfony ont les bonnes permissions
RUN mkdir -p var/cache var/log public/uploads && \
    chown -R www-data:www-data var public && \
    chmod -R 755 var public

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php-fpm -t || exit 1

# Utiliser l'utilisateur non-root
USER www-data

# Définir bash comme shell par défaut pour les commandes interactives
SHELL ["/bin/bash", "-c"]

# Exposer le port PHP-FPM
EXPOSE 9000
