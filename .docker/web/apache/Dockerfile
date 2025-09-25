FROM httpd:2.4-alpine

# Installer curl pour les health checks
RUN apk add --no-cache curl

# Enable required modules and include our vhost
RUN set -eux \
 && sed -i 's/^#LoadModule rewrite_module/LoadModule rewrite_module/' /usr/local/apache2/conf/httpd.conf \
 && sed -i 's/^#LoadModule deflate_module/LoadModule deflate_module/' /usr/local/apache2/conf/httpd.conf \
 && sed -i 's/^#LoadModule headers_module/LoadModule headers_module/' /usr/local/apache2/conf/httpd.conf \
 && sed -i 's/^#LoadModule expires_module/LoadModule expires_module/' /usr/local/apache2/conf/httpd.conf \
 && sed -i 's/^#LoadModule proxy_module/LoadModule proxy_module/' /usr/local/apache2/conf/httpd.conf \
 && sed -i 's/^#LoadModule proxy_fcgi_module/LoadModule proxy_fcgi_module/' /usr/local/apache2/conf/httpd.conf \
 && echo 'Include conf/extra/symfony.conf' >> /usr/local/apache2/conf/httpd.conf \
 && mkdir -p /var/www/html/public \
 && chown -R www-data:www-data /var/www/html 2>/dev/null || chown -R daemon:daemon /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://${VHOST}:${WEB_PORT}/ || exit 1

EXPOSE 80

CMD ["httpd-foreground"]
