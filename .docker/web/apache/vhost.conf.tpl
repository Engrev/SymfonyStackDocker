<VirtualHost *:80>
    ServerName %%vhost%%
    ServerAlias localhost

    # PHP-FPM via proxy
    <FilesMatch \.php$>
        SetHandler "proxy:fcgi://php:9000"
    </FilesMatch>

    DocumentRoot /var/www/html/public
    <Directory /var/www/html/public>
        AllowOverride None
        Require all granted
        # Use FallbackResource to route all non-existent requests to the front controller
        FallbackResource /index.php
        # Pass the Authorization header to PHP-FPM
        CGIPassAuth On
    </Directory>

    # Disable directory listing
    Options -Indexes

    # Disallow access to hidden files (e.g., .env, .git)
    <Directory /var/www/html/public>
        <FilesMatch "^\.">
            Require all denied
        </FilesMatch>
    </Directory>

    # Logs
    ErrorLog /usr/local/apache2/logs/error.log
    CustomLog /usr/local/apache2/logs/access.log combined

    # Security: Don't reveal version information
    ServerSignature Off
</VirtualHost>
