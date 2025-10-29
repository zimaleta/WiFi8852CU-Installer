# Simple Makefile for WiFi8852CU_Installer
# Targets:
#   make install     - runs ./install.sh
#   make uninstall   - runs ./uninstall.sh
#   make purge       - runs ./uninstall.sh --purge
#   make status      - shows dkms/module status
#   make check       - syntax check scripts
#   make trial-reset - reset trial file (for testing)
#   make help        - show this help

SHELL := /bin/bash
PKG_NAME ?= rtl8852cu
PKG_VER  ?= 1.19.2.1

.PHONY: help install uninstall purge status check trial-reset

help:
	@sed -n '1,40p' Makefile

install:
	@chmod +x install.sh
	@./install.sh

uninstall:
	@chmod +x uninstall.sh
	@./uninstall.sh

purge:
	@chmod +x uninstall.sh
	@./uninstall.sh --purge

status:
	@echo "== DKMS status =="
	@dkms status | grep -E "^$(PKG_NAME)/" || echo "(no dkms entries for $(PKG_NAME))"
	@echo "== Loaded module =="
	@lsmod | grep -E '8852cu|rtl8852cu' || echo "(module not loaded)"
	@echo "== Net devices =="
	@nmcli device || true

check:
	@bash -n install.sh
	@bash -n uninstall.sh
	@bash -n scripts/trial.sh
	@echo "Shell syntax OK."

trial-reset:
	@sudo rm -f /etc/zimaletai/wifi8852cu.trial
	@sudo ./scripts/trial.sh
