## Makefile for Dockerized Symfony Project
## Works on Linux/macOS and Windows via Git Bash or WSL

-include .env.docker
include $(wildcard makefiles/*.mk)
export

.PHONY: help
.DEFAULT_GOAL=help
help:
	$(call title,Help)
	@awk 'BEGIN {FS = ":.*## "; printf "\n$(BOLD)Usage$(RESET)\n  make $(CYAN)<command>$(RESET)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BOLD)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Project

.PHONY: install _prepare _setup banner reset _end
install: banner ## Install and start the project
	@$(MAKE) _prepare _setup _end
_prepare: _check-docker _default-ports _env _webserver _docker ## Prepare the environment (check Docker, configure env, generate webserver config, rebuild/start containers)
_setup: _symfony-app _assets _app-env _deps _update-hosts ## Set up the application (create Symfony app, configure assets and .env.local, install dev dependencies, update hosts)
_end:
	@printf "$(BLUE)"
	@printf "+===============================+\n"
	@printf "|     Installation complete     |\n"
	@printf "+===============================+\n"
	@printf "$(RESET)\n"
	@printf "$(BOLD)  Application   :$(RESET) http://$(VHOST):$(WEB_EXTERNAL_PORT) in your browser once Symfony boots.\n"
	@printf "$(BOLD)  Mailpit UI    :$(RESET) http://$(VHOST):8025.\n"
	@if [ "$database" = "mariadb" ]; then \
		printf "$(BOLD)  phpMyAdmin   :$(RESET) http://$(VHOST):$(PMA_EXTERNAL_PORT).\n"; \
	fi
	@printf "$(BOLD)  make help     :$(RESET) to see available commands.\n"

banner:
	@printf "$(BOLD)$(BLUE)"
	@printf "+==========================================+\n"
	@printf "|     Welcome to the setup assistant !     |\n"
	@printf "|    Please answer the questions below.    |\n"
	@printf "+==========================================+\n"
	@printf "$(RESET)"

reset: destroy ## Remove app and config files; run 'make install' afterward
	@rm -rf app 2>/dev/null
	@rm -f .docker/web/apache/vhost.conf 2>/dev/null
	@rm -f .docker/web/nginx/vhost.conf 2>/dev/null
	@rm -f .env.docker 2>/dev/null
	@rm -f .env 2>/dev/null
	@printf "\n$(GREEN)Reset complete. Run $(BOLD)make install$(RESET)$(GREEN) to reinitialize.$(RESET)\n"

##@ Docker containers

.PHONY: up down start stop restart restart-soft build build-no-cache destroy ps logs logs-php logs-web logs-db
up: ## Start all Docker services (detached mode)
	$(call title,Docker Up)
	@$(DOCKER_COMPOSE_UP)
	$(call success,Containers started successfully.)

down: ## Stop and remove containers and default resources
	$(call title,Docker Down)
	@$(DOCKER_COMPOSE_DOWN)
	$(call success,Containers stopped and removed successfully.)

start: ## Start all Docker services (attached mode)
	$(call title,Docker Start)
	@$(DOCKER_COMPOSE) up --remove-orphans
	$(call success,Containers started successfully.)

stop: ## Stop all Docker services
	$(call title,Docker Stop)
	@$(DOCKER_COMPOSE) stop
	$(call success,Containers stopped successfully.)

restart: ## Restart all Docker services (down and up)
	$(call title,Docker Restart)
	@$(MAKE) down
	@$(MAKE) up

restart-soft: ## Restart all Docker services (stop and start)
	$(call title,Docker Soft Restart)
	@$(MAKE) stop
	@$(MAKE) start

build: ## Build all Docker services
	$(call title,Docker Build)
	@$(DOCKER_COMPOSE) build
	$(call success,Docker images built successfully.)

build-no-cache: ## Build all Docker services (without cache)
	$(call title,Docker Build no cache)
	@$(DOCKER_COMPOSE) build --no-cache
	$(call success,Docker images built successfully (no cache).)

destroy: ## Force remove all containers, networks, volumes, and images created
	$(call title,Docker Destroy)
	@printf "\n$(YELLOW)/!\ This will remove all containers, images, networks, and volumes created by this project.\n"
	@printf "This action cannot be undone. Please confirm that you want to proceed.$(RESET)\n\n"
	@read -p "Are you sure ? (yes/no) : " confirm_destroy; \
	if [ "$$confirm_destroy" = "yes" ]; then \
		$(DOCKER_COMPOSE_DOWN); \
    	printf "\n$(GREEN)Project destroyed successfully.$(RESET)\n"; \
	else \
		printf "\n$(YELLOW)/!\ Action cancelled. No resources were removed.$(RESET)\n"; \
	fi

ps: ## List running Docker containers
	$(call title,Docker PS)
	@$(DOCKER_COMPOSE) ps

logs: ## Affiche les logs (tous les services)
	$(call title,Docker logs)
	@$(DOCKER_COMPOSE) logs -f --tail=100

logs-php: ## Logs du container PHP
	$(call title,Docker PHP logs)
	@$(DOCKER_COMPOSE) logs -f --tail=100 php

logs-web: ## Logs du serveur web
	$(call title,Docker webserver logs)
	@$(DOCKER_COMPOSE) logs -f --tail=100 web-nginx web-apache

logs-db: ## Logs de la base de données
	$(call title,Docker database logs)
	@$(DOCKER_COMPOSE) logs -f --tail=100 db-mariadb db-postgres

##@ Terminals

.PHONY: terminal-php terminal-web terminal-db terminal-root
terminal-php: ## Open an interactive shell in the PHP container
	$(call title,Terminal PHP)
	@if [ "$$OS" = "Windows_NT" ]; then \
		winpty $(EXEC_IN_APP) bash; \
	else \
		$(EXEC_IN_APP) bash; \
	fi

terminal-web: ## Open an interactive shell in the webserver container
	$(call title,Terminal webserver)
	@if [ "$$OS" = "Windows_NT" ]; then \
		winpty docker exec -it $(PROJECT_SLUG)-web bash; \
	else \
		docker exec -it $(PROJECT_SLUG)-web bash; \
	fi

terminal-db: ## Open an interactive shell in the database container
	$(call title,Terminal database)
	@if [ "$$OS" = "Windows_NT" ]; then \
		winpty docker exec -it $(PROJECT_SLUG)-db bash; \
	else \
		docker exec -it $(PROJECT_SLUG)-db bash; \
	fi

terminal-root: ## Open an interactive root shell in the PHP container
	$(call title,Root Terminal)
	@if [ "$$OS" = "Windows_NT" ]; then \
		winpty $(EXEC_IN_APP_ROOT) bash; \
	else \
		$(EXEC_IN_APP_ROOT) bash; \
	fi

##@ Composer

.PHONY: composer composer-install composer-update composer-dump-autoload composer-outdated
composer: ## Execute a Composer command inside the PHP container; pass extra args with ARGS="require..."
	$(call title,Composer)
	@$(COMPOSER) $(ARGS)

composer-install: ## Install PHP dependencies
	$(call title,Composer install)
	@$(COMPOSER) install

composer-update: ## Update PHP dependencies
	$(call title,Composer update)
	@$(COMPOSER) update

composer-dump: ## Optimize Composer autoloader
	$(call title,Composer dump-autoload)
	@$(COMPOSER) dump-autoload -o

composer-outdated: ## Show outdated Composer dependencies
	$(call title,Composer outdated)
	@$(COMPOSER) outdated

##@ Symfony

.PHONY: console cc assets db-create db-drop db-schema-update db-migrate db-fixtures db-fixtures-append dr ds env-check
console: ## Run Symfony Console inside the container; pass extra args with ARGS="..."
	$(call title,Symfony Console)
	$(SF_CONSOLE) $(ARGS);

cc: ## Clear the Symfony application cache
	$(call title,Clear app cache)
	@$(SF_CONSOLE) cache:clear

assets: ## Install assets
	@$(SF_CONSOLE) assets:install

dr: ## List Symfony routes
	$(call title,Debug routes)
	@$(SF_CONSOLE) debug:router

ds: ## List Symfony services
	$(call title,Debug services)
	@$(SF_CONSOLE) debug:container

env-check: ## Check Symfony environment and configuration
	$(call title,Check Symfony environment)
	@$(SF_CONSOLE) about

##@ Frontend

.PHONY: npm npm-install assets assets-watch
npm: ## Run an npm command inside the NPM container; pass extra args with ARGS="..."
	$(call title,NPM)
	$(NPM) $(ARGS)
npm-install: ## Install Node dependencies (npm install) inside the NPM container
	$(call title,NPM install)
	$(NPM) install
webpack: ## Build assets (Encore)
	$(call title,Webpack dev)
	@if [ "$$APP_ENV" = "dev" ]; then \
		$(NPM) run dev; \
	else \
		printf "\n$(YELLOW)Cette commande ne s'exécute qu'en développement.$(RESET)\n"; \
	fi
webpack-watch: ## Build assets in watch mode (Encore)
	$(call title,Webpack watch)
	@if [ "$$APP_ENV" = "dev" ]; then \
		$(NPM) run watch; \
	else \
		printf "\n$(YELLOW)Cette commande ne s'exécute qu'en développement.$(RESET)\n"; \
	fi
webpack-build: ## Build assets in production mode (minified)
	$(call title,Webpack build)
	@if [ "$$APP_ENV" = "prod" ]; then \
		$(NPM) run build; \
	else \
		printf "\n$(YELLOW)Cette commande ne s'exécute qu'en production.$(RESET)\n"; \
	fi

##@ Tests

.PHONY: tests php-cs-check php-cs-fixer phpstan phpunit phpunit-coverage twigcs lint-yaml lint-twig lint-container eslint eslint-fix security-check
tests: ## Run all tests
	$(call title,Run all tests)
	@$(MAKE) php-cs-check phpstan lint-yaml lint-twig phpunit

php-cs-check: ## Check PHP coding standards with php-cs-fixer (dry-run)
	$(call title,PHP CS Fixer check)
	@$(PHP) vendor/bin/php-cs-fixer --ansi fix --show-progress=dots --diff --dry-run

php-cs-fixer: ## Fix PHP coding standards with php-cs-fixer (in-place)
	$(call title,PHP CS Fixer)
	@$(PHP) vendor/bin/php-cs-fixer --ansi fix --show-progress=dots --diff

phpstan: ## Run PHPStan static analysis
	$(call title,PHPStan)
	@$(PHP) vendor/bin/phpstan --ansi analyse

phpunit: ## Run PHPUnit tests
	$(call title,PHPUnit)
	@$(PHP) bin/phpunit --ansi $(ARGS)

phpunit-coverage: ## Run PHPUnit tests with code coverage report (HTML)
	$(call title,PHPUnit)
	@$(PHP) bin/phpunit --ansi --coverage-html var/coverage $(ARGS)

twigcs: ## Check Twig coding standards with twigcs
	$(call title,Twig CS)
	$(PHP) vendor/bin/twigcs --ansi templates/

lint-yaml: ## Lint YAML configuration files
	$(call title,Lint YAML)
	$(SF_CONSOLE) --ansi lint:yaml config/ --parse-tags

lint-twig: ## Lint Twig templates
	$(call title,Lint Twig)
	$(SF_CONSOLE) --ansi lint:twig templates/

lint-container: ## Lint services container
	$(call title,Lint container)
	$(SF_CONSOLE) --ansi lint:container

eslint: ## Run ESLint on frontend assets
	$(call title,ESLint)
	$(DOCKER_COMPOSE_EXEC) node ./node_modules/.bin/eslint assets/ --ext .js,.ts,.vue

eslint-fix: ## Run ESLint with --fix to automatically fix issues in frontend assets
	$(call title,ESLint Fix)
	$(DOCKER_COMPOSE_EXEC) node ./node_modules/.bin/eslint assets/ --ext .js,.ts,.vue --fix

security-check: ## Run Symfony security checker to check for known vulnerabilities in PHP dependencies
	$(call title,Security Check)
	@$(EXEC_IN_APP) symfony security:check 2>/dev/null || $(EXEC_IN_APP) composer audit

##@ Database

.PHONY: db-create db-drop db-reset db-schema-update db-migration db-migrations-diff db-migrate db-fixtures db-fixtures-append db-reset-fixtures db-dump db-import
db-create: ## Create the database if it does not exist
	$(call title,Create database)
	@$(SF_CONSOLE) doctrine:database:create --if-not-exists

db-drop: ## Drop the database if it exists
	$(call title,Drop database)
	@$(SF_CONSOLE) doctrine:database:drop --force --if-exists

db-reset: ## Reset the database (drop, create, migrate)
	$(call title,Reset database)
	@$(MAKE) db-drop db-create db-migrate

db-schema-update: ## Update the database schema to match the current mapping metadata
	$(call title,Update database schema)
	@$(SF_CONSOLE) doctrine:schema:update --force

db-migration: ## Generate a new Doctrine migration based on the current mapping metadata
	$(call title,Doctrine migrations)
	@$(SF_CONSOLE) doctrine:migrations:generate

db-migrations-diff: ## Generate a new Doctrine migration by comparing the current database schema with the mapping metadata
	$(call title,Doctrine migrations diff)
	@$(SF_CONSOLE) doctrine:migrations:diff

db-migrate: ## Run Doctrine migrations
	$(call title,Doctrine migrate)
	@$(SF_CONSOLE) doctrine:migrations:migrate --no-interaction

db-fixtures: ## Load Doctrine fixtures (database purged before loading)
	$(call title,Load doctrine fixtures)
	@$(SF_CONSOLE) doctrine:fixtures:load --no-interaction

db-fixtures-append: ## Load Doctrine fixtures (database not purged before loading)
	$(call title,Load doctrine fixtures without purge)
	@$(SF_CONSOLE) doctrine:fixtures:load --append --no-interaction

db-reset-fixtures: ## Reset the database and load fixtures
	$(call title,Reset database and load fixtures)
	@$(MAKE) db-reset db-fixtures

db-dump: ## Dump the database schema and data to a SQL file
	$(call title,Dump database)
	@mkdir -p var
	@if echo "$(COMPOSE_PROFILES)" | grep -q "mariadb"; then \
		docker exec -e MYSQL_PWD='$(APP_DB_PASSWORD)' $(PROJECT_SLUG)-db mysqldump -u$(APP_DB_USER) --add-drop-table $(APP_DB_NAME) > var/dump.sql; \
	elif echo "$(COMPOSE_PROFILES)" | grep -q "postgres"; then \
		docker exec -e PGPASSWORD='$(APP_DB_PASSWORD)' $(PROJECT_SLUG)-db pg_dump -U $(APP_DB_USER) --clean --if-exists $(APP_DB_NAME) > var/dump.sql; \
	else \
		printf "$(RED)Error : No database engine (mariadb or postgres) found in COMPOSE_PROFILES.$(RESET)\n"; exit 1; \
	fi
	$(call success,Database dumped to var/dump.sql)

db-import: ## Import a SQL file into the database; pass file path with ARGS="path/to/file.sql"
	$(call title,Import database)
	@$(eval FILE=$(if $(ARGS),$(ARGS),var/dump.sql))
	@if [ ! -f "$(FILE)" ]; then \
		printf "$(RED)Error : File '$(FILE)' not found.$(RESET)\n"; \
		exit 1; \
	fi
	@if echo "$(COMPOSE_PROFILES)" | grep -q "mariadb"; then \
		docker exec -i -e MYSQL_PWD='$(APP_DB_PASSWORD)' $(PROJECT_SLUG)-db mysql -u$(APP_DB_USER) $(APP_DB_NAME) < $(FILE); \
	elif echo "$(COMPOSE_PROFILES)" | grep -q "postgres"; then \
		docker exec -i -e PGPASSWORD='$(APP_DB_PASSWORD)' $(PROJECT_SLUG)-db psql -U $(APP_DB_USER) -d $(APP_DB_NAME) < $(FILE); \
	else \
		printf "$(RED)Error : No database engine (mariadb or postgres) found in COMPOSE_PROFILES.$(RESET)\n"; exit 1; \
	fi
	$(call success,Database imported successfully from $(FILE))

##@ XDebug

.PHONY: xdebug-on xdebug-off
xdebug-on: ## Enable Xdebug in debug and develop modes, then restart the PHP container
	$(call title,Enable XDebug)
	@sed -i 's/^XDEBUG_MODE=.*/XDEBUG_MODE=debug,develop/' .env
	@printf "\n$(CYAN)Enabled Xdebug (mode=debug,develop). Restarting php...$(RESET)\n"
	@docker compose up -d php
	$(call success,Xdebug enabled successfully.)

xdebug-off: ## Disable Xdebug, then restart the PHP container
	$(call title,Disable XDebug)
	@sed -i 's/^XDEBUG_MODE=.*/XDEBUG_MODE=off/' .env
	@printf "\n$(CYAN)Disabled Xdebug. Restarting php...$(RESET)\n"
	@docker compose up -d php
	$(call success,Xdebug disabled successfully.)

##@ Redis

.PHONY: redis-on redis-off
redis-on: ## Enable Redis compose profile, set default port, add REDIS_URL to .env.local if not exists, and recreate containers
	$(call title,Enable Redis)
	@sed -i '/^COMPOSE_PROFILES=/ { /redis/! s/$$/,redis/; s/=,/=/; }' .env
	@sed -i 's/^REDIS_EXTERNAL_PORT=.*/REDIS_EXTERNAL_PORT=6379/' .env
	@if [ -f app/.env.local ] && ! grep -q "REDIS_URL" app/.env.local; then \
		echo "REDIS_URL=redis://redis:6379" >> app/.env.local; \
		printf "\n$(CYAN)REDIS_URL added to app/.env.local.$(RESET)\n"
	fi
	@$(DOCKER_COMPOSE_UP)
	$(call success,Redis enabled successfully.)

redis-off: ## Disable Redis compose profile and recreate containers
	$(call title,Disable Redis)
	@sed -i '/^COMPOSE_PROFILES=/ { s/redis//g; s/,,/,/g; s/=,/=/; s/,$//; }' .env
	@if [ -f app/.env.local ]; then \
		sed -i 's/^REDIS_URL=/#REDIS_URL=/g' app/.env.local; \
	fi
	@$(DOCKER_COMPOSE_UP)
	$(call success,Redis disabled successfully.)

