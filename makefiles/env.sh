#!/usr/bin/env bash
## ════════════════════════════════════════════════════════════════
##  env.sh — Environment variable configuration
##  Generates the .env.docker file interactively
## ════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Couleurs ─────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'

# ── Helpers ───────────────────────────────────────────────────────
success() { printf "${GREEN}✅ %b\n" "$1"; }
warning() { printf "${YELLOW}⚠️ %b\n" "$1"; }
info()    { printf "${CYAN}ℹ️ %b\n" "$1"; }
title() {
    local msg="${1:-Make target}"
    local line2="|     $msg     |"
    local len=${#line2}
    local dashes=""
    for i in $(seq 1 $((len-2))); do
        dashes="${dashes}="
    done
    local line1="+$dashes+"
    echo -e "\n${BOLD}${BLUE}${line1}"
    echo "${line2}"
    echo -e "${line1}${RESET}"
}

slugify() {
    echo "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9-]/-/g' \
        | sed 's/--*/-/g' \
        | sed 's/^-//;s/-$//'
}

# ── Default Values ──────────────────────────────────────────────
DEFAULT_WEB_PORT=8080
DEFAULT_DB_PORT_MARIADB=3306
DEFAULT_DB_PORT_POSTGRES=5432
DEFAULT_PMA_PORT=8081
DEFAULT_REDIS_PORT=6379
DEFAULT_PHP_VERSION="8.2"
SF_VERSION_STABLE="8.0.*"
SF_VERSION_LTS="7.4.*"
ENV_FILE=".env.docker"
CI_ENV_FILE=".env.ci"
PIPELINE_FILE=".github/workflows/pipeline.yml"
ROLLBACK_FILE=".github/workflows/rollback.yml"
CI_MARIADB_URL="mysql://app_test:app_test_pass@db-mariadb:3306/app_test?serverVersion=11.8.6-MariaDB&charset=utf8mb4"
CI_POSTGRES_URL="postgresql://app_test:app_test_pass@db-postgres:5432/app_test?serverVersion=18.3&charset=utf8"

# ════════════════════════════════════════════════════════════════
#  File already exists ?
# ════════════════════════════════════════════════════════════════
if [ -f "$ENV_FILE" ]; then
    info "Le fichier $ENV_FILE existe déjà."
    exit 0
fi

printf "It will write configuration to ${BOLD}.env.docker${RESET}. "
printf "You can edit this file later to adjust settings.\n\n"

# ════════════════════════════════════════════════════════════════
#  User IDs
# ════════════════════════════════════════════════════════════════
user_id=$(id -u)
group_id=$(id -g)

# ════════════════════════════════════════════════════════════════
# Application environment
# ════════════════════════════════════════════════════════════════
read -r -p "App environment [dev (default) / prod] : " app_env
if [ "$app_env" != "dev" ] && [ "$app_env" != "prod" ]; then
    app_env="dev"
fi

if [ "$app_env" = "prod" ]; then
    profiles=""
else
    profiles="mailpit"
fi

# ════════════════════════════════════════════════════════════════
#  Project name
# ════════════════════════════════════════════════════════════════
read -r -p "Project name [My Symfony App] : " project_name
if [ -z "$project_name" ]; then
    project_name="My Symfony App"
fi

project_slug=$(slugify "$project_name")
default_vhost="${project_slug}.docker"

# ════════════════════════════════════════════════════════════════
#  Symfony version
# ════════════════════════════════════════════════════════════════
read -r -p "Symfony version [latest stable (stable, default) / latest LTS (lts) / custom (e.g. 7.1.*)] : " symfony_version
if [ -z "$symfony_version" ] || [ "$symfony_version" = "stable" ]; then
  symfony_version="$SF_VERSION_STABLE"
elif [ "$symfony_version" = "lts" ]; then
  symfony_version="$SF_VERSION_LTS"
fi

# ════════════════════════════════════════════════════════════════
#  Distribution
# ════════════════════════════════════════════════════════════════
read -r -p "Distribution [webapp (default) / api] : " distribution
if [ "$distribution" != "webapp" ] && [ "$distribution" != "api" ]; then
    distribution="webapp"
fi

# ════════════════════════════════════════════════════════════════
#  Assets frontend
# ════════════════════════════════════════════════════════════════
read -r -p "Front-end assets [mapper (default) / webpack] : " assets
if [ "$assets" != "mapper" ] && [ "$assets" != "webpack" ]; then
    assets="mapper"
fi

profiles+=",$assets"

if [ "$assets" = "webpack" ]; then profiles+=",node"; fi

# ════════════════════════════════════════════════════════════════
#  Web server
# ════════════════════════════════════════════════════════════════
read -r -p "Web server [nginx (default) / apache] : " webserver
if [ "$webserver" != "nginx" ] && [ "$webserver" != "apache" ]; then
    webserver="nginx"
fi

profiles+=",$webserver"

# ════════════════════════════════════════════════════════════════
#  Database engine
# ════════════════════════════════════════════════════════════════
read -r -p "Database [mariadb (default) / postgres] : " database
if [ "$database" != "postgres" ] && [ "$database" != "mariadb" ]; then
    database="mariadb"
fi

if [ "$database" = "mariadb" ]; then
    profiles+=",mariadb"
    db_internal_port="$DEFAULT_DB_PORT_MARIADB"
    db_port_default="$DEFAULT_DB_PORT_MARIADB"
else
    profiles+=",postgres"
    db_internal_port="$DEFAULT_DB_PORT_POSTGRES"
    db_port_default="$DEFAULT_DB_PORT_POSTGRES"
fi

# ════════════════════════════════════════════════════════════════
#  Virtual host
# ════════════════════════════════════════════════════════════════
read -r -p "Virtual host [$default_vhost] : " virtual_host
if [ -z "$virtual_host" ]; then
    virtual_host="$default_vhost"
fi

# ════════════════════════════════════════════════════════════════
#  Ports
# ════════════════════════════════════════════════════════════════
read -r -p "HTTP external port [$DEFAULT_WEB_PORT] : " web_external_port
if [ -z "$web_external_port" ]; then
    web_external_port="$DEFAULT_WEB_PORT"
fi

read -r -p "Database external port [$db_port_default] : " db_external_port
if [ -z "$db_external_port" ]; then
    db_external_port="$db_port_default"
fi

# ════════════════════════════════════════════════════════════════
#  PHP
# ════════════════════════════════════════════════════════════════
read -r -p "PHP version [8.4 (latest stable) / 8.3 / 8.2 (default) / custom (e.g. 8.1)] : " php_version
if [ -z "$php_version" ]; then
    php_version="$DEFAULT_PHP_VERSION"
fi

# ════════════════════════════════════════════════════════════════
#  Redis
# ════════════════════════════════════════════════════════════════
read -r -p "Do you want to install Redis ? [y/n] : " install_redis
if [ "$install_redis" = "y" ] || [ "$install_redis" = "Y" ]; then
    read -r -p "Redis host port [$DEFAULT_REDIS_PORT] : " redis_external_port
    if [ -z "$redis_external_port" ]; then
        redis_external_port="$DEFAULT_REDIS_PORT"
    fi
    profiles+=",redis"
else
    redis_external_port=""
fi

# ════════════════════════════════════════════════════════════════
#  Xdebug
# ════════════════════════════════════════════════════════════════
read -r -p "Do you want to enable Xdebug ? [y/n] : " enable_xdebug
if [ "$enable_xdebug" = "y" ] || [ "$enable_xdebug" = "Y" ]; then
    xdebug_mode="debug,develop"
else
    xdebug_mode="off"
fi

# ════════════════════════════════════════════════════════════════
#  Writing the .env.docker file
# ════════════════════════════════════════════════════════════════
{
    echo "USER_ID=$user_id"
    echo "GROUP_ID=$group_id"
    echo "APP_ENV=$app_env"
    echo "PROJECT_NAME=$project_name"
    echo "PROJECT_SLUG=$project_slug"
    echo "SYMFONY_VERSION=$symfony_version"
    echo "DIST=$distribution"
    echo "ASSETS=$assets"
    echo "WEB_SERVER=$webserver"
    echo "VHOST=$virtual_host"
    echo "WEB_EXTERNAL_PORT=$web_external_port"
    echo "DB_INTERNAL_PORT=$db_internal_port"
    echo "DB_EXTERNAL_PORT=$db_external_port"
    if [ "$database" = "mariadb" ]; then
        echo "PMA_EXTERNAL_PORT=$DEFAULT_PMA_PORT"
    fi
    echo "APP_DB_NAME=$project_slug"
    echo "APP_DB_USER=$project_slug"
    echo "APP_DB_PASSWORD=$project_slug"
    echo "PHP_VERSION=$php_version"
    echo "XDEBUG_MODE=$xdebug_mode"
    echo "REDIS_EXTERNAL_PORT=$redis_external_port"
    echo "INSTALL_SYMFONY_CLI=1"
    echo "COMPOSE_PROFILES=$profiles"
} > "$ENV_FILE"

# ════════════════════════════════════════════════════════════════
#  Display and Confirmation
# ════════════════════════════════════════════════════════════════
title "Contenu de .env.docker :"
cat "$ENV_FILE"
printf "\n\n"

read -r -p "Do you approve of it ? [y/n] : " approve

if [ "$approve" = "n" ] || [ "$approve" = "N" ]; then
    warning "Cancellation — deletion of $ENV_FILE..."
    rm -f "$ENV_FILE"
    success "Configuration not approved. Please run 'make install' again to configure the project."
    exit 0
fi

success "Configuration saved to ${BOLD}$ENV_FILE${RESET}."

# ════════════════════════════════════════════════════════════════
#  Updating CI files (.env.ci, pipeline.yml, rollback.yml)
# ════════════════════════════════════════════════════════════════
if [ -f "$CI_ENV_FILE" ] || [ -f "$PIPELINE_FILE" ] || [ -f "$ROLLBACK_FILE" ]; then
    info "Updating CI configuration files..."

    # Prepare values based on database
    if [ "$database" = "mariadb" ]; then
        db_profile="ci-mariadb"
        db_port="3306"
        db_url="$CI_MARIADB_URL"
    else
        db_profile="ci-postgres"
        db_port="5432"
        db_url="$CI_POSTGRES_URL"
    fi

    # Escaped URL for sed
    db_url_sed=$(echo "$db_url" | sed 's/&/\\&/g')

    # --- Updating .env.ci ---
    if [ -f "$CI_ENV_FILE" ]; then
        sed -i "s/^PROJECT_SLUG=.*/PROJECT_SLUG=$project_slug/" "$CI_ENV_FILE"
        sed -i "s/^PHP_VERSION=.*/PHP_VERSION=$php_version/" "$CI_ENV_FILE"
        sed -i "s/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=$db_profile/" "$CI_ENV_FILE"
        sed -i "s/^DB_INTERNAL_PORT=.*/DB_INTERNAL_PORT=$db_port/" "$CI_ENV_FILE"
        sed -i "s|^CI_DATABASE_URL=.*|CI_DATABASE_URL=$db_url_sed|" "$CI_ENV_FILE"
        success "$CI_ENV_FILE updated."
    fi

    # --- Updating pipeline.yml ---
    if [ -f "$PIPELINE_FILE" ]; then
        # Section env:
        sed -i "s/PHP_VERSION: \".*\"/PHP_VERSION: \"$php_version\"/" "$PIPELINE_FILE"
        sed -i "s/DB_ENGINE: \".*\"/DB_ENGINE: \"$database\"/" "$PIPELINE_FILE"
        sed -i "s/DB_COMPOSE_PROFILE: \".*\"/DB_COMPOSE_PROFILE: \"$db_profile\"/" "$PIPELINE_FILE"
        sed -i "s/DB_PORT: \".*\"/DB_PORT: \"$db_port\"/" "$PIPELINE_FILE"
        sed -i "s|DB_URL: \".*\"|DB_URL: \"$db_url_sed\"|" "$PIPELINE_FILE"
        sed -i "s/PROJECT_SLUG: \".*\"/PROJECT_SLUG: \"$project_slug\"/" "$PIPELINE_FILE"

        # Section matrix: (targeting lines after the specific comment)
        sed -i "/synchronized with env: above/,/php-version:/ s/php-version: \".*\"/php-version: \"$php_version\"/" "$PIPELINE_FILE"
        sed -i "/synchronized with env: above/,/db:/ s/db: \".*\"/db: \"$database\"/" "$PIPELINE_FILE"
        sed -i "/synchronized with env: above/,/compose-profile:/ s/compose-profile: \".*\"/compose-profile: \"$db_profile\"/" "$PIPELINE_FILE"
        sed -i "/synchronized with env: above/,/db-port:/ s/db-port: \".*\"/db-port: \"$db_port\"/" "$PIPELINE_FILE"
        sed -i "/synchronized with env: above/,/db-url:/ s|db-url: \".*\"|db-url: \"$db_url_sed\"|" "$PIPELINE_FILE"

        success "$PIPELINE_FILE updated."
    fi

    # --- Updating rollback.yml ---
    if [ -f "$ROLLBACK_FILE" ]; then
        sed -i "s/PHP_VERSION: \".*\"/PHP_VERSION: \"$php_version\"/" "$ROLLBACK_FILE"
        sed -i "s/DB_COMPOSE_PROFILE: \".*\"/DB_COMPOSE_PROFILE: \"$db_profile\"/" "$ROLLBACK_FILE"
        sed -i "s/DB_PORT: \".*\"/DB_PORT: \"$db_port\"/" "$ROLLBACK_FILE"
        sed -i "s|DB_URL: \".*\"|DB_URL: \"$db_url_sed\"|" "$ROLLBACK_FILE"
        sed -i "s/PROJECT_SLUG: \".*\"/PROJECT_SLUG: \"$project_slug\"/" "$ROLLBACK_FILE"
        success "$ROLLBACK_FILE updated."
    fi
fi

# ── Symlink to .env for Docker Compose auto-loading ───────────────
if [ -f "$ENV_FILE" ]; then
    ln -sf "$ENV_FILE" .env
    success "Environment file symlinked to ${BOLD}.env${RESET}${GREEN} for Docker Compose auto-loading."
fi
