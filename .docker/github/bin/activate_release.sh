#!/bin/bash
set -euo pipefail

TARGET=$1      # prod | pprod
RELEASE=$2     # nom du dossier release
SKIP_MIGR=${3:-false} # optionnel: true pour sauter migrations

APP_BASE="/home/clients/981fc5351e7e6b9d58350ef0f0987594/sites" # A REMPLACER
APP_PATH="$APP_BASE/<project_name>/$TARGET"
RELEASE_DIR="$APP_PATH/releases/$RELEASE"
SHARED_DIR="$APP_PATH/shared"
CURRENT_LINK="$APP_PATH/current"

if [ ! -d "$RELEASE_DIR" ]; then
    echo "❌ Release not found: $RELEASE_DIR"
    exit 1
fi

# Création shared
mkdir -p "$SHARED_DIR/var/log" "$SHARED_DIR/var/sessions" "$SHARED_DIR/public/uploads" "$RELEASE_DIR/var"

# Liens partagés
ln -sfn "$SHARED_DIR/.env.local" "$RELEASE_DIR/.env.local"
ln -sfn "$SHARED_DIR/var/log" "$RELEASE_DIR/var/log"
ln -sfn "$SHARED_DIR/var/sessions" "$RELEASE_DIR/var/sessions"
ln -sfn "$SHARED_DIR/public/uploads" "$RELEASE_DIR/public/uploads"

cd "$RELEASE_DIR"

# Install PHP deps
/opt/php8.4/bin/php /opt/php8.4/bin/composer2.phar install --no-dev --optimize-autoloader --no-interaction --prefer-dist --classmap-authoritative
/opt/php8.4/bin/php /opt/php8.4/bin/composer2.phar dump-env prod

# (Optionnel) Build front si nécessaire
if [ -f package.json ]; then
    npm ci --silent
    npm run build
fi

# Migrations
if [ "$SKIP_MIGR" != "true" ]; then
    /opt/php8.4/bin/php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration --env=prod
fi

# Cache Symfony
/opt/php8.4/bin/php bin/console cache:clear --env=prod --no-warmup
/opt/php8.4/bin/php bin/console cache:warmup --env=prod

# Activation release
ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"

echo "✅ Release activated: $RELEASE_DIR"
