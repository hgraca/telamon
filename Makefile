# Mute all `make` specific output. Comment this out to get some debug information.
.SILENT:
.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory
SHELL=/bin/bash
EXEC_SHELL=/bin/bash
# if there is a file or folder with the name of the target, add to the phony list:
.PHONY: app
# SECONDEXPANSION is needed to be able to resolve `psr4: .docker-wrap-$$@` to `psr4: .docker-wrap-psr4`
.SECONDEXPANSION:

ARCH := $(shell uname -m)
OS := $(shell uname -s 2>/dev/null)
ROOT_PATH := $(shell cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
UID ?= "$(shell id -u)"
GID ?= "$(shell id -g)"

ifneq ("$(wildcard Makefile.proj.mk)","")
  include Makefile.proj.mk
endif

ifneq ("$(wildcard Makefile.local.mk)","")
  include Makefile.local.mk
endif

ifneq ("$(wildcard Makefile.vars.local.mk)","")
  include Makefile.vars.local.mk
endif

_IS_WORKTREE := $(shell [ "$$(git rev-parse --git-dir 2>/dev/null)" != "$$(git rev-parse --git-common-dir 2>/dev/null)" ] && echo 1 || echo 0)
_DIR_NAME := $(shell basename $(CURDIR))
ifeq ($(_IS_WORKTREE),1)
  ifdef PROJECT_NAME
    PROJECT_NAME := $(_DIR_NAME)-$(PROJECT_NAME)
  else
    PROJECT_NAME := $(_DIR_NAME)
  endif
else
  PROJECT_NAME ?= $(_DIR_NAME)
endif
ENV_VARS=env UID=${UID} GID=${GID} DEV_APP_IMG=${DEV_APP_IMG} JAVA_OPTS=${JAVA_OPTS} PROJECT_NAME=${PROJECT_NAME}

# use when the container is not booted yet
RUN=$(ENV_VARS) docker compose run --rm app
# use when the container is already booted
EXEC=docker exec -it --workdir /app --user ${UID}:${GID} ${PROJECT_NAME}-app-1
EXEC_ROOT=docker exec -it --workdir /app --user 0:0 ${PROJECT_NAME}-app-1
SH=$(EXEC) /bin/bash

IS_DOCKER := $(shell ./scripts/is-in-docker.sh)

COMPOSE_PROFILES :=
ifneq ($(shell grep -s '^LANGFUSE_ENABLED=true' .env),)
  COMPOSE_PROFILES := $(COMPOSE_PROFILES) --profile langfuse
endif
ifneq ($(shell grep -s '^GRAPHITI_ENABLED=true' .env),)
  COMPOSE_PROFILES := $(COMPOSE_PROFILES) --profile graphiti
endif


.docker-wrap-%:
ifeq ($(IS_DOCKER),1)
	$(MAKE) ".$*"
else
	$(EXEC) $(MAKE) ".$*"
endif

.docker-wrap-root-%:
ifeq ($(IS_DOCKER),1)
	$(MAKE) ".$*"
else
	$(EXEC_ROOT) $(MAKE) ".$*"
endif

# .DEFAULT: If the command does not exist in this makefile
# default: If no command was specified
.DEFAULT default:
	if [ -f ./Makefile.custom.mk ]; then \
	    $(MAKE) -f Makefile.custom.mk "$@"; \
	else \
	    if [ "$@" != "default" ]; then echo "Command '$@' not found."; fi; \
	    $(MAKE) help; \
	    if [ "$@" != "default" ]; then exit 2; fi; \
	fi

help:  ## Show this help
	@echo
	@echo "Usage:"
	@echo "     [ENV=VALUE] [...] make [command] [ARG=VALUE]"
	@echo "     make my-target"
	@echo "     NAMESPACE=\"dummy-app-namespace\" RELEASE_NAME=\"another-dummy-app\" make my-target"
	@echo
	@echo
	@echo "Available commands:"
	@echo
	@for file in Makefile Makefile.proj.mk Makefile.local.mk; do \
		if [ -f $$file ]; then \
			echo "$$file"; \
			echo ""; \
			grep -E '^[^#[:space:]].*:' $$file | \
			grep -vE '^default|^\.|^_|=' | \
			awk -F: '{\
				target=$$1; \
				match($$0, /##[[:space:]]*(.*)/); \
				desc = RSTART ? substr($$0, RSTART+3, RLENGTH-3) : ""; \
				printf "  \033[36m%-50s\033[0m %s\n", target, desc \
			}'; \
			echo; \
		fi \
	done

up: ## Start Telamon: install host tools, then bring docker compose services up
	@test -f .env || cp .env.dist .env
	@test -f .telamon.jsonc || cp .telamon.dist.jsonc .telamon.jsonc
	echo -e "\n\033[1m\033[34m━━━ Installing prerequisites (homebrew, docker)... ━━━\033[0m"
	bash bin/install.sh --pre-docker
	echo -e "\n\033[1m\033[34m━━━ Bringing up services... ━━━\033[0m"
	docker compose \
		$$(grep -s '^LANGFUSE_ENABLED=true' .env > /dev/null && echo '--profile langfuse') \
		$$(grep -s '^GRAPHITI_ENABLED=true' .env > /dev/null && echo '--profile graphiti') \
		up -d --no-recreate
	echo -e "\n\033[1m\033[34m━━━ Installing remaining tools (requires containers)... ━━━\033[0m"
	bash bin/install.sh --post-docker
	@bash src/install/obsidian/sync-obsidian-key.sh
	echo -e "\n\033[1m\033[34m━━━ Starting Obsidian... ━━━\033[0m"
	@_vault="$$(pwd)/storage/obsidian"; \
	_key_file="$$(pwd)/storage/secrets/obsidian-api-key"; \
	_running=false; \
	if [ -f "$$_key_file" ]; then \
		_key=$$(cat "$$_key_file"); \
		if [ -n "$$_key" ] && curl -sk --connect-timeout 2 --max-time 3 -o /dev/null -w "%{http_code}" \
			-H "Authorization: Bearer $$_key" "https://127.0.0.1:27124/" 2>/dev/null | grep -q "200"; then \
			_running=true; \
		fi; \
	fi; \
	if $$_running; then \
		echo "  ✓ Obsidian already running (vault: storage/obsidian)"; \
	elif command -v obsidian >/dev/null 2>&1; then \
		nohup xdg-open "obsidian://open?path=$${_vault}" >/dev/null 2>&1 & \
		echo "  ✓ Obsidian launched (vault: storage/obsidian)"; \
	elif [ "$$(uname -s)" = "Darwin" ] && [ -d "/Applications/Obsidian.app" ]; then \
		open "obsidian://open?path=$${_vault}"; \
		echo "  ✓ Obsidian launched (vault: storage/obsidian)"; \
	else \
		echo "  ⚠ Obsidian not found — install it or run 'make up' after installing"; \
	fi
	@echo -e "\n\033[1m\033[34m━━━ Starting Discord Bot... ━━━\033[0m"
	@if grep -s '^DISCORD_ENABLED=true' .env > /dev/null 2>&1 && command -v remote-opencode >/dev/null 2>&1; then \
		if [ -f storage/remote-opencode.pid ] && kill -0 "$$(cat storage/remote-opencode.pid)" 2>/dev/null; then \
			echo "  ✓ remote-opencode already running (PID $$(cat storage/remote-opencode.pid))"; \
		else \
			nohup remote-opencode start >storage/remote-opencode.log 2>&1 & \
			echo "$$!" > storage/remote-opencode.pid; \
			echo "  ✓ remote-opencode launched (PID $$!)"; \
		fi; \
	elif grep -s '^DISCORD_ENABLED=true' .env > /dev/null 2>&1; then \
		echo "  ⚠ remote-opencode not found — run: npm install -g remote-opencode && remote-opencode setup"; \
	else \
		echo "  – Discord Bot (disabled)"; \
	fi
	echo -e "\n\033[1m\033[34m━━━ Telamon is up. ━━━\033[0m\n"
	$(MAKE) status

down: ## Shut down Telamon services
	echo -e "\n\033[1m\033[34m━━━ Shutting down Telamon services... ━━━\033[0m"
	@if [ -f storage/remote-opencode.pid ]; then \
		_pid=$$(cat storage/remote-opencode.pid); \
		if kill -0 "$$_pid" 2>/dev/null; then \
			kill "$$_pid" 2>/dev/null && echo "  ✓ remote-opencode stopped (PID $$_pid)"; \
		fi; \
		rm -f storage/remote-opencode.pid; \
	fi
	@if pgrep -x obsidian >/dev/null 2>&1; then \
		pkill -x obsidian 2>/dev/null && echo "  ✓ Obsidian stopped"; \
	else \
		echo "  – Obsidian (not running)"; \
	fi
	docker compose $(COMPOSE_PROFILES) down --remove-orphans

reset: ## Remove project-side wiring created by init, keep storage data  (usage: make reset PROJ=path/to/project)
	@if [ -z "$(PROJ)" ]; then echo "Usage: make reset PROJ=path/to/project"; exit 1; fi
	echo -e "\n\033[1m\033[34m━━━ Resetting project: $(PROJ) ━━━\033[0m"
	bash bin/reset.sh "$(PROJ)"

purge: ## Remove project wiring AND project storage data  (usage: make purge PROJ=path/to/project)
	@if [ -z "$(PROJ)" ]; then echo "Usage: make purge PROJ=path/to/project"; exit 1; fi
	echo -e "\n\033[1m\033[34m━━━ Purging project: $(PROJ) ━━━\033[0m"
	bash bin/purge.sh "$(PROJ)"

uninstall: ## Completely remove Telamon from this system (destructive — shows confirmation prompt)
	echo -e "\n\033[1m\033[34m━━━ Uninstalling Telamon... ━━━\033[0m"
	bash bin/uninstall.sh

restart: ## Stop then start Telamon services
	echo -e "\n\033[1m\033[34m━━━ Restarting Telamon services... ━━━\033[0m"
	$(MAKE) down
	$(MAKE) up

status: ## Show installation status of all Telamon tools
	echo -e "\n\033[1m\033[34m━━━ Telamon Status ━━━\033[0m"
	bash bin/status.sh

update: ## Upgrade all Telamon-managed tools to their latest versions
	echo -e "\n\033[1m\033[34m━━━ Updating Telamon tools... ━━━\033[0m"
	bash bin/update.sh

doctor: ## Run a comprehensive health check of the full Telamon stack
	echo -e "\n\033[1m\033[34m━━━ Telamon Doctor ━━━\033[0m"
	bash bin/doctor.sh

init: ## Initialise a project to use Telamon  (usage: make init PROJ=path/to/project)
	@if [ -z "$(PROJ)" ]; then echo "Usage: make init PROJ=path/to/project"; exit 1; fi
	echo -e "\n\033[1m\033[34m━━━ Initialising project: $(PROJ) ━━━\033[0m"
	bash bin/init.sh "$(PROJ)"

test: ## Run the full test suite (make up + init a dummy project + assert wiring)
	@echo -e "\n\033[1m\033[34m━━━ Step 1/3: Ensuring Telamon is up... ━━━\033[0m"
	$(MAKE) up
	@echo -e "\n\033[1m\033[34m━━━ Step 2/3: Running make init on a fresh dummy project... ━━━\033[0m"
	rm -rf tmp/test-proj
	mkdir -p tmp/test-proj
	$(MAKE) init PROJ=./tmp/test-proj
	@echo -e "\n\033[1m\033[34m━━━ Step 3/3: Asserting wiring... ━━━\033[0m"
	bash tests/bin/init.test.sh ./tmp/test-proj test-proj
