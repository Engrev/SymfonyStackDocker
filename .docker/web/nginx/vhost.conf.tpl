server {
    listen 80;
    server_name %%vhost%% localhost;

    root /var/www/html/public;
    index index.php index.html;

    # Logs
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Assets statiques
    location ~* \.(ico|css|js|gif|jpeg|jpg|png|webp|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # Symfony front controller
    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass   php:9000;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;

        fastcgi_param  SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param  DOCUMENT_ROOT   $realpath_root;
        fastcgi_param  HTTPS           off;

        # Timeouts
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;

        internal;
    }

    # Bloquer les .php autres que index.php
    location ~ \.php$ {
        return 404;
    }

    # Bloquer les fichiers cachés
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
