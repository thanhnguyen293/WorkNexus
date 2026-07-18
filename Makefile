SHELL := /bin/sh

FLUTTER ?= fvm flutter
DART ?= fvm dart
DEVICE ?= macos
TEST ?=

.DEFAULT_GOAL := help

.PHONY: help doctor get outdated codegen watch format analyze test verify run build-macos build-macos-release build-windows-release build-linux-release clean reset

help: ## Show available targets.
	@awk 'BEGIN {FS = ":.*##"; printf "\nWorkNexus targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

doctor: ## Show Flutter toolchain diagnostics.
	$(FLUTTER) doctor -v

get: ## Install Dart and Flutter dependencies.
	$(FLUTTER) pub get

outdated: ## Show dependency upgrade information.
	$(FLUTTER) pub outdated

codegen: ## Generate freezed/json/drift/retrofit sources once.
	$(FLUTTER) pub run build_runner build --delete-conflicting-outputs

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

build-macos: ## Build the macOS app.
	$(FLUTTER) build macos

build-macos-release: ## Build the macOS release app.
	$(FLUTTER) build macos --release

build-windows-release: ## Build the Windows release app.
	$(FLUTTER) build windows --release

build-linux-release: ## Build the Linux release app.
	$(FLUTTER) build linux --release

clean: ## Clean Flutter build output.
	$(FLUTTER) clean

reset: clean get codegen ## Clean, reinstall dependencies, and regenerate code.
