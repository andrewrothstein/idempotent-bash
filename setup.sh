#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

source "idempotent-bash.sh"

# Set the log file path so you can follow along.
IB_LOG="/tmp/${BASH_SOURCE[0]}.log"

# Most setup scripts require root.
if [[ $EUID != 0 ]]; then
    echo "Re-run this script with root privileges."
    exit 1
fi

setup_pip() {
  printf "\n=== Pip ===\n"
  local label="[python] install pip"
  local skip=$(command -v pip)
  local url="https://bootstrap.pypa.io/get-pip.py"
  ib-action -l "$label" -s "$skip" -- wget --quiet -O - $url \| sudo python

  ib-pip-install pyyaml jinja2-cli
}

setup_pip
