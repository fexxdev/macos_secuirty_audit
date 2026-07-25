PREFIX ?= /usr/local
SCRIPT := bin/macos-security-audit

install:
	@mkdir -p $(PREFIX)/bin
	@cp $(SCRIPT) $(PREFIX)/bin/macos-security-audit
	@chmod +x $(PREFIX)/bin/macos-security-audit
	@echo "Installed to $(PREFIX)/bin/macos-security-audit"

uninstall:
	@rm -f $(PREFIX)/bin/macos-security-audit
	@echo "Removed $(PREFIX)/bin/macos-security-audit"

# Parse-only: catches syntax errors without running anything.
lint:
	@bash -n $(SCRIPT) && echo "bash -n: ok"
	@bash -n tests/run-tests.sh && echo "bash -n (tests): ok"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -S warning $(SCRIPT) tests/run-tests.sh && echo "shellcheck: clean"; \
	else \
		echo "shellcheck: not installed (brew install shellcheck)"; \
	fi

test:
	@./tests/run-tests.sh

check: lint test

.PHONY: install uninstall lint test check
