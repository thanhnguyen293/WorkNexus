SHELL := /bin/sh

FLUTTER ?= $(shell command -v fvm >/dev/null 2>&1 && echo "fvm flutter" || echo "flutter")
DART ?= $(shell command -v fvm >/dev/null 2>&1 && echo "fvm dart" || echo "dart")

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  DEFAULT_DEVICE := macos
else ifeq ($(UNAME_S),Linux)
  DEFAULT_DEVICE := linux
else
  DEFAULT_DEVICE := windows
endif

DEVICE ?= $(DEFAULT_DEVICE)
TEST ?=

.DEFAULT_GOAL := help

.PHONY: help setup setup-linux-deps install install-linux doctor get outdated codegen l10n watch format analyze test verify run run-linux dev-linux build-linux build-macos build-macos-release build-windows-release build-linux-release clean reset

help: ## Show available targets.
	@awk 'BEGIN {FS = ":.*##"; printf "\nWorkNexus targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Initial project setup: install system deps, flutter packages, codegen & l10n.
ifeq ($(UNAME_S),Linux)
	@$(MAKE) setup-linux-deps
endif
	@$(MAKE) get
	@$(MAKE) codegen
	@$(MAKE) l10n
	@printf "\n✨ Setup complete! Run 'make dev-linux' (or 'make run') to start the app.\n\n"

setup-linux-deps: ## Install Linux desktop system dependencies (Debian/Ubuntu).
	@echo "Checking Linux system dependencies..."
	@which apt-get >/dev/null 2>&1 || (echo "Not a Debian/Ubuntu system, skipping apt."; exit 0)
	@dpkg -s libayatana-appindicator3-dev libwebkit2gtk-4.1-dev >/dev/null 2>&1 && echo "  ✓ Linux system dependencies are installed." || (echo "  Installing Linux system dependencies & build tools..." && sudo apt-get update && sudo apt-get install -y libayatana-appindicator3-dev libwebkit2gtk-4.1-dev clang cmake ninja-build pkg-config libgtk-3-dev)

install: setup ## Standard alias for setup.

doctor: ## Show Flutter toolchain diagnostics.
	$(FLUTTER) doctor -v

get: ## Install Dart and Flutter dependencies.
	$(FLUTTER) pub get

outdated: ## Show dependency upgrade information.
	$(FLUTTER) pub outdated

codegen: ## Generate freezed/json/drift/retrofit sources once.
	$(FLUTTER) pub run build_runner build --delete-conflicting-outputs

l10n: ## Generate localization files (ARB to Dart).
	$(FLUTTER) gen-l10n

watch: ## Watch and regenerate generated Dart sources.
	$(FLUTTER) pub run build_runner watch --delete-conflicting-outputs

format: ## Format Dart source and tests.
	$(DART) format lib test

analyze: ## Run static analysis.
	$(DART) analyze

test: ## Run tests. Use TEST=path/or/name to target a subset.
	$(FLUTTER) test $(TEST)

verify: format analyze test ## Format, analyze, and run tests.

run: ## Run the app. Override with DEVICE=<device-id>.
	$(FLUTTER) run -d $(DEVICE)

run-linux: ## Run the app on Linux desktop.
	$(FLUTTER) run -d linux

dev-linux: ## Run the app on Linux desktop in debug mode.
	$(FLUTTER) run -d linux

build-linux: ## Build the Linux desktop debug app.
	$(FLUTTER) build linux --debug

build-macos: ## Build the macOS app.
	$(FLUTTER) build macos

build-macos-release: ## Build the macOS release app.
	$(FLUTTER) build macos --release

build-windows-release: ## Build the Windows release app.
	$(FLUTTER) build windows --release

build-linux-release: ## Build the Linux release app.
	$(FLUTTER) build linux --release

install-linux: build-linux-release ## Build and update installed app in ~/.local/share/worknexus.
	@mkdir -p ~/.local/share/worknexus
	@cp -r build/linux/x64/release/bundle/* ~/.local/share/worknexus/
	@echo "✓ WorkNexus updated successfully in ~/.local/share/worknexus"

clean: ## Clean Flutter build output.
	$(FLUTTER) clean

reset: clean get codegen l10n ## Clean, reinstall dependencies, and regenerate code and l10n.
