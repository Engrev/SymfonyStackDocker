FROM nginx:1.25-alpine

# Ajouter les packages nécessaires pour le debugging et la sécurité
RUN apk add --no-cache curl

# Créer la structure de répertoires nécessaire
# Améliorer la configuration par défaut de Nginx
RUN mkdir -p /var/www/html/public && \
    chown -R nginx:nginx /var/www/html && \
    sed -i 's/worker_processes  auto;/worker_processes  1;/' /etc/nginx/nginx.conf && \
    sed -i 's/worker_connections  1024;/worker_connections  2048;/' /etc/nginx/nginx.conf

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://${VHOST}:${WEB_PORT}/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
