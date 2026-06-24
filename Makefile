# Makefile
# Definition of Done (DoD) verification targets for devx-mac-provisioning.

.PHONY: default help check lint test security build clean all

default: help

help:
	@echo "Available Definition of Done (DoD) targets:"
	@echo "  make check      - Run all local validation checks (syntax, secrets, lint)"
	@echo "  make test       - Alias for make check to run local validations"
	@echo "  make security   - Run OSV vulnerability scanner recursively"
	@echo "  make build      - Compile the macOS installer package (.pkg)"
	@echo "  make clean      - Clean local temporary build output directories"
	@echo "  make all        - Run verification checks and build the package"

check: lint

lint:
	@echo "Running local syntax and secret audits..."
	@./scripts/preflight-check.sh

test: check

security:
	@echo "Running vulnerability scanner..."
	@if command -v osv-scanner >/dev/null 2>&1; then \
		osv-scanner -r . ; \
	elif [ -f "/opt/homebrew/bin/osv-scanner" ]; then \
		/opt/homebrew/bin/osv-scanner -r . ; \
	elif [ -f "/usr/local/bin/osv-scanner" ]; then \
		/usr/local/bin/osv-scanner -r . ; \
	else \
		echo "Warning: osv-scanner not found in PATH. Install with: brew install google/osv-scanner/osv-scanner" ; \
		exit 1 ; \
	fi

build:
	@echo "Compiling macOS installer package..."
	@./packaging/build-pkg.sh

clean:
	@echo "Cleaning temporary build files..."
	@rm -rf dist/
	@rm -rf packaging/build_root/
	@rm -rf packaging/scripts/

all: check build
