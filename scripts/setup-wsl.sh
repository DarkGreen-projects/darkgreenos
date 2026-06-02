#!/bin/bash
# DarkgreenOS - install build tools in WSL (Ubuntu/Debian)
set -euo pipefail

echo "Installing DarkgreenOS build dependencies..."
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    nasm \
    gcc-multilib \
    grub-pc-bin \
    xorriso \
    qemu-system-x86

echo ""
echo "Done. Build from the project folder:"
echo "  cd /mnt/c/Users/feded/darkgreenos"
echo "  make iso && make run"
