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

up: ## Start the ADK: install host tools, then bring docker compose services up
	@test -f .env || cp .env.dist .env
	echo -e "\n\n====== Ensuring host has all requirements... ====== \n"
	bash src/install/run.sh
	echo -e "\n\n====== Bringing up services... ====== \n"
	docker compose up -d --no-recreate
	echo -e "\n\n====== ADK is up. ====== \n"

down: ## Shut down the ADK services
	docker compose down

purge: ## Remove all containers and volumes
	docker compose down --volumes --remove-orphans

restart: down up ## Restart running containers

init: ## Initialise a project to use this ADK  (usage: make init PROJ=path/to/project)
	@if [ -z "$(PROJ)" ]; then echo "Usage: make init PROJ=path/to/project"; exit 1; fi
	bash bin/init.sh "$(PROJ)"
