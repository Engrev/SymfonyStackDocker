## ════════════════════════════════════════════════════════════════
##  ci.mk — CI Targets (Continuous Integration)
##
##  Configurable variables:
##    CI_ENV_FILE   CI environment file (default: .env.ci)
##    CI_COMPOSE    CI compose file override
## ════════════════════════════════════════════════════════════════

##@ CI

# ── CI Variables ─────────────────────────────────────────────────
CI_ENV_FILE     ?= .env.ci
CI_COMPOSE_FILE ?= docker-compose.ci.yml

# All Docker Compose CI commands pass through here.
DOCKER_COMPOSE_CI = docker compose -f $(CI_COMPOSE_FILE) --env-file $(CI_ENV_FILE)

# Execution in the PHP CI container (always -T because there is no TTY in CI)
CI_EXEC         = $(DOCKER_COMPOSE_CI) exec -T --user=www-data:www-data php
CI_EXEC_ROOT    = $(DOCKER_COMPOSE_CI) exec -T --user=root:root php
CI_PHP          = $(CI_EXEC) php
CI_COMPOSER     = $(CI_EXEC) composer --ansi --no-interaction
CI_CONSOLE      = $(CI_EXEC) php bin/console --ansi --no-interaction
CI_WITH_BASH    = bash -c

.PHONY: ci ci-build ci-up ci-down ci-install ci-migrate ci-lint ci-test ci-coverage ci-status ci-logs

# ─────────────────────────────────────────────────────────────────
#  Full Pipeline
# ─────────────────────────────────────────────────────────────────
ci: ## Full CI Pipeline (build → up → install → migrate → lint → test → down)
	$(call title,CI Pipeline)
	@$(MAKE) ci-build
	@$(MAKE) ci-up
	@$(MAKE) ci-install
	@$(MAKE) ci-migrate
	@$(MAKE) ci-lint
	@$(MAKE) ci-test
	@$(MAKE) ci-down
	$(call success,CI pipeline completed successfully.)

# ────────────────────────────────────────────────────────────────
#  CI Infrastructure
# ────────────────────────────────────────────────────────────────
ci-build: ## Build the PHP image for CI
	$(call title,CI Build)
	@$(DOCKER_COMPOSE_CI) build --pull php
	$(call success,CI image built.)

ci-up: ## Start CI containers (detached)
	$(call title,CI Up)
	@$(DOCKER_COMPOSE_CI) up -d --wait --remove-orphans
	$(call success,CI containers started.)

ci-down: ## Stop and remove CI containers
	$(call title,CI Down)
	@$(DOCKER_COMPOSE_CI) down --remove-orphans --volumes
	$(call success,CI containers stopped and cleaned.)

ci-status: ## CI containers status
	@$(DOCKER_COMPOSE_CI) ps

ci-logs: ## CI containers logs
	@$(DOCKER_COMPOSE_CI) logs --tail=100

# ────────────────────────────────────────────────────────────────
#  Dependencies installation
# ────────────────────────────────────────────────────────────────
ci-install: ## Install Composer dependencies (env=test)
	$(call title,CI Composer install)
	@$(CI_EXEC_ROOT) chown -R www-data:www-data /var/www/html
	@$(CI_COMPOSER) install --prefer-dist --optimize-autoloader $(if $(ARGS),$(ARGS),)
	$(call success,Dependencies installed.)

# ────────────────────────────────────────────────────────────────
#  Database
# ────────────────────────────────────────────────────────────────
ci-migrate: ## Create test DB and run migrations
	$(call title,CI Database setup)
	@$(CI_CONSOLE) doctrine:database:create --if-not-exists --env=test
	@$(CI_EXEC) bash -c 'if ls migrations/Version*.php >/dev/null 2>&1; then php bin/console doctrine:migrations:migrate --no-interaction --env=test; else echo "No migrations found, skipping..."; fi'
	@$(CI_CONSOLE) doctrine:schema:update --force --env=test
	$(call success,Database ready.)

ci-db-fixtures: ## Load fixtures into test DB
	$(call title,CI Fixtures)
	@$(CI_CONSOLE) doctrine:fixtures:load --no-interaction --env=test
	$(call success,Fixtures loaded.)

# ────────────────────────────────────────────────────────────────
#  Code Quality — Linters
# ────────────────────────────────────────────────────────────────
ci-lint: ## Run all linters (cs-check, phpstan, lint-yaml, lint-twig, lint-container)
	$(call title,CI Lint)
	@$(MAKE) ci-cs-check
	@$(MAKE) ci-phpstan
	@$(MAKE) ci-lint-yaml
	@$(MAKE) ci-lint-twig
	@$(MAKE) ci-lint-container
	$(call success,All linters passed.)

ci-cs-check: ## PHP CS Fixer — check (dry-run)
	$(call title,CI CS Check)
	@$(CI_PHP) vendor/bin/php-cs-fixer --ansi fix \
		--show-progress=dots --diff --dry-run \
		--stop-on-violation

ci-phpstan: ## PHPStan — static analysis
	$(call title,CI PHPStan)
	@$(CI_PHP) vendor/bin/phpstan --ansi analyse \
		--memory-limit=512M --no-progress

ci-twigcs: ## TwigCS — templates linting
	$(call title,CI TwigCS)
	@$(CI_PHP) vendor/bin/twigcs --ansi templates/

ci-lint-yaml: ## YAML files linting
	$(call title,CI Lint YAML)
	@$(CI_CONSOLE) lint:yaml config/ --parse-tags

ci-lint-twig: ## Twig templates linting
	$(call title,CI Lint Twig)
	@$(CI_CONSOLE) lint:twig templates/

ci-lint-container: ## Symfony service container validation
	$(call title,CI Lint Container)
	@$(CI_CONSOLE) lint:container

ci-security: ## Composer dependencies audit (vulnerabilities)
	$(call title,CI Security Check)
	@$(CI_EXEC) composer audit

# ────────────────────────────────────────────────────────────────
#  PHPUnit Tests
# ────────────────────────────────────────────────────────────────
ci-test: ## Run PHPUnit (env=test, without coverage)
	$(call title,CI PHPUnit)
	@$(CI_PHP) bin/phpunit \
		--testdox \
		$(if $(ARGS),$(ARGS),)
	$(call success,Tests passed.)

ci-coverage: ## PHPUnit with HTML coverage report (var/coverage/)
	$(call title,CI PHPUnit Coverage)
	@$(CI_EXEC_ROOT) bash -c \
		"sed -i 's/xdebug.mode=.*/xdebug.mode=coverage/' \
		/usr/local/etc/php/conf.d/96-xdebug.ini 2>/dev/null || true"
	@$(DOCKER_COMPOSE_CI) restart php
	@sleep 3
	@$(CI_PHP) bin/phpunit --ansi \
		--coverage-html var/coverage \
		--coverage-text \
		$(if $(ARGS),$(ARGS),)
	$(call success,Coverage report generated in app/var/coverage/)

ci-coverage-clover: ## PHPUnit with Clover XML report (for SonarQube / Codecov)
	$(call title,CI Coverage Clover)
	@$(CI_PHP) bin/phpunit --ansi \
		--coverage-clover var/coverage/clover.xml \
		$(if $(ARGS),$(ARGS),)
	$(call success,Clover XML generated in app/var/coverage/clover.xml)
