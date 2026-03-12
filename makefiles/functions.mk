define title
	@{ \
		set -e; \
		msg="$(if $(strip $(1)),$(1),Make $@)"; \
		line2="|     $$msg     |"; \
		len=$${#line2}; \
		dashes=""; \
		for i in $$(seq 1 $$((len-2))); do \
			dashes="$$dashes="; \
		done; \
		line1="+$$dashes+"; \
		echo -e "\n$(BOLD)$(BLUE)$$line1"; \
		echo "$$line2"; \
		echo -e "$$line1$(RESET)"; \
	}
endef
# Slugify helper: lowercase, replace non-alnum with hyphen, squeeze, trim
# $(call slugify,string)
define slugify
	@printf "$(1)" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$$//'
endef
define replace_in_file
	@bash -c "sed -i 's|$(2)|$(3)|g' $(1)"
endef
define get_postgres_server_version
	docker exec "$(1)-db" sh -c "psql --version || postgres --version" | grep -Eo "[0-9]+\.[0-9]+(\.[0-9]+)?" | head -n1
endef
define get_mysql_server_version
	docker exec "$(1)-db" sh -c "(mariadb --version 2>/dev/null || mysql --version 2>/dev/null || mariadbd --version 2>/dev/null || mysqld --version 2>/dev/null)" | grep -Eo "[0-9]+\.[0-9]+(\.[0-9]+)?(-MariaDB)?" | head -n1
endef
define success
	@printf "$(GREEN)✅ %b$(RESET)\n" "$(1)"
endef
define warning
	@printf "$(YELLOW)⚠️ %b$(RESET)\n" "$(1)"
endef
define info
	@printf "$(CYAN)ℹ️ %b$(RESET)\n" "$(1)"
endef
define error
	@printf "$(RED)❌ Erreur : %b$(RESET)\n" "$(1)"; exit 1
endef
