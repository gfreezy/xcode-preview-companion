# Xcode Preview Companion — build automation
#
# Requires: xcodegen (brew install xcodegen) and Xcode command line tools.

PROJECT      := XcodePreviewCompanion.xcodeproj
SCHEME       := XcodePreviewCompanion
CONFIG       ?= Debug
DERIVED_DATA := build
APP          := $(DERIVED_DATA)/Build/Products/$(CONFIG)/$(SCHEME).app

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	-configuration $(CONFIG) -derivedDataPath $(DERIVED_DATA)

.DEFAULT_GOAL := build

.PHONY: help generate build run release dmg clean distclean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

generate: $(PROJECT) ## Regenerate the Xcode project from project.yml

$(PROJECT): project.yml
	xcodegen generate

build: generate ## Build the app (Debug by default; CONFIG=Release to override)
	$(XCODEBUILD) build

run: build ## Build and launch the app
	open $(APP)

release: ## Build a Release configuration
	$(MAKE) build CONFIG=Release

dmg: ## Build, sign (ad-hoc by default), and package a DMG into dist/
	./scripts/release.sh

clean: ## Remove build products (xcodebuild clean)
	$(XCODEBUILD) clean

distclean: ## Remove the build dir and generated project
	rm -rf $(DERIVED_DATA) $(PROJECT)
