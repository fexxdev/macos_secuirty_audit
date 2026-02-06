PREFIX ?= /usr/local

install:
	@mkdir -p $(PREFIX)/bin
	@cp bin/macos-security-audit $(PREFIX)/bin/macos-security-audit
	@chmod +x $(PREFIX)/bin/macos-security-audit
	@echo "Installed to $(PREFIX)/bin/macos-security-audit"

uninstall:
	@rm -f $(PREFIX)/bin/macos-security-audit
	@echo "Removed $(PREFIX)/bin/macos-security-audit"

.PHONY: install uninstall
