#!/usr/bin/env bash

# Test runner script for centerpad.nvim
# Runs tests using busted via nvim

set -e

echo "=== Centerpad Test Suite ==="
echo ""

# Check if busted is available
if ! command -v busted &> /dev/null; then
    echo "Error: busted not found. Please install it:"
    echo "  luarocks install busted"
    exit 1
fi

# Check if nvim is available
if ! command -v nvim &> /dev/null; then
    echo "Error: nvim not found. Please install Neovim."
    exit 1
fi

# Run tests
echo "Running tests..."
echo ""

# Use busted with nvim lua interpreter
busted \
    --helper=tests/minimal_init.lua \
    --lua="nvim -u tests/minimal_init.lua -l" \
    --output=gtest \
    --pattern="_spec%.lua$" \
    tests/centerpad/

echo ""
echo "=== Tests Complete ==="
