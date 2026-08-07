#!/usr/bin/env bash
# Seed only gitignored, per-machine configuration. This script is idempotent:
# existing worktree-local files win, and provisioning failures are non-fatal.
set -u

worktree="$(git rev-parse --show-toplevel)"
main="$(dirname "$(git rev-parse --git-common-dir)")"
[ "$worktree" = "$main" ] && exit 0

log() { printf 'worktree-setup: %s\n' "$1"; }

# Shared SPM Module Cache export for fast package resolution
export SWIFTPM_MODULE_CACHE_PATH="${HOME}/Library/Caches/org.swift.swiftpm/ModuleCache"

# 1) Synchronous (< 100ms): Seed gitignored local files
for rel in .claude/settings.local.json Development.xcconfig; do
  src="$main/$rel"
  dst="$worktree/$rel"
  if [ -e "$src" ] && [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst" 2>/dev/null && log "seeded $rel"
  fi
done

# 2) Direnv auto-allow
if command -v direnv >/dev/null 2>&1 && [ -f "$worktree/.envrc" ]; then
  ( cd "$worktree" && direnv allow >/dev/null 2>&1 || true )
fi

# 3) Fast SPM resolve
if [ "${WORKTREE_SKIP_INSTALL:-0}" != "1" ]; then
  if (cd "$worktree/APITypes" && swift package resolve) >/dev/null 2>&1; then
    log 'resolved APITypes'
  else
    log 'WARN: APITypes resolution failed — run swift package resolve manually'
  fi
fi

log 'done'
