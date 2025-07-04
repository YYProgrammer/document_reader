SHELL := /bin/bash
HIDE ?= @

export HOMEBREW_NO_AUTO_UPDATE=true

gen:
	$(HIDE)flutter pub get

