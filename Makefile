## Makefile for Dockerized Symfony Project
## Works on Linux/macOS and Windows via Git Bash or WSL

-include .env.dist
-include .make.local
-include .env

## Colors for output
OBJ_COLOR	= \033[0;34m
BLUE		= \033[0;36m
GREEN		= \033[0;32m
RED			= \033[0;31m
YELLOW		= \033[0;33m
NC			= \033[m

## Makefile variables
DOCKER						= docker
DOCKER_EXEC					= $(DOCKER) exec --user=www-data:www-data
DOCKER_RUN					= $(DOCKER) run --user=www-data:www-data
DOCKER_RUN_ROOT				= $(DOCKER) run --user=root:root
DOCKER_COMPOSE				= docker compose
DOCKER_COMPOSE_EXEC			= $(DOCKER_COMPOSE) exec --user=www-data:www-data
DOCKER_COMPOSE_RUN			= $(DOCKER_COMPOSE) run --user=www-data:www-data
DOCKER_COMPOSE_EXEC_NO_TTY	= $(DOCKER_COMPOSE) exec -T --user=www-data:www-data
WITH_BASH					= bash -lc
EXEC_IN_APP					= $(DOCKER_EXEC) $(PROJECT_SLUG)-php
PHP							= $(EXEC_IN_APP) php
COMPOSER					= $(DOCKER_COMPOSE_EXEC) php composer --ansi
#SF_CONSOLE					= $(PHP) ./bin/console
SF_CONSOLE					= $(EXEC_IN_APP) symfony console --ansi
NPM							= $(DOCKER_EXEC) $(PROJECT_SLUG)-node npm
#WEBPACK						= $(EXEC_IN_APP) ./node_modules/.bin/encore
WEBPACK						= $(NPM) encore

## Helper functions
define title
	@{ \
		set -e ;\
		msg="$(if $(strip $(1)),$(1),Make $@)"; \
		line2="|    $$msg    |"; \
		len=$${#line2}; \
		dashes=""; \
		for i in $$(seq 1 $$((len-2))); do dashes="$$dashes="; done; \
		line1="+$$dashes+"; \
		echo -e "$(OBJ_COLOR)"; \
		echo "$$line1"; \
		echo "$$line2"; \
		echo -e "$$line1$(NC)"; \
    }
endef
# Slugify helper: lowercase, replace non-alnum with hyphen, squeeze, trim
# $(call slugify,string)
define slugify
	echo "$(1)" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$$//'
endef
define replace_in_file
	sed -i 's|$(2)|$(3)|g' $(1)
endef
define get_postgres_server_version
	docker exec "$(1)-db" psql --version | grep -oP '\d+\.\d+'
endef
define get_mysql_server_version
	docker exec "$(1)-db" sh -c "(mysql --version 2>/dev/null || mysqld --version)" | grep -Eo "[0-9]+\.[0-9]+" | head -n1
endef

.PHONY: help
.DEFAULT_GOAL=help
help:
	$(call title,Help)
	# PROJECT_NAME: Human-readable project name
	# PROJECT_SLUG: Slug used for container names and network (lowercase, hyphens)
	# SYMFONY_VERSION: "latest" (empty), "lts", or a custom version constraint
	# DIST: "webapp" or "api"
	# ASSETS: "mapper" or "encore"
	# WEB_SERVER: "nginx" or "apache"
	# DB_CHOICE: "postgres" or "mysql"
	# VHOST: e.g., "localhost" or "my-app.local"
	# WEB_PORT: e.g., 8080
	# DB_PORT: 5432 (postgres) or 3306 (mysql)
	# REDIS_PORT: 6379
	# PHP_VERSION: default 8.2 unless overridden by Symfony requirements
	# XDEBUG_MODE: off by default; set to debug,develop when enabled
	# COMPOSE_PROFILES: comma-separated list (e.g., "redis,node")
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[32m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[32m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Project

.PHONY: install _prepare _setup reset
install: _prepare _setup ## Install and start the project
_prepare: _check-docker _env _webserver _docker # Prepare the environment (check Docker, configure env, generate webserver config, rebuild/start containers)
_setup: _setup-symfony-app _setup-assets _setup-env-local _setup-deps _update-hosts _end # Set up the application (create Symfony app, configure assets and .env.local, install dev dependencies, update hosts)

reset: down ## Remove app/vendor/node_modules and lockfiles; run 'make install' afterward
	@rm -rf app vendor node_modules package.json package-lock.json 2>/dev/null
	@echo -e "$(GREEN)Reset complete. Run 'make install' to reinitialize.$(NC)"

.PHONY: _check-docker _default-ports _env _setup-webserver _setup-symfony-app _setup-assets _setup-env-local _setup-deps _update-hosts _end
_check-docker: # Check that Docker is installed and running
	$(call title,Check Docker)
	@command -v docker >/dev/null 2>&1 || { echo -e "$(RED)Docker is not installed. Install Docker Desktop / Docker Engine.$(NC)\n$(YELLOW)Please install Docker and then run 'make install' again.$(NC)"; }
	@$(DOCKER) info >/dev/null 2>&1 || { echo -e "$(RED)Docker is installed but not started. Launch Docker Desktop / start the Docker service.$(NC)\n$(YELLOW)Start Docker and then run 'make install' again.$(NC)"; }
	@command -v docker >/dev/null 2>&1 && $(DOCKER) info >/dev/null 2>&1 && echo -e "$(GREEN)Docker installed and running.$(NC)"
_default-ports: # Shows the default ports used (WEB, DB, REDIS)
	@echo ""; echo -e "$(BLUE)Info :$(NC) Default ports -> WEB: 8080, DB: 5432 (Postgres) / 3307 (MariaDB), REDIS: 6379"
_env: # Configures the project interactively and writes .make.local and .env
	$(call title,Environment Variables)
	@echo "It will write configuration to .make.local and .env."
	@echo ""
	@if [ ! -f .make.local ] || [ ! -f .env ]; then \
		user_id=$(shell id -u); \
		group_id=$(shell id -g); \
		echo "USER_ID=$$user_id" > .env; \
		echo "GROUP_ID=$$group_id" >> .env; \
		read -r -p "App environment [dev (default) / prod] : " app_env; \
		if [ "$$app_env" != "dev" ] && [ "$$app_env" != "prod" ]; then app_env="dev"; fi; \
		if [ "$$app_env" = "prod" ]; then profiles=""; else profiles="mailpit"; fi; \
		echo "APP_ENV=$$app_env" > .make.local; \
		read -r -p "Project name [$(PROJECT_NAME)] : " project_name; \
		if [ -z "$$project_name" ]; then project_name=$(PROJECT_NAME); fi; \
		project_slug=$$( $(call slugify,$$project_name) ); \
		default_vhost="$$project_slug.docker"; \
		echo "PROJECT_NAME=$$project_name" >> .make.local; \
		echo "PROJECT_SLUG=$$project_slug" >> .make.local; \
		echo "PROJECT_SLUG=$$project_slug" >> .env; \
		read -r -p "Symfony version [latest stable (stable, default) / latest LTS (lts) / custom (e.g., 7.1.*)] : " symfony_version; \
		if [ -z "$$symfony_version" ]; then symfony_version=$(SYMFONY_VERSION); fi; \
		echo "SYMFONY_VERSION=$$symfony_version" >> .make.local; \
		read -r -p "Distribution [webapp (default) / api] : " distribution; \
		if [ "$$distribution" != "webapp" ] && [ "$$distribution" != "api" ]; then distribution=$(DIST); fi; \
		echo "DIST=$$distribution" >> .make.local; \
		read -r -p "Front-end assets [mapper (default) / webpack] : " assets; \
		if [ "$$assets" != "mapper" ] && [ "$$assets" != "webpack" ]; then assets=$(ASSETS); fi; \
		echo "ASSETS=$$assets" >> .make.local; \
		if [ -z "$$profiles" ]; then profiles="$$assets"; else profiles+=",$$assets"; fi; \
		read -r -p "Web server [nginx (default) / apache] : " webserver; \
		if [ "$$webserver" != "nginx" ] && [ "$$webserver" != "apache" ]; then webserver=$(WEB_SERVER); fi; \
		echo "WEB_SERVER=$$webserver" >> .make.local; \
		echo "WEB_SERVER=$$webserver" >> .env; \
		profiles+=",$$webserver"; \
		read -r -p "Database [mysql (default) / postgres] : " database; \
		if [ "$$database" != "postgres" ] && [ "$$database" != "mysql" ]; then database=$(DB); fi; \
		echo "DB=$$database" >> .make.local; \
		echo "DB=$$database" >> .env; \
		read -r -p "Virtual host [$$default_vhost] : " virtual_host; \
		if [ -z "$$virtual_host" ]; then virtual_host="$$default_vhost"; fi; \
		echo "VHOST=$$virtual_host" >> .make.local; \
		echo "VHOST=$$virtual_host" >> .env; \
		read -r -p "HTTP host port [$(WEB_PORT)] : " web_port; \
		if [ -z "$$web_port" ]; then web_port=$(WEB_PORT); fi; \
		echo "WEB_PORT=$$web_port" >> .make.local; \
		echo "WEB_PORT=$$web_port" >> .env; \
		if [ "$$database" = "postgres" ]; then db_port_default=5432; else db_port_default=3306; fi; \
		read -p "Database host port [$$db_port_default] : " db_port; \
		if [ -z "$$db_port" ]; then db_port=$(DB_PORT); fi; \
		echo "DB_PORT=$$db_port" >> .make.local; \
		echo "DB_PORT=$$db_port" >> .env; \
		echo "PMA_PORT=$(PMA_PORT)" >> .env; \
		read -p "Do you want to install Redis ? [y/n] : " install_redis; \
		if [ "$$install_redis" = "y" ] || [ "$$install_redis" = "Y" ]; then \
			read -r -p "Redis host port [$(REDIS_PORT)] : " redis_port; \
			if [ -z "$$redis_port" ]; then redis_port=$(REDIS_PORT); fi; \
			echo "REDIS_PORT=$$redis_port" >> .make.local; \
			echo "REDIS_PORT=$$redis_port" >> .env; \
			profiles+=",redis"; \
		else \
			echo "REDIS_PORT=" >> .make.local; \
			echo "REDIS_PORT=" >> .env; \
		fi; \
		if command -v nc >/dev/null 2>&1; then \
			if nc -z 127.0.0.1 "$$web_port"; then \
				port_in_use="$$web_port"; \
				echo "Port $$web_port is in use."; \
				read -p "Enter alternate HTTP port (e.g., 8081) : " tmp; \
				if [ -n "$$tmp" ]; then web_port="$$tmp"; fi; \
				$(call replace_in_file,.make.local,"WEB_PORT=$$port_in_use","WEB_PORT=$$web_port"); \
			fi; \
			if nc -z 127.0.0.1 "$$db_port"; then \
				port_in_use="$$db_port"; \
				echo "Port $$db_port is in use."; \
				read -p "Enter alternate DB port : " tmp; \
				if [ -n "$$tmp" ]; then db_port="$$tmp"; fi; \
				$(call replace_in_file,.make.local,"DB_PORT=$$port_in_use","DB_PORT=$$db_port"); \
			fi; \
			if nc -z 127.0.0.1 "$$redis_port"; then \
				port_in_use="$$redis_port"; \
				echo "Port $$redis_port is in use."; \
				read -p "Enter alternate Redis port : " tmp; \
				if [ -n "$$tmp" ]; then redis_port="$$tmp"; fi; \
				$(call replace_in_file,.make.local,"REDIS_PORT=$$port_in_use","REDIS_PORT=$$redis_port"); \
			fi; \
		else \
			echo -e "$(BLUE)Note :$(NC) 'nc' not available; skipping port-in-use checks."; \
		fi; \
		read -p "PHP version [$(PHP_VERSION)] : " php_version; \
		if [ -z "$$php_version" ]; then php_version=$(PHP_VERSION); fi; \
		echo "PHP_VERSION=$$php_version" >> .make.local; \
		echo "PHP_VERSION=$$php_version" >> .env; \
		if [ "$$database" = "postgres" ]; then \
			db_image=postgres:16-alpine; db_internal_port=5432; db_data_dir=/var/lib/postgresql/data; \
		else \
			db_image=mysql:lts; db_internal_port=3306; db_data_dir=/var/lib/mysql; \
		fi; \
		echo "DB_IMAGE=$$db_image" >> .env; \
		echo "DB_INTERNAL_PORT=$$db_internal_port" >> .env; \
		echo "DB_DATA_DIR=$$db_data_dir" >> .env; \
		read -p "Do you want to enable Xdebug ? [y/n] : " enable_xdebug; \
		if [ "$$enable_xdebug" = "y" ] || [ "$$enable_xdebug" = "Y" ]; then \
			xdebug_mode="debug,develop"; \
		else \
			xdebug_mode="off"; \
		fi; \
		echo "XDEBUG_MODE=$$xdebug_mode" >> .make.local; \
		echo "XDEBUG_MODE=$$xdebug_mode" >> .env; \
		echo "APP_DB_NAME=$$project_slug" >> .make.local; \
		echo "APP_DB_NAME=$$project_slug" >> .env; \
		echo "APP_DB_USER=$$project_slug" >> .make.local; \
		echo "APP_DB_USER=$$project_slug" >> .env; \
		echo "APP_DB_PASSWORD=$$project_slug" >> .make.local; \
		echo "APP_DB_PASSWORD=$$project_slug" >> .env; \
		echo "INSTALL_SYMFONY_CLI=1" >> .env; \
		echo "COMPOSE_PROFILES=$$profiles" >> .env; \
		echo ""; echo -e "$(GREEN)Saved configuration to .make.local and .env.$(NC)"; \
	else \
		echo -e "$(BLUE)Configuration files (.make.local and .env) already exist.$(NC)"; \
	fi
_webserver: # Generates web server configuration from templates
	$(call title,Webserver configuration)
	@if [ ! -f .docker/web/nginx/nginx.conf ]; then cp .docker/web/nginx/nginx.conf.tpl .docker/web/nginx/nginx.conf; fi; \
	if [ ! -f .docker/web/apache/apache.conf ]; then cp .docker/web/apache/apache.conf.tpl .docker/web/apache/apache.conf; fi; \
	sed -i "s/\s*server_name ##vhost##/    server_name $(VHOST)/g" .docker/web/nginx/nginx.conf; \
	sed -i "s/##vhost##/$(VHOST)/g" .docker/web/apache/apache.conf; \
	echo -e "$(GREEN)Webserver configuration success.$(NC)"
_docker: # Rebuild images and restart all Docker services
	$(call main_title,Start docker)
	@${MAKE} down
	@-$(DOCKER_COMPOSE) pull --parallel --quiet --ignore-pull-failures 2> /dev/null
	@$(DOCKER_COMPOSE) build
	@${MAKE} up
_setup-symfony-app: # Create the Symfony application in ./app
	$(call title,Setup Symfony app)
	@if [ -d app ] && [ -f app/composer.json ]; then \
		read -p "./app exists. Reuse it ? [y/n] : " reuse; \
		if [ "$$reuse" = "n" ] || [ "$$reuse" = "N" ]; then \
			read -p "This will remove ./app. Continue ? [y/n] : " confirm; \
			if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then rm -rf app; fi; \
		fi; \
	fi
	@if [ ! -d app ] || [ ! -f app/composer.json ]; then \
	    echo -e "$(BLUE)Creating Symfony project in ./app ...$(NC)"; \
		$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) 'git config --global --add safe.directory /var/www/html'; \
	    if [ $(DIST) = "webapp" ]; then \
			if [ $(SYMFONY_VERSION) = "stable" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "cd /var/www/html && symfony new . --webapp --no-git"; \
			elif [ $(SYMFONY_VERSION) = "lts" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "cd /var/www/html && symfony new . --version=$(SYMFONY_VERSION) --webapp --no-git"; \
			else
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "cd /var/www/html && symfony new . --version='$(SYMFONY_VERSION)' --webapp --no-git"; \
			fi; \
			if [ $(WEB_SERVER) = "apache" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "cd /var/www/html && composer require symfony/apache-pack"; \
			fi; \
		else \
			if [ $(SYMFONY_VERSION) = "stable" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "cd /var/www/html && symfony new . --no-git"; \
			elif [ $(SYMFONY_VERSION) = "lts" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "cd /var/www/html && symfony new . --version=$(SYMFONY_VERSION) --no-git"; \
			else \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "cd /var/www/html && symfony new . --version='$(SYMFONY_VERSION)' --no-git"; \
			fi; \
			$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "cd /var/www/html && composer require api"; \
		fi; \
	fi
	@cp phpstan.dist.neon app/phpstan.dist.neon
	@mkdir -p app/.github
	@cp -r .docker/github/workflows app/.github/
_setup-assets: # Configures assets (Asset Mapper or Webpack Encore) according to the selection
	$(call title,Setup Assets)
	@if [ $(ASSETS) = "encore" ]; then \
		echo -e "$(BLUE)Setting up Webpack Encore...$(NC)"; \
		$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "set -e; cd /var/www/html; composer require symfony/webpack-encore-bundle"; \
		$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && if [ -f package.json ]; then echo package.json exists; else npm init -y; fi"; \
		$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && npm install --save-dev @symfony/webpack-encore webpack webpack-cli core-js regenerator-runtime"; \
		$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && mkdir -p assets/styles"; \
		$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && echo 'import \"./styles/app.css\"' > assets/app.js"; \
		$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && echo '/* app styles */' > assets/styles/app.css"; \
		$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && if [ ! -f webpack.config.js ]; then ./node_modules/.bin/encore init --no-interaction || true; fi"; \
	else \
		echo -e "$(BLUE)Trying to set up Asset Mapper...$(NC)"; \
		if $(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "set -e; cd /var/www/html; composer require symfony/asset-mapper"; then :; \
		else \
			echo "Asset Mapper may be unsupported for this Symfony version. Falling back to Webpack Encore..."; \
			if grep -q '^COMPOSE_PROFILES=' .env; then \
				sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=redis,node/' .env; \
			else \
				echo 'COMPOSE_PROFILES=redis,node' >> .env; \
			fi; \
			compose up -d --build node; \
			$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "set -e; cd /var/www/html; composer require symfony/webpack-encore-bundle"; \
			$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && if [ -f package.json ]; then echo package.json exists; else npm init -y; fi"; \
			$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && npm install --save-dev @symfony/webpack-encore webpack webpack-cli core-js regenerator-runtime"; \
			$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && mkdir -p assets/styles"; \
			$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && echo 'import \"./styles/app.css\"' > assets/app.js"; \
			$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && echo '/* app styles */' > assets/styles/app.css"; \
			$(DOCKER_COMPOSE_RUN) --rm node $(WITH_BASH) "set -e && cd /var/www/html && if [ ! -f webpack.config.js ]; then ./node_modules/.bin/encore init --no-interaction || true; fi"; \
		fi; \
	fi
_setup-env-local: # Generates app/.env.local (DB_URL, Mailpit DSN, REDIS_URL if enabled)
	$(call title,Setup app/.env.local)
	@if [ -f app/.env.local ]; then \
		echo -e "$(BLUE)app/.env.local already exists$(NC)"; \
	else \
		if [ "$(DB)" = "postgres" ]; then \
			server_version=$$( $(call get_postgres_server_version,$(PROJECT_SLUG)) ); \
			db_url="postgresql:\/\/$(APP_DB_USER):$(APP_DB_PASSWORD)@db:$(DB_INTERNAL_PORT)\/$(APP_DB_NAME)?serverVersion=$$server_version\&charset=utf8"; \
		else \
			server_version=$$( $(call get_mysql_server_version,$(PROJECT_SLUG)) ); \
			db_url="mysql:\/\/$(APP_DB_USER):$(APP_DB_PASSWORD)@db:$(DB_INTERNAL_PORT)\/$(APP_DB_NAME)?serverVersion=$$server_version\&charset=utf8mb4"; \
		fi; \
		cp .env.local.dist app/.env.local; \
		sed -i "s/##DATABASE##/$$db_url/g" app/.env.local; \
		sed -i "s/##DSN##/smtp:\/\/mailpit:1025/g" app/.env.local; \
		if [ ! -z $(REDIS_PORT) ]; then echo "REDIS_URL=redis://redis:$(REDIS_PORT)" >> app/.env.local; fi; \
		echo -e "$(GREEN)app/.env.local created.$(NC)"; \
	fi
_setup-deps: # Installs development dependencies (tests, PHPStan, CS Fixer, TwigCS)
	$(call title,Setup dependencies)
	@$(COMPOSER) require --dev --with-all-dependencies \
		"symfony/test-pack" \
		"phpstan/phpstan" \
		"phpstan/phpstan-symfony" \
		"phpstan/phpstan-doctrine" \
		"phpstan/phpstan-strict-rules" \
		"ekino/phpstan-banned-code" \
		"friendsofphp/php-cs-fixer" \
		"friendsoftwig/twigcs" \
	;
_update-hosts: # Updates the OS hosts file with the VHOST (best-effort)
	$(call title,Update hosts file)
	@if [ -z "$(VHOST)" ]; then \
		echo -e "$(BLUE)No VHOST specified; skipping hosts update.$(NC)"; \
	else  \
		entry="127.0.0.1 $(VHOST)"; \
		if [ "$$OS" = "Windows_NT" ]; then \
			hostspath="/c/Windows/System32/drivers/etc/hosts"; \
			if grep -i -q "^127.0.0.1[[:space:]]\+$(VHOST)\>" "$$hostspath" 2>/dev/null; then \
				echo -e "$(GREEN)Hosts entry already present (Windows).$(NC)"; \
			else \
				echo -e "$(BLUE)Attempting to update Windows hosts file (requires elevation)...$(NC)"; \
				powershell -NoProfile -Command "if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) { Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -Command \"Add-Content -Path ''C:\\Windows\\System32\\drivers\\etc\\hosts'' -Value ''$$entry''; pause\"' -Wait } else { Add-Content -Path 'C:\\Windows\\System32\\drivers\\etc\\hosts' -Value '$$entry'; }"; \
				if grep -i -q "^127.0.0.1[[:space:]]\+$(VHOST)\>" "$$hostspath" 2>/dev/null; then \
					echo -e "$(GREEN)Hosts updated.$(NC)"; \
				else \
					echo -e "$(RED)Could not update hosts automatically.$(NC)"; \
					echo -e "$(YELLOW)Please add : $$entry to C:\\Windows\\System32\\drivers\\etc\\hosts.$(NC)"; \
				fi; \
			fi; \
		else \
			hostspath="/etc/hosts"; \
			if grep -i -q "^127.0.0.1[[:space:]]\+$(VHOST)\>" "$$hostspath" 2>/dev/null; then \
				echo -e "$(GREEN)Hosts entry already present.$(NC)"; \
			else \
				echo -e "$(BLUE)Updating /etc/hosts (may prompt for sudo)...$(NC)"; \
				echo "$$entry" | sudo tee -a "$$hostspath" >/dev/null || true; \
				if grep -i -q "^127.0.0.1[[:space:]]\+$(VHOST)\>" "$$hostspath" 2>/dev/null; then \
					echo -e "$(GREEN)Hosts updated.$(NC)"; \
				else \
					echo -e "$(YELLOW)Could not update hosts automatically. Please add: $$entry to /etc/hosts.$(NC)"; \
				fi; \
			fi; \
		fi; \
	fi
_end:
	@echo -e "$(GREEN)"
	@echo "+=============================+"
	@echo "|    Installation complete    |"
	@echo -e "+=============================+$(NC)"
	@echo "Next steps :"
	@echo "- Open http://$(VHOST):$(WEB_PORT) in your browser once Symfony boots."

##@ Docker

.PHONY: up down restart restart-soft build build-no-cache ps logs
up: ## Start all Docker services (detached mode)
	$(call title,Docker Up)
	$(DOCKER_COMPOSE) up -d

down: ## Stop and remove containers and default resources
	$(call title,Docker Down)
	$(DOCKER_COMPOSE) down --remove-orphans --volumes

stop: ## Stop all Docker services
	$(call title,Docker Stop)
	$(DOCKER_COMPOSE) stop

restart: ## Restart all Docker services (down and up)
	$(call title,Docker Restart)
	$(DOCKER_COMPOSE) down
	$(DOCKER_COMPOSE) up -d

restart-soft: ## Restart all Docker services (stop and start)
	$(call title,Docker Soft Restart)
	$(DOCKER_COMPOSE) stop
	$(DOCKER_COMPOSE) start

build: ## Build all Docker services
	$(call title,Docker Build)
	$(DOCKER_COMPOSE) build

build-no-cache: ## Build all Docker services (without cache)
	$(call title,Docker Build no cache)
	$(DOCKER_COMPOSE) build --no-cache

ps: ## List running Docker containers
	$(call title,Docker PS)
	$(DOCKER) ps

logs: ## Tail logs; set SERVICE=name to follow a specific service
	$(call title,Docker Logs)
	@echo -e "$(BLUE)make logs $(SERVICE)$(NC)"
	@echo ""
	@if [ -z "$(SERVICE)" ]; then $(DOCKER) logs -f; else $(DOCKER) logs -f $(SERVICE); fi

##@ Symfony

.PHONY: terminal terminal-root console cache-clear db-create db-drop db-migrate db-fixtures db-fixtures-append composer vendor npm node-modules
terminal: ## Open an interactive shell in the PHP container
	$(call title,Terminal)
	@if [ "$$OS" = "Windows_NT" ]; then \
		winpty $(DOCKER_COMPOSE_EXEC) php bash; \
	else \
		$(DOCKER_COMPOSE_EXEC) php bash; \
	fi

terminal-root: ## Open an interactive root shell in the PHP container
	$(call title,Root Terminal)
	@if [ "$$OS" = "Windows_NT" ]; then \
		winpty $(DOCKER_COMPOSE) exec php bash; \
	else \
		$(DOCKER_COMPOSE) exec php bash; \
	fi

console: ## Run Symfony Console inside the container; pass extra args with ARGS="..."
	$(call title,Symfony Console)
	@read -p "command [options] [arguments] : " command; \
	$(SF_CONSOLE) $$command;

cache-clear: ## Clear the Symfony application cache
	$(call title,Clear app cache)
	@$(SF_CONSOLE) cache:clear

db-create: ## Create the database (idempotent; uses --if-not-exists when available)
	$(call title,Create database)
	@$(SF_CONSOLE) doctrine:database:create --if-not-exists

db-drop: ## Drop the database (forced; uses --if-exists when available)
	$(call title,Drop database)
	@$(SF_CONSOLE) doctrine:database:drop --force --if-exists

db-migrate: ## Run Doctrine migrations (non-interactive; falls back to schema:update if migrations not available)
	$(call title,Doctrine migrations)
	@$(SF_CONSOLE) doctrine:migrations:migrate --no-interaction --allow-no-migration

db-fixtures: ## Load Doctrine fixtures (non-interactive; prints a message if fixtures bundle is not installed)
	$(call title,Load doctrine fixtures)
	@$(SF_CONSOLE) doctrine:fixtures:load --no-interaction

db-fixtures-append: ## Load Doctrine fixtures (no database purged)
	$(call title,Load doctrine fixtures without purge)
	@$(SF_CONSOLE) doctrine:fixtures:load --append

composer: ## Run Composer inside the PHP container
	$(call title,Composer)
	@read -p "command [options] [arguments] : " command; \
	$(COMPOSER) $$command

vendor: app/composer.json app/.env.local ## Install PHP dependencies (Composer install; optimized flags in production)
	$(call title,Composer install)
	@if [ "$$APP_ENV" = "prod" ]; then \
		$(COMPOSER) install --optimize-autoloader --no-progress --no-suggest --classmap-authoritative --no-interaction; \
	else \
		$(COMPOSER) install; \
	fi

.PHONY: npm node-modules assets assets-watch
npm: ## Run NPM inside the PHP container
	$(call title,NPM)
	@read -p "command [options] [arguments] : " command; \
	$(NPM) $$command
node-modules: ## Install Node dependencies (npm install) inside the NPM container
	$(call title,NPM install)
	$(NPM) install
	@if [ ! -f ./node_modules/.bin/eslint ]; then \
		$(NPM) i eslint --dev; \
	fi
webpack: ## Build assets in Encore
	$(call title,Webpack dev)
	@if [ "$$APP_ENV" = "dev" ]; then \
		$(NPM) run dev
	else \
		echo -e "$(YELLOW)Cette commande ne s'exécute qu'en développement.$(NC)"; \
	fi
webpack-watch: ## Watch assets in Encore (rebuild on changes)
	$(call title,Webpack watch)
	@if [ "$$APP_ENV" = "dev" ]; then \
		$(NPM) run watch
	else \
		echo -e "$(YELLOW)Cette commande ne s'exécute qu'en développement.$(NC)"; \
	fi
webpack-build: app/.env.local
	$(call title,Webpack build)
	@if [ "$$APP_ENV" = "prod" ]; then \
		$(NPM) run build
	else \
		echo -e "$(YELLOW)Cette commande ne s'exécute qu'en production.$(NC)"; \
	fi

##@ Tests

.PHONY: tests php-cs php-cs-fixer twigcs eslint eslint-fix lint validate validate-doctrine-schema validate-composer-config phpstan phpunit
tests: php-cs twigcs eslint lint validate phpstan phpunit

php-cs: ## Launch php-cs without fixing
	$(call title,PHP CS)
	@$(EXEC_IN_APP) vendor/bin/php-cs-fixer --ansi fix --show-progress=dots --diff --dry-run

php-cs-fixer: ## Launch php-cs-fixer
	$(call title,PHP CS Fixer)
	@$(EXEC_IN_APP) vendor/bin/php-cs-fixer --ansi fix --show-progress=dots --diff

phpstan: ## Launch phpstan tests
	$(call title,PHPStan)
	@$(PHP) -d memory_limit=-1 vendor/bin/phpstan --ansi analyse

phpunit: ## Launch phpunit tests
	$(call title,PHPUnit)
	#@$(EXEC_IN_APP) bash -c "APP_ENV=test php -d memory_limit=-1 bin/phpunit"
	@if [ "$$OS" = "Windows_NT" ]; then \
		winpty $(DOCKER_COMPOSE_EXEC) php bash -c "APP_ENV=test php -d memory_limit=-1 bin/phpunit"; \
	else \
		$(DOCKER_COMPOSE_EXEC) php bash -c "APP_ENV=test php -d memory_limit=-1 bin/phpunit"; \
	fi

twigcs: ## Launch twigcs
	$(call title,Twig CS)
	$(PHP) vendor/bin/twigcs --ansi --severity ignore templates

eslint: ## Launch eslint
	$(call title,ESLint)
	$(EXEC_IN_APP) ./node_modules/.bin/eslint assets
	@echo "\033[32mSuccess"

eslint-fix: ## Launch eslint --fix
	$(call title,ESLint Fix)
	$(EXEC_IN_APP) ./node_modules/.bin/eslint assets --fix
	@echo "\033[32mSuccess"

lint: ## Lint Yaml & Twig files
	$(call title,Lint)
	$(SF_CONSOLE) --ansi lint:yaml config *.yaml --parse-tags
	$(SF_CONSOLE) --ansi lint:twig templates

validate: validate-doctrine-schema validate-composer-config ## Validate Doctrine Schema & Composer config file

validate-doctrine-schema: ## Validate Doctrine Schema
	$(call title,Validate Doctrine Schema)
	# Options disponibles pour la commande doctrine:schema:validate :
	# --skip-mapping    Skip the mapping validation check
	# --skip-sync       Skip checking if the mapping is in sync with the database
	@$(SF_CONSOLE) --ansi doctrine:schema:validate

validate-composer-config: ## Validate Composer config file
	$(call title,Validate Composer config)
	@if [ -n "$$DO_NOT_VALIDATE_COMPOSER_CONFIG" ]; then \
		echo 'Variable "DO_NOT_VALIDATE_COMPOSER_CONFIG" is defined so we skip this test'; \
	else \
		echo 'Options disponibles pour la commande composer validate :'; \
		echo '# --no-check-all        Do not validate requires for overly strict/loose constraints'; \
		echo '# --no-check-lock       Do not check if lock file is up to date'; \
		echo '# --no-check-publish    Do not check for publish errors'; \
		$(COMPOSER) validate --strict --no-check-all; \
	fi

##@ XDebug

.PHONY: xdebug-on xdebug-off
xdebug-on: ## Enable Xdebug (mode=debug,develop) and restart the PHP container
	$(call title,Enable XDebug)
	@sed -i 's/^XDEBUG_MODE=.*/XDEBUG_MODE=debug,develop/' .env
	@echo "Enabled Xdebug (mode=debug,develop). Restarting php..."
	@$(DOCKER_COMPOSE) up -d php
xdebug-off: ## Disable Xdebug and restart the PHP container
	$(call title,Disable XDebug)
	@sed -i 's/^XDEBUG_MODE=.*/XDEBUG_MODE=off/' .env
	@echo "Disabled Xdebug. Restarting php..."
	@$(DOCKER_COMPOSE) up -d php

##@ Redis and Node

.PHONY: redis-on redis-off node-on node-off
redis-on: ## Enable Redis compose profile and recreate containers
	$(call title,Enable Redis)
	@sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=redis,$$(grep -oE ",node" .env || true)/' .env
	@echo "Enabled Redis. Restarting containers..."
	$(DOCKER_COMPOSE) down
	$(DOCKER_COMPOSE) up -d
redis-off: ## Disable Redis compose profile and recreate containers
	$(call title,Disable Redis)
	@sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=$$(grep -oE "node" .env || true)/' .env
	@echo "Disabled Redis. Restarting containers..."
	$(DOCKER_COMPOSE) down
	$(DOCKER_COMPOSE) up -d
node-on: ## Enable Node compose profile and recreate containers
	$(call title,Enable Node)
	@sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=$$(grep -oE "redis" .env || true),node/' .env
	@echo "Enabled Node. Restarting containers..."
	$(DOCKER_COMPOSE) down
	$(DOCKER_COMPOSE) up -d
node-off: ## Disable Node compose profile and recreate containers
	$(call title,Disable Node)
	@sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=$$(grep -oE "redis" .env || true)/' .env
	@echo "Disabled Node. Restarting containers..."
	$(DOCKER_COMPOSE) down
	$(DOCKER_COMPOSE) up -d
