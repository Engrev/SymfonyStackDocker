# ── Docker ────────────────────────────────────────────────────────
DOCKER_COMPOSE_UP           = docker compose up -d --remove-orphans
DOCKER_COMPOSE_DOWN         = docker compose down --remove-orphans

# ── Execution in containers ───────────────────────────────────────
DOCKER_EXEC                 = docker exec --user=www-data:www-data
DOCKER_EXEC_ROOT            = docker exec --user=root:root
DOCKER_COMPOSE_EXEC         = docker compose exec --user=www-data:www-data
DOCKER_COMPOSE_EXEC_ROOT    = docker compose exec --user=root:root
DOCKER_COMPOSE_EXEC_ROOT_NO_TTY = docker compose exec -T --user=root:root
DOCKER_COMPOSE_EXEC_NO_TTY  = docker compose exec -T --user=www-data:www-data
DOCKER_COMPOSE_RUN          = docker compose run --user=www-data:www-data

# ── PHP container shortcuts ───────────────────────────────────────
WITH_BASH                   = bash -lc
EXEC_IN_APP                 = $(DOCKER_COMPOSE_EXEC) php
EXEC_IN_APP_ROOT            = $(DOCKER_COMPOSE_EXEC_ROOT) php

# ── PHP tools ─────────────────────────────────────────────────────
PHP                         = $(EXEC_IN_APP) php
COMPOSER                    = $(EXEC_IN_APP) composer --ansi --no-interaction
SF_BIN_CONSOLE              = $(EXEC_IN_APP) bin/console --ansi
ifeq ($(INSTALL_SYMFONY_CLI),1)
    SF_CONSOLE              = $(EXEC_IN_APP) symfony console --ansi
else
    SF_CONSOLE              = $(SF_BIN_CONSOLE)
endif

# ── Frontend ──────────────────────────────────────────────────────
NPM                         = $(DOCKER_COMPOSE_EXEC) node npm
WEBPACK                     = $(NPM) run encore
