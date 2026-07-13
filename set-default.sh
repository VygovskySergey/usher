#!/bin/bash
set -euo pipefail
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SRC_DIR/.build"
swiftc -O "$SRC_DIR/Sources/set-default.swift" -o "$SRC_DIR/.build/set-default"
exec "$SRC_DIR/.build/set-default"
