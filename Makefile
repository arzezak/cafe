BUNDLE_ID ?= com.arzezak.cafe
APP := $(HOME)/Applications/Cafe.app
AGENT := $(HOME)/Library/LaunchAgents/$(BUNDLE_ID).plist

.PHONY: install uninstall restart

install:
	@BUNDLE_ID=$(BUNDLE_ID) APP=$(APP) AGENT=$(AGENT) ./install

uninstall:
	@launchctl bootout gui/$$(id -u)/$(BUNDLE_ID) 2>/dev/null || true
	@rm -rf $(APP) $(AGENT)
	@echo "Removed $(APP) and $(AGENT)"

restart:
	@launchctl kickstart -k gui/$$(id -u)/$(BUNDLE_ID)
