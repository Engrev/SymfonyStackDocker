ServerName ##vhost##

ServerTokens Prod
ServerSignature Off

DocumentRoot "/var/www/html/public"
<Directory "/var/www/html/public">
    AllowOverride All
    Require all granted
    Options -Indexes +FollowSymLinks
    DirectoryIndex index.php
    # Fallback to index.php for front controller
    FallbackResource /index.php
</Directory>

# Deny access to hidden files and sensitive resources
<Directory "/var/www/html">
    <FilesMatch "^(\.env.*|composer\.(json|lock))$">
        Require all denied
    </FilesMatch>
</Directory>

# PHP-FPM via FastCGI
<FilesMatch "\.(php)$">
    SetHandler "proxy:fcgi://php:9000"
</FilesMatch>

# Compression and caching for static assets
AddOutputFilterByType DEFLATE text/plain text/html text/xml text/css application/xml application/xhtml+xml application/rss+xml application/javascript application/x-javascript
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType image/svg+xml "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresDefault "access plus 7 days"
</IfModule>

ErrorLog "/proc/self/fd/2"
CustomLog "/proc/self/fd/1" combined
