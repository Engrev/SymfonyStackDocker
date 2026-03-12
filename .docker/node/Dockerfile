FROM node:20-alpine

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN apk add --no-cache bash shadow && \
    (getent group www-data && groupdel www-data || true) && \
    usermod -u ${USER_ID} -d /home/www-data -m -l www-data node && \
    groupmod -g ${GROUP_ID} -n www-data node

WORKDIR /var/www/html

RUN mkdir -p /var/www/html/node_modules /home/www-data/.npm && \
    chown -R www-data:www-data /var/www/html /home/www-data

RUN corepack enable

USER www-data

CMD ["bash"]
