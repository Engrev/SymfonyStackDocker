<VirtualHost *:80>
    ServerName %%vhost%%
    ServerAlias localhost
    DocumentRoot /var/www/html/public

    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
        Options -Indexes +FollowSymLinks

        # Symfony front controller
        DirectoryIndex index.php
        FallbackResource /index.php
    </Directory>

    # Logs
    ErrorLog  /usr/local/apache2/logs/error.log
    CustomLog /usr/local/apache2/logs/access.log combined

    # PHP-FPM via proxy
    <FilesMatch \.php$>
        SetHandler "proxy:fcgi://php:9000"
    </FilesMatch>
</VirtualHost>
