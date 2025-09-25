server {
    listen 80;
    server_name ##vhost##;

    root /var/www/html/public;
    index index.php index.html;

    # Gzip & general performance
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;
    gzip_min_length 256;

    # Security: deny access to hidden files and sensitive dirs
    location ~ /\.(?!well-known).* { deny all; }
    location ~* /(?:app|var|vendor)/ { deny all; }

    # Static assets caching
    location ~* \.(?:ico|gif|jpe?g|png|svg|css|js|woff2?|ttf|eot|otf)$ {
        expires 1M;
        add_header Cache-Control "public, max-age=2592000, immutable";
        try_files $uri =404;
    }

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PHP_VALUE "realpath_cache_size=4096k\nrealpath_cache_ttl=600";
        fastcgi_pass php:9000;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
        include /etc/nginx/fastcgi.conf;
    }

    # Deny direct access to composer and env files
    location ~ /(composer\.(json|lock)|\.env.*)$ {
        deny all;
    }
}
