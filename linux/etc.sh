#!/bin/bash
set -euo pipefail
if ! command -v apt-get >/dev/null 2>&1; then
    echo 'This setup supports Debian/Ubuntu Linux. Install git, curl, zsh and build tools manually for other distributions.' >&2
    exit 1
fi
sudo apt-get update
sudo apt-get install -y git curl zsh build-essential procps file
