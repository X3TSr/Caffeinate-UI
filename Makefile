.DEFAULT_GOAL := build
.PHONY: build debug universal run install uninstall test lint clean icon

## Build Caffeinate UI.app into ./build
build:
	@./scripts/build.sh

## Unoptimised build, faster to iterate on
debug:
	@./scripts/build.sh --debug

## arm64 + x86_64 bundle
universal:
	@./scripts/build.sh --universal

## Build and run in the foreground
run:
	@./scripts/run.sh

## Build and copy to /Applications
install:
	@./scripts/install.sh

## Remove the app, its preferences and its login item
uninstall:
	@./scripts/uninstall.sh

## Run the CaffeinateKit unit tests
test:
	@swift test

## Regenerate build/AppIcon.icns
icon:
	@swift Tools/GenerateAppIcon.swift build/AppIcon.iconset
	@iconutil --convert icns build/AppIcon.iconset --output build/AppIcon.icns
	@echo "build/AppIcon.icns"

## Delete build products
clean:
	@rm -rf .build build
	@echo "cleaned"
