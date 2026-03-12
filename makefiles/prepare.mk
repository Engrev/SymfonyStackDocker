.PHONY: _check-docker _default-ports _env _webserver _docker
_check-docker: # Check that Docker is installed and running
	$(call title,Check Docker)
	@command -v docker >/dev/null 2>&1 || \
		{ printf "$(RED)Docker is not installed. Install Docker Desktop / Docker Engine.\nPlease install Docker and then run 'make install' again.$(RESET)\n"; exit 1; }
	@docker info >/dev/null 2>&1 || \
		{ printf "$(RED)Docker is installed but not started. Launch Docker Desktop / start the Docker service.\nStart Docker and then run 'make install' again.$(RESET)\n"; exit 1; }
	@command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && printf "$(GREEN)✅ Docker installed and running.$(RESET)\n"

_default-ports: # Shows the default ports used (WEB, DB, REDIS)
	$(call title,Default ports)
	@printf "$(BOLD)WEB:$(RESET) 8080, $(BOLD)DB:$(RESET) 5432 (Postgres) / 3306 (MariaDB), $(BOLD)REDIS:$(RESET) 6379\n"

_env: # Configures the project interactively and writes .env.docker
	$(call title,Environment Variables)
	@bash makefiles/env.sh

_webserver: # Generates web server configuration from templates
	$(call title,Webserver configuration)
	@cp .docker/web/nginx/nginx.conf.tpl .docker/web/nginx/nginx.conf
	@cp .docker/web/nginx/vhost.conf.tpl .docker/web/nginx/vhost.conf
	$(call replace_in_file,.docker/web/nginx/vhost.conf,%%vhost%%,$(VHOST))
	@cp .docker/web/apache/vhost.conf.tpl .docker/web/apache/vhost.conf
	$(call replace_in_file,.docker/web/apache/vhost.conf,%%vhost%%,$(VHOST))
	$(call success,Webserver configuration success.)

_docker: # Rebuild images and restart all Docker services
	$(call title,Start docker)
	@$(DOCKER_COMPOSE_DOWN) --volumes
	@-docker compose pull --parallel --quiet --ignore-pull-failures 2> /dev/null
	@docker compose build
	@$(DOCKER_COMPOSE_UP)
