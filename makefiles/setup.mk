.PHONY: _symfony-app _assets _app-env _deps _update-hosts
_symfony-app: ## Create the Symfony application in ./app
	$(call title,Setup Symfony app)
	@if [ -d app ]; then \
		if [ -f app/bin/console ]; then \
			read -p "./app exists and seems to be a Symfony project. Reuse it ? [y/n] : " reuse; \
			if [ "$$reuse" = "n" ] || [ "$$reuse" = "N" ]; then \
				read -p "This will remove ./app. Continue ? [y/n] : " confirm; \
				if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then rm -rf app; fi; \
			fi; \
		else \
			if [ "$$(ls -A app | grep -Ev '^(node_modules|\.git)$$' | wc -l)" -gt 0 ]; then \
				printf "\n$(YELLOW)./app exists but is not a valid Symfony project (bin/console missing) and is not empty.$(RESET)\n"; \
				read -p "Clean ./app and start new Symfony project ? [y/n] : " confirm; \
				if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
					rm -rf app; \
				else \
					printf "$(RED)Error: Symfony project creation skipped, but directory is not empty.$(RESET)\n"; \
					printf "$(RED)Please empty ./app or move it before running make install.$(RESET)\n"; \
					exit 1; \
				fi; \
			fi; \
		fi; \
	fi
	@if [ ! -d app ] || [ ! -f app/bin/console ]; then \
		mkdir -p app; \
	    printf "\n$(CYAN)Creating Symfony project in ./app ...$(RESET)\n"; \
		$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) 'git config --global user.email "dev@local.host" && git config --global user.name "Dev Local" && git config --global --add safe.directory .'; \
		if [ "$(DIST)" = "webapp" ]; then \
			if [ "$(SYMFONY_VERSION)" = "stable" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "rm -rf _tmp && symfony new _tmp --webapp --no-interaction && shopt -s dotglob && mv _tmp/* . && rmdir _tmp && rm -rf .git" || exit 1; \
			elif [ "$(SYMFONY_VERSION)" = "lts" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "rm -rf _tmp && symfony new _tmp --version=$(SYMFONY_VERSION) --webapp --no-interaction && shopt -s dotglob && mv _tmp/* . && rmdir _tmp && rm -rf .git" || exit 1; \
			else \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "rm -rf _tmp && symfony new _tmp --version='$(SYMFONY_VERSION)' --webapp --no-interaction && shopt -s dotglob && mv _tmp/* . && rmdir _tmp && rm -rf .git" || exit 1; \
			fi; \
			if [ "$(WEB_SERVER)" = "apache" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "composer require symfony/apache-pack --no-interaction" || exit 1; \
			fi; \
		else \
			if [ "$(SYMFONY_VERSION)" = "stable" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "rm -rf _tmp && symfony new _tmp --no-interaction && shopt -s dotglob && mv _tmp/* . && rmdir _tmp && rm -rf .git" || exit 1; \
			elif [ "$(SYMFONY_VERSION)" = "lts" ]; then \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "rm -rf _tmp && symfony new _tmp --version=$(SYMFONY_VERSION) --no-interaction && shopt -s dotglob && mv _tmp/* . && rmdir _tmp && rm -rf .git" || exit 1; \
			else \
				$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "rm -rf _tmp && symfony new _tmp --version='$(SYMFONY_VERSION)' --no-interaction && shopt -s dotglob && mv _tmp/* . && rmdir _tmp && rm -rf .git" || exit 1; \
			fi; \
			$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "composer require api --no-interaction" || exit 1; \
		fi; \
		cp phpstan.dist.neon app/phpstan.dist.neon; \
		printf "\n$(GREEN)./app created.$(RESET)\n"; \
	fi

_assets: ## Configures assets (Asset Mapper or Webpack Encore)
	$(call title,Setup Assets)
	@if [ "$(ASSETS)" = "webpack" ]; then \
		printf "\n$(CYAN)Setting up Webpack Encore...$(RESET)\n"; \
		$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "set -e; composer require symfony/webpack-encore-bundle --no-interaction"; \
		$(DOCKER_COMPOSE_EXEC_ROOT_NO_TTY) node $(WITH_BASH) "chown -R www-data:www-data /home/www-data /var/www/html/node_modules" || true; \
		$(DOCKER_COMPOSE_EXEC_NO_TTY) node $(WITH_BASH) "set -e && \
			if [ ! -f package.json ]; then npm init -y; fi && \
			npm install --save-dev @symfony/webpack-encore webpack webpack-cli core-js regenerator-runtime && \
			mkdir -p assets/styles && \
			if [ ! -f assets/app.js ]; then echo \"import './styles/app.css';\" > assets/app.js; fi && \
			if [ ! -f assets/styles/app.css ]; then echo '/* app styles */' > assets/styles/app.css; fi && \
			if [ ! -f webpack.config.js ]; then ./node_modules/.bin/encore init --no-interaction || true; fi && \
			npm install"; \
	else \
		printf "\n$(CYAN)Trying to set up Asset Mapper...$(RESET)\n"; \
		if $(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "set -e; composer require symfony/asset-mapper --no-interaction"; then :; \
		else \
			printf "$(YELLOW)Asset Mapper may be unsupported for this Symfony version. Falling back to Webpack Encore...$(RESET)"; \
			if grep -q '^COMPOSE_PROFILES=' .env.docker; then \
				sed -i 's/^COMPOSE_PROFILES=.*/&,node/' .env.docker; \
			else \
				echo 'COMPOSE_PROFILES=node' >> .env.docker; \
			fi; \
			$(DOCKER_COMPOSE_UP) --build node; \
			$(DOCKER_COMPOSE_EXEC_NO_TTY) php $(WITH_BASH) "set -e; composer require symfony/webpack-encore-bundle --no-interaction"; \
			$(DOCKER_COMPOSE_EXEC_ROOT_NO_TTY) node $(WITH_BASH) "chown -R www-data:www-data /home/www-data /var/www/html/node_modules" || true; \
			$(DOCKER_COMPOSE_EXEC_NO_TTY) node $(WITH_BASH) "set -e && \
				if [ ! -f package.json ]; then npm init -y; fi && \
				npm install --save-dev @symfony/webpack-encore webpack webpack-cli core-js regenerator-runtime && \
				mkdir -p assets/styles && \
				if [ ! -f assets/app.js ]; then echo \"import './styles/app.css';\" > assets/app.js; fi && \
				if [ ! -f assets/styles/app.css ]; then echo '/* app styles */' > assets/styles/app.css; fi && \
				if [ ! -f webpack.config.js ]; then ./node_modules/.bin/encore init --no-interaction || true; fi && \
				npm install"; \
		fi; \
	fi

_app-env: ## Generates app/.env.local (DB_URL, Mailpit DSN, REDIS_URL if enabled)
	$(call title,Setup app/.env.local)
	@if [ -f app/.env.local ]; then \
		printf "\n$(CYAN)app/.env.local already exists.$(RESET)\n"; \
	else \
		if [ "$(DB)" = "postgres" ]; then \
			server_version=$$( $(call get_postgres_server_version,$(PROJECT_SLUG)) ); \
			db_url="postgresql:\/\/$(APP_DB_USER):$(APP_DB_PASSWORD)@db:$(DB_INTERNAL_PORT)\/$(APP_DB_NAME)?serverVersion=$$server_version\&charset=utf8"; \
		else \
			server_version=$$( $(call get_mysql_server_version,$(PROJECT_SLUG)) ); \
			db_url="mysql:\/\/$(APP_DB_USER):$(APP_DB_PASSWORD)@db:$(DB_INTERNAL_PORT)\/$(APP_DB_NAME)?serverVersion=$$server_version\&charset=utf8mb4"; \
		fi; \
		cp .env.local.dist app/.env.local; \
		sed -i "s/%%DATABASE%%/$$db_url/g" app/.env.local; \
		sed -i "s/%%DSN%%/smtp:\/\/mailpit:1025/g" app/.env.local; \
		if [ ! -z "$(REDIS_EXTERNAL_PORT)" ]; then echo "REDIS_URL=redis://redis:$(REDIS_EXTERNAL_PORT)" >> app/.env.local; fi; \
		printf "\n$(GREEN)app/.env.local created.$(RESET)\n"; \
	fi

_deps: ## Installs development dependencies (tests, PHPStan, CS Fixer, TwigCS)
	$(call title,Setup dev dependencies)
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

_update-hosts: ## Updates the OS hosts file with the VHOST (best-effort)
	$(call title,Update hosts file)
	@bash makefiles/host.sh "${VHOST}"
