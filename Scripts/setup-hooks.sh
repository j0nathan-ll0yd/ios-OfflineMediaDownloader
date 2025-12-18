#!/usr/bin/env bash
# Setup git hooks for iOS project
# Run this once after cloning the repository

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Setting up git hooks for iOS project..."

# Configure git to use our hooks directory
git config core.hooksPath .githooks

# Make hooks executable
chmod +x "$PROJECT_ROOT/.githooks/commit-msg"
chmod +x "$PROJECT_ROOT/.githooks/pre-push"

echo "✅ Git hooks configured successfully!"
echo ""
echo "Hooks installed:"
echo "  - commit-msg: Blocks AI attribution in commit messages"
echo "  - pre-push: Blocks direct master pushes, verifies Xcode build"
